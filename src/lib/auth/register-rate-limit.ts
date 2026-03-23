import "server-only";

type Bucket = {
  count: number;
  resetAt: number;
};

type RateLimitStore = {
  byEmail: Map<string, Bucket>;
  byIp: Map<string, Bucket>;
};

declare global {
  var __portalRegisterRateLimitStore: RateLimitStore | undefined;
}

const WINDOW_MS = 5 * 60 * 1000;
const MAX_PER_EMAIL = 3;
const MAX_PER_IP = 10;

function getStore() {
  if (!globalThis.__portalRegisterRateLimitStore) {
    globalThis.__portalRegisterRateLimitStore = {
      byEmail: new Map(),
      byIp: new Map(),
    };
  }

  return globalThis.__portalRegisterRateLimitStore;
}

function consumeBucket(map: Map<string, Bucket>, key: string, max: number) {
  const now = Date.now();
  const current = map.get(key);

  if (!current || current.resetAt <= now) {
    map.set(key, {
      count: 1,
      resetAt: now + WINDOW_MS,
    });
    return true;
  }

  if (current.count >= max) {
    return false;
  }

  current.count += 1;
  map.set(key, current);
  return true;
}

export function consumeRegisterRateLimit(input: { email: string; ip: string }) {
  const store = getStore();

  const emailAllowed = consumeBucket(store.byEmail, input.email, MAX_PER_EMAIL);
  const ipAllowed = consumeBucket(store.byIp, input.ip, MAX_PER_IP);

  return emailAllowed && ipAllowed;
}
