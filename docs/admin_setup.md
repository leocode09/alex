# Super admin setup

This app ships a hidden super-admin panel that lets a single operator
see every installation, view usage stats, limit license periods, and
toggle individual features per shop or per device.

The panel is reached by **long-pressing the "About" row in Settings**.
Only Firebase accounts listed in `/admins/{uid}` can sign in; everybody
else gets "This account is not authorized for admin access." and is
signed out.

## One-time Firebase Console setup

### 1. Enable authentication providers

Every POS user signs in with a **phone number + password** (see
[`lib/services/cloud/user_auth_service.dart`](../lib/services/cloud/user_auth_service.dart)).
Under the hood this uses the native **Email/Password** provider keyed by a
synthetic email derived from the normalized phone
(`<phoneKey>@phone.alex-pos.app`) — no SMS, no backend. The resulting
Firebase uid is **stable**, so a returning owner is always recognized as
the owner of their shop even after a reinstall or new device. The
super-admin panel also uses **Email/Password** (on a separate named
Firebase app instance).

> Anonymous auth is **no longer used** for identity. You can leave the
> Anonymous provider disabled.

**Preferred (from repo root):** `firebase.json` already lists the
providers. Deploy with a recent Firebase CLI (v15.15+):

```bash
npx -y firebase-tools@latest deploy --only auth,firestore:rules
```

Business registration and cloud sync need **both** the Email/Password
provider and the rules in [`firestore.rules`](../firestore.rules). If
either is missing, owners see sign-in or permission-denied errors on
**Register business**, and staff see permission-denied when submitting a
**Join a business** request.

**Manual (Console):** Firebase Console → **Build → Authentication →
Sign-in method** → enable **Email/Password**. Magic links and social
providers are not required.

### Identity model & data layout

- `/users/{uid}` — per-user profile: `phone`, `phoneKey` (normalized),
  `displayName`, and a best-effort pointer to the current `shopId` / `role`
  so a fresh device restores membership after login. A user owns only
  their own doc.
- `/shops/{shopId}` — carries `ownerUid`, `ownerPhone`, and
  `ownerPhoneKey` (normalized). System admins approve shops
  (`approvalStatus`), owners approve staff.
- **Ownership claim / migration:** when a user logs in, the app re-binds
  any shop whose `ownerPhoneKey` matches their phone to their current uid
  (changing only `ownerUid` / `ownerName`, enforced by the
  `isOwnershipClaim` rule). This is how legacy anonymous-uid owners
  recover their shop and how owners move to a new device.

### 2. Create the first admin user

1. Firebase Console → **Build → Authentication → Users → Add user**
2. Enter the admin's email + password. Copy the generated **User UID**.

### 3. Allowlist the UID in Firestore

1. Firebase Console → **Build → Firestore Database → Data**
2. Create collection `admins`.
3. Inside it, create a document whose **Document ID is the UID** you
   copied above. Any payload works; a single field
   `{ name: "owner" }` is fine.

```text
/admins/<uid>
  name:  "owner"
  email: "you@example.com"  // optional, for your own bookkeeping
```

To add another admin later, repeat steps 2–3 for the new user.

### 4. Deploy the security rules

The file [`firestore.rules`](../firestore.rules) at the repo root
enforces all admin-only access. Deploy it once, then again whenever it
changes:

```bash
npx -y firebase-tools@latest deploy --only firestore:rules
```

If you are using the Firebase Console UI, paste the contents of
`firestore.rules` into **Firestore Database → Rules → Publish**.

## What the admin can do

Once signed in on any device:

| Section   | Capability                                                              |
| --------- | ----------------------------------------------------------------------- |
| Dashboard | Total devices, active in 24h / 7d, total shops, recently active list.   |
| Shops     | See every shop, its member devices, 14-day usage bars.                  |
| Shop edit | Enable / disable, set license expiry, toggle every `FeatureKey`, force PIN on any feature, set `maxProducts` / `maxSalesPerDay`, publish a `notice` shown on the lock screen. |
| Devices   | Global list of every install (with filter "only blocked").              |
| Device edit | Per-device expiry override, per-feature override (on / off / inherit), and a hard **Block device** switch. |

### Feature keys

`FeatureKey` (see [`lib/models/license_policy.dart`](../lib/models/license_policy.dart)) enumerates the gated features:

- `sales` — creating / editing sales & receipts
- `inventoryEdit` — creating / editing / deleting products
- `reports` — reports & dashboard analytics routes
- `printing` — receipt auto-print and manual reprint
- `cloudSync` — Firestore cloud sync background service
- `lanSync` — LAN & Wi-Fi Direct peer sync

When a feature is disabled:

- UI actions show an "[Feature] has been disabled by the administrator" dialog.
- Background services (cloud sync, LAN sync) refuse to start.
- Blocked / expired devices are hard-routed to `/license-locked` until
  the admin lifts the restriction.

### Per-device vs per-shop precedence

The policy is merged in this order (first match wins):

1. **Device override** (`/devices/{installId}.featureOverrides.<key>`)
   — explicit `true` or `false`.
2. **Shop flag** (`/shops/{shopId}.featureFlags.<key>`).
3. Default: enabled.

Global kill-switches (shop-level `enabled=false`, `licenseExpiresAt` in
the past, or device `blocked=true`) override every feature flag and
route the device to `/license-locked`.

## Resetting a user's password

Passwords are reset out of band — there is no in-app self-service reset
(the synthetic phone email cannot receive a reset link). When a user
forgets their password, the app's **Forgot password?** link tells them to
contact support. To reset it:

1. Firebase Console → **Build → Authentication → Users**.
2. Find the user by their synthetic email
   `<phoneKey>@phone.alex-pos.app` (e.g. a `0784712870` login normalizes
   to `250784712870@phone.alex-pos.app`).
3. Use the row's **⋮ → Reset password** (or set a temporary password) and
   share the new password with the user.

The uid never changes, so the user keeps their shop, role, and data.

## One-time data migration

After deploying the rules, run the cleanup script once with the Firebase
CLI logged in as a project owner/editor:

```bash
node scripts/migrate_accounts.js          # dry run (report only)
node scripts/migrate_accounts.js --apply  # backfill ownerPhoneKey
node scripts/migrate_accounts.js --apply --dedup  # also tombstone duplicate shops
```

It backfills `ownerPhoneKey` on existing shops (so the in-app claim can
find them), reports duplicate shops and orphaned member docs, and — with
`--dedup` — soft-tombstones the non-canonical duplicates. Existing owners
then just register/log in with their phone number; the app claims their
shop automatically. Stale staff member docs (old anonymous uids) are
removed by the owner from the **Team** screen.

## Operational notes

- Admin sign-in uses a **named Firebase app** (`"admin"`). This keeps
  the device's user session intact while the admin is signed in, so
  the heartbeat and usage tracking never point at the admin account.
- The admin session lives in memory only. Admins must re-authenticate
  on every app restart — this is intentional, since losing a device
  with an active admin session should not hand admin rights to its
  next holder.
- Heartbeats run every 5 minutes. `lastSeenAtIso` is always updated
  via `FieldValue.serverTimestamp()` as well, so clock skew cannot
  trick the "active in last 24h" counter.
- Usage counters are buffered in `SharedPreferences` and flushed every
  30 seconds via `FieldValue.increment(...)`. A brief offline window
  does not lose sales, prints, or edits.
