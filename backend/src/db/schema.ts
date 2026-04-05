import { pgTable, text, integer, real, timestamp, bigint, date, index, boolean, unique } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  email: text('email').unique().notNull(),
  emailVerified: boolean('emailVerified').notNull().default(false),
  image: text('image'),
  createdAt: timestamp('createdAt', { mode: 'date' }).notNull(),
  updatedAt: timestamp('updatedAt', { mode: 'date' }).notNull(),
  color: text('color').default('#FF6B6B'),
  totalTiles: integer('totalTiles').default(0),
  totalDistance: real('totalDistance').default(0),
  totalSteps: integer('totalSteps').default(0),
  currentStreak: integer('currentStreak').default(0),
  longestStreak: integer('longestStreak').default(0),
  lastActiveAt: timestamp('lastActiveAt', { mode: 'date' }),
  lastLat: real('last_lat'),
  lastLng: real('last_lng'),
});

export const sessions = pgTable('sessions', {
  id: text('id').primaryKey(),
  expiresAt: timestamp('expiresAt', { mode: 'date' }).notNull(),
  token: text('token').notNull().unique(),
  createdAt: timestamp('createdAt', { mode: 'date' }).notNull(),
  updatedAt: timestamp('updatedAt', { mode: 'date' }).notNull(),
  ipAddress: text('ipAddress'),
  userAgent: text('userAgent'),
  userId: text('userId').notNull().references(() => users.id),
});

export const accounts = pgTable('accounts', {
  id: text('id').primaryKey(),
  accountId: text('accountId').notNull(),
  providerId: text('providerId').notNull(),
  userId: text('userId').notNull().references(() => users.id),
  accessToken: text('accessToken'),
  refreshToken: text('refreshToken'),
  idToken: text('idToken'),
  accessTokenExpiresAt: timestamp('accessTokenExpiresAt', { mode: 'date' }),
  refreshTokenExpiresAt: timestamp('refreshTokenExpiresAt', { mode: 'date' }),
  scope: text('scope'),
  password: text('password'),
  createdAt: timestamp('createdAt', { mode: 'date' }).notNull(),
  updatedAt: timestamp('updatedAt', { mode: 'date' }).notNull(),
});

export const verifications = pgTable('verifications', {
  id: text('id').primaryKey(),
  identifier: text('identifier').notNull(),
  value: text('value').notNull(),
  expiresAt: timestamp('expiresAt', { mode: 'date' }).notNull(),
  createdAt: timestamp('createdAt', { mode: 'date' }).notNull(),
  updatedAt: timestamp('updatedAt', { mode: 'date' }).notNull()
});

export const tiles = pgTable('tiles', {
  h3Index: text('h3_index').primaryKey(), // resolution 10
  ownerId: text('owner_id').references(() => users.id),
  strength: integer('strength').default(100), // 0-100
  capturedAt: timestamp('captured_at', { mode: 'date' }),
  lastUpdatedAt: timestamp('last_updated_at', { mode: 'date' }).defaultNow(),
}, (t) => ({
  ownerIdx: index('tile_owner_idx').on(t.ownerId),
}));

export const tileEvents = pgTable('tile_events', {
  id: bigint('id', { mode: 'bigint' }).primaryKey().generatedAlwaysAsIdentity(),
  h3Index: text('h3_index').notNull(),
  actorId: text('actor_id').references(() => users.id),
  previousOwnerId: text('previous_owner_id'),
  eventType: text('event_type').notNull(),
  strengthDelta: integer('strength_delta'),
  createdAt: timestamp('created_at', { mode: 'date' }).defaultNow(),
}, (t) => ({
  h3Idx: index('event_h3_idx').on(t.h3Index),
  actorIdx: index('event_actor_idx').on(t.actorId),
}));

export const activeTrails = pgTable('active_trails', {
  id: bigint('id', { mode: 'bigint' }).primaryKey().generatedAlwaysAsIdentity(),
  userId: text('user_id').notNull().references(() => users.id),
  h3Index: text('h3_index').notNull(),
  createdAt: timestamp('created_at', { mode: 'date' }).defaultNow(),
}, (t) => ({
  userH3Idx: index('active_trail_user_h3_idx').on(t.userId, t.h3Index),
  userOrderIdx: index('active_trail_user_order_idx').on(t.userId, t.id),
}));

export const dailyStats = pgTable('daily_stats', {
  id: bigint('id', { mode: 'bigint' }).primaryKey().generatedAlwaysAsIdentity(),
  userId: text('user_id').notNull().references(() => users.id),
  date: date('date').notNull(), // format YYYY-MM-DD
  tilesCaptured: integer('tiles_captured').default(0),
  distanceTraveled: real('distance_traveled').default(0),
  steps: integer('steps').default(0),
  updatedAt: timestamp('updated_at', { mode: 'date' }).defaultNow(),
}, (t) => ({
  userDateIdx: index('daily_user_date_idx').on(t.userId, t.date),
  uniqueUserDate: unique('unique_user_date').on(t.userId, t.date),
}));
