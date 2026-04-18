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
- Multi-device catalog sync uses LAN (`LanSyncService`) and Wi-Fi Direct (`WifiDirectSyncService`) only—no QR catalog sync; peers exchange full `SyncData` and product deletes propagate as tombstones (`deletedProductIds`, persisted via `ProductRepository`) applied on merge import
- On the sales page, multi-package products render as one catalog card per package (plus a Single line when applicable) and tap adds that line directly without a package picker sheet; cart-line quantity can also be typed as digits in the field between −/+ (commits on blur or keyboard done; stock-aware caps; 0 removes the line)
- Shorebird OTA (code push) is integrated for Dart-only updates without rebuilding the APK; `shorebird.yaml` at project root, `shorebird_code_push` in pubspec, auto-update check via `ShorebirdUpdater` in `main.dart`
- Sales page tabs (Products/Cart/Receipts) support left/right swipe (`PageScrollPhysics` on `TabBarView`) plus a small bottom-right FAB that cycles tabs; the Receipts PIN gate is enforced on both swipe and tap via a `TabController` listener that reverts the index when the PIN is cancelled
- The product catalog page (route `/products`) is titled "Inventory" in both the AppBar and bottom-nav label (search hint "Search inventory…"); the route path itself is unchanged
- UI shares a design system: use `AppTokens` (e.g. `space2`/`space3`, `radiusM`, `border` width) and `AppThemeExtras` via `context.appExtras` (`panel`, `border`, `muted`, `danger`, `success`) for cards/panels/rows instead of hardcoded `Colors.white`/grey or literal radii, so styling adapts to dark mode and matches the global `cardTheme`
