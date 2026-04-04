import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { db } from "./db";
import * as schema from "./db/schema";
import { dash } from "@better-auth/infra";

export const auth = betterAuth({
    database: drizzleAdapter(db, {
        provider: "pg", // use 'pg' for postgres
        schema: {
            user: schema.users,
            session: schema.sessions,
            account: schema.accounts,
            verification: schema.verifications,
        }
    }),
    emailAndPassword: {
        enabled: true,
    },
    plugins: [
        dash(),
    ],
    trustedOrigins: ["http://localhost:*", "http://127.0.0.1:*"],
});
