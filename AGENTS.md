## Learned User Preferences

- Prefer auto-calculation of derived values over manual entry — if one number can be computed from others, compute it rather than asking the user to type it
- Design features for "full control": use flexible optional fields rather than rigid required ones (e.g. unit price is optional when every package has a fixed price)
- Bidirectional data entry: when A can derive B and B can derive A, support both directions so the user can start from whichever value they know
- When building an APK, copy the output file to the clipboard as a file (not just the path as text) so it can be pasted directly
- Prefer professional, theme-native UI — no gradients, rainbow accents, or decorative flourishes; use standard Material components, `ColorScheme` tokens, and flat/bordered panels

## Learned Workspace Facts

- Flutter POS/retail app using Riverpod for state, go_router for navigation, and JSON-based persistence via StorageHelper (not SQL)
- Product packages support per-package pricing (`packagePrice`), per-package cost (`packageCostPrice`), per-package inventory (`packageCount`), loose stock (`looseStock`), and bidirectional stock calculation; `sellingPriceForPackage()` centralizes price resolution
- `SaleItem.costPrice` captures per-base-unit cost at sale time for historical profit tracking; when a package has `packageCostPrice`, it is normalized to per-unit before storing; profit is displayed on the catalog, receipts, receipt detail, and dashboard
- `Product.stock` is the canonical total base-unit count; `looseStock + Σ(packageCount × unitsPerPackage)` must equal `stock`
- Device name (`lan_device_name` in SharedPreferences) is used for sales attribution (`Sale.employeeId`) and receipt seller identification
- PIN protection guards sensitive operations (add/edit/delete products, create sales, edit receipts, apply discounts, etc.) via `PinProtection` helper and `PinService`
- Multi-device sync over LAN (`LanSyncService`) and Wi-Fi Direct (`WifiDirectSyncService`) exchanges full catalog data so product edits propagate between nearby devices
- Shorebird OTA (code push) is integrated for Dart-only updates without rebuilding the APK; `shorebird.yaml` at project root, `shorebird_code_push` in pubspec, auto-update check via `ShorebirdUpdater` in `main.dart`
- Sales cart line quantity can be entered as digits in the field between −/+ (commits on blur or keyboard done; stock-aware caps; 0 removes the line), not only via the stepper buttons
