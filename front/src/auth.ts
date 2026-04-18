import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import { loginSchema } from "@/lib/auth/validation";
import { findUserByEmailForAuth, toSessionUser } from "@/lib/auth/user-repo";
import { verifyPassword } from "@/lib/auth/password";

const nextAuth = NextAuth({
  trustHost: process.env.AUTH_TRUST_HOST === "true",
  secret: process.env.AUTH_SECRET,
  session: {
    strategy: "jwt",
  },
  providers: [
    Credentials({
      name: "Credentials",
      credentials: {
        email: {
          label: "E-mail",
          type: "email",
        },
        password: {
          label: "Senha",
          type: "password",
        },
      },
      async authorize(credentials) {
        const parsed = loginSchema.safeParse(credentials);

        if (!parsed.success) {
          return null;
        }

        const user = await findUserByEmailForAuth(parsed.data.email);

        if (!user) {
          return null;
        }

        const passwordIsValid = await verifyPassword(
          parsed.data.password,
          user.password,
        );

        if (!passwordIsValid) {
          return null;
        }

        return toSessionUser(user);
      },
    }),
  ],
  callbacks: {
    jwt({ token, user }) {
      if (user) {
        token.id = user.id;
        token.role = user.role;
        token.email = user.email;
      }

      return token;
    },
    session({ session, token }) {
      if (session.user) {
        session.user.id = typeof token.id === "string" ? token.id : "";
        session.user.role =
          typeof token.role === "string" ? token.role : "user";
        session.user.email = token.email ?? session.user.email ?? "";
      }

      return session;
    },
  },
});

export const { auth, signIn, signOut } = nextAuth;
export const {
  handlers: { GET, POST },
} = nextAuth;
