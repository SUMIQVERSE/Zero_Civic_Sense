# CIVICSETU Supabase Setup

This folder contains the starter database and auth setup for moving the app from seeded demo mode to real cloud-backed accounts.

## What this enables

- Email/password registration and sign in
- Google OAuth sign in
- Persistent user profiles
- Starter civic issue tables
- Row Level Security foundations

## 1. Create the project

Create a new Supabase project from the dashboard, then copy:

- Project URL
- Publishable key or anon key

## 2. Configure redirect URLs

In `Authentication -> URL Configuration`, add this mobile redirect URL:

```text
com.civicsetu.mobile://login-callback/
```

For Google sign-in, also enable the Google provider in `Authentication -> Providers`.

## 3. Run the schema

Open the SQL editor in Supabase and run:

```sql
\i backend/supabase/schema.sql
```

If your SQL editor does not support `\i`, copy-paste the contents of `schema.sql` directly.

## 4. Optional storage buckets

Create these buckets if you want media uploads next:

- `complaint-media`
- `resolution-media`
- `avatars`

## 5. Run Flutter with auth config

From `civicsetu_flutter/`:

```bash
flutter run ^
  --dart-define=CIVICSETU_SUPABASE_URL=<your-project-url> ^
  --dart-define=CIVICSETU_SUPABASE_PUBLISHABLE_KEY=<your-publishable-or-anon-key>
```

The app keeps demo mode as a fallback when these values are not provided.

## Notes

- The Flutter app should only receive the publishable/anon key, never the service role key.
- The `profiles` table is keyed directly to `auth.users.id`.
- The included RLS policies are a safe starter, not a finished production policy set.
