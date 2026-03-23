import "server-only";
import { createHash, timingSafeEqual } from "node:crypto";

type PendingRegistration = {
  email: string;
  passwordHash: string;
  expiresAt: number;
  tokenHash: string;
};

type PendingRegistrationStore = {
  byEmail: Map<string, PendingRegistration>;
  tokenToEmail: Map<string, string>;
  cleanupTimerStarted: boolean;
};

const DEFAULT_TTL_MS = 5 * 60 * 1000;
const CLEANUP_INTERVAL_MS = 60 * 1000;

declare global {
  var __portalPendingEmailVerificationStore: PendingRegistrationStore | undefined;
}

function getStore() {
  if (!globalThis.__portalPendingEmailVerificationStore) {
    globalThis.__portalPendingEmailVerificationStore = {
      byEmail: new Map(),
      tokenToEmail: new Map(),
      cleanupTimerStarted: false,
    };
  }

  const store = globalThis.__portalPendingEmailVerificationStore;

  if (!store.cleanupTimerStarted) {
    store.cleanupTimerStarted = true;

    setInterval(() => {
      cleanupExpiredEntries();
    }, CLEANUP_INTERVAL_MS).unref?.();
  }

  return store;
}

export function getEmailVerificationTtlMs() {
  const raw = process.env.EMAIL_VERIFICATION_TTL_MS?.trim();
  const parsed = raw ? Number(raw) : DEFAULT_TTL_MS;

  if (!Number.isFinite(parsed) || parsed <= 0) {
    return DEFAULT_TTL_MS;
  }

  return parsed;
}

export function hashVerificationToken(token: string) {
  return createHash("sha256").update(token).digest("hex");
}

function cleanupExpiredEntries(now = Date.now()) {
  const store = getStore();

  for (const [email, entry] of store.byEmail.entries()) {
    if (entry.expiresAt <= now) {
      store.byEmail.delete(email);
      store.tokenToEmail.delete(entry.tokenHash);
    }
  }
}

export function upsertPendingRegistration(input: {
  email: string;
  passwordHash: string;
  tokenHash: string;
}) {
  const store = getStore();
  const now = Date.now();
  cleanupExpiredEntries(now);

  const previous = store.byEmail.get(input.email);

  if (previous) {
    store.tokenToEmail.delete(previous.tokenHash);
  }

  const entry: PendingRegistration = {
    email: input.email,
    passwordHash: input.passwordHash,
    tokenHash: input.tokenHash,
    expiresAt: now + getEmailVerificationTtlMs(),
  };

  store.byEmail.set(input.email, entry);
  store.tokenToEmail.set(input.tokenHash, input.email);

  return entry;
}

export function removePendingRegistrationByEmail(email: string) {
  const store = getStore();
  const entry = store.byEmail.get(email);

  if (!entry) {
    return;
  }

  store.byEmail.delete(email);
  store.tokenToEmail.delete(entry.tokenHash);
}

export function consumePendingRegistration(rawToken: string) {
  const store = getStore();
  const now = Date.now();
  cleanupExpiredEntries(now);

  const providedHash = hashVerificationToken(rawToken);
  const email = store.tokenToEmail.get(providedHash);

  if (!email) {
    return null;
  }

  const entry = store.byEmail.get(email);

  if (!entry) {
    store.tokenToEmail.delete(providedHash);
    return null;
  }

  const expected = Buffer.from(entry.tokenHash, "hex");
  const actual = Buffer.from(providedHash, "hex");

  if (
    expected.length !== actual.length ||
    !timingSafeEqual(expected, actual) ||
    entry.expiresAt <= now
  ) {
    store.byEmail.delete(email);
    store.tokenToEmail.delete(entry.tokenHash);
    return null;
  }

  store.byEmail.delete(email);
  store.tokenToEmail.delete(entry.tokenHash);

  return entry;
}
