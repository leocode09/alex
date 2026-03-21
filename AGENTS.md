## Learned User Preferences

- Prefer auto-calculation of derived values over manual entry — if one number can be computed from others, compute it rather than asking the user to type it
- Design features for "full control": use flexible optional fields rather than rigid required ones (e.g. unit price is optional when every package has a fixed price)
- Bidirectional data entry: when A can derive B and B can derive A, support both directions so the user can start from whichever value they know
- When building an APK, copy the output file to the clipboard as a file (not just the path as text) so it can be pasted directly

## Learned Workspace Facts

- Flutter POS/retail app using Riverpod for state, go_router for navigation, and JSON-based persistence via StorageHelper (not SQL)
- Product packages support per-package pricing (`packagePrice`), per-package inventory (`packageCount`), loose stock (`looseStock`), and bidirectional stock calculation; `sellingPriceForPackage()` centralizes price resolution
- `Product.stock` is the canonical total base-unit count; `looseStock + Σ(packageCount × unitsPerPackage)` must equal `stock`
- Device name (`lan_device_name` in SharedPreferences) is used for sales attribution (`Sale.employeeId`) and receipt seller identification
- PIN protection guards sensitive operations (add/edit/delete products, create sales, edit receipts, apply discounts, etc.) via `PinProtection` helper and `PinService`
- Multi-device sync over LAN is supported via `LanSyncService`
