# Super admin setup

This app ships a hidden super-admin panel that lets a single operator
see every installation, view usage stats, limit license periods, and
toggle individual features per shop or per device.

The panel is reached by **long-pressing the "About" row in Settings**.
Only Firebase accounts listed in `/admins/{uid}` can sign in; everybody
else gets "This account is not authorized for admin access." and is
signed out.

## One-time Firebase Console setup

### 1. Enable email/password auth

1. Firebase Console → **Build → Authentication → Sign-in method**
2. Enable **Email/Password**. Magic links and social providers are not
   required.

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
firebase deploy --only firestore:rules
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

## Operational notes

- Admin sign-in uses a **named Firebase app** (`"admin"`). This keeps
  the device's anonymous uid intact while the admin is signed in, so
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
