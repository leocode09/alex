# Data Sync Feature

## Overview
The POS system now includes a comprehensive bidirectional data synchronization feature that allows two mobile devices to sync all data using QR codes. This feature enables seamless data transfer between devices without requiring internet connectivity.

## Features

### ✅ Complete Data Synchronization
- **Products**: All product details including prices, stock, discounts, barcodes
- **Categories**: Product categories and their metadata
- **Customers**: Customer profiles, purchase history, and contact information
- **Employees**: Employee records and sales statistics
- **Sales**: Complete sales history with transaction details
- **Stores**: Store information and configurations

### ✅ Sync Strategies
The system supports three intelligent sync strategies:

1. **Merge (Recommended)** 
   - Intelligently merges data from both devices
   - Keeps the most recent version based on timestamps
   - Prevents data loss while resolving conflicts
   - Ideal for regular synchronization

2. **Append Only**
   - Only adds new items that don't exist on the receiving device
   - Never modifies or deletes existing data
   - Safest option when you want to preserve local data

3. **Replace All**
   - Completely replaces all data on the receiving device
   - Use with caution - this is destructive
   - Useful for setting up a new device or complete backup restoration

### ✅ QR Code Based Transfer
- No internet connection required
- Secure local data transfer
- Visual feedback with QR code generation
- Real-time scanning with camera

## How It Works

### Architecture

```
┌─────────────────┐         QR Code         ┌─────────────────┐
│   Device A      │ ◄──────────────────────► │   Device B      │
│                 │                          │                 │
│ • Generate QR   │                          │ • Scan QR       │
│ • Export Data   │                          │ • Import Data   │
│ • Show Stats    │                          │ • Merge/Replace │
└─────────────────┘                          └─────────────────┘
```

### Components

1. **SyncData Model** (`lib/models/sync_data.dart`)
   - Encapsulates all syncable data
   - Includes metadata (device ID, timestamp, version)
   - Provides JSON serialization/deserialization

2. **SyncService** (`lib/services/sync_service.dart`)
   - Handles data export and import
   - Implements merge strategies
   - Manages data compression (if needed)
   - Calculates data size

3. **SyncProvider** (`lib/providers/sync_provider.dart`)
   - State management for sync operations
   - Tracks sync progress and status
   - Handles errors and success states

4. **SyncPage** (`lib/ui/pages/sync_page.dart`)
   - User interface for sync operations
   - QR code generation and display
   - Camera-based QR code scanning
   - Progress feedback and statistics

## Usage Guide

### Syncing Data Between Two Devices

#### Device A (Sending Data):
1. Open **Settings** from the main menu
2. Tap on **Data Sync**
3. Select your preferred sync strategy (Merge is recommended)
4. Tap **Generate QR Code**
5. Wait for the QR code to appear
6. Hold the device steady for Device B to scan

#### Device B (Receiving Data):
1. Open **Settings** from the main menu
2. Tap on **Data Sync**
3. Select your preferred sync strategy
4. Tap **Scan QR Code**
5. Grant camera permissions if prompted
6. Point the camera at Device A's QR code
7. Wait for the scan to complete
8. Review the sync results

### Bidirectional Sync
To sync both ways:
1. Device A generates QR code → Device B scans (A → B transfer)
2. Device B generates QR code → Device A scans (B → A transfer)
3. Both devices now have merged data from each other

## Technical Details

### Data Flow

```
Export Flow:
1. Collect all data from repositories
2. Create SyncData object
3. Serialize to JSON
4. Generate QR code from JSON string
5. Display QR code to user

Import Flow:
1. Scan QR code from camera
2. Parse JSON string
3. Deserialize to SyncData object
4. Apply sync strategy (merge/append/replace)
5. Update all repositories
6. Show success/error result
```

### Sync Strategies Implementation

**Merge Strategy:**
- Compares timestamps on items with matching IDs
- Keeps the newer version of each item
- Adds items that only exist on one device
- Products: Uses `updatedAt` timestamp
- Sales: Uses `createdAt` timestamp (no duplicates)

**Append Strategy:**
- Checks if item ID exists on receiving device
- Only adds items with new IDs
- Never modifies existing items

**Replace Strategy:**
- Completely clears all existing data
- Imports all data from sending device
- No comparison or merging

### Data Size Considerations

The sync feature displays the size of data being transferred. For large datasets:
- QR codes can encode up to ~4,296 alphanumeric characters
- For very large datasets, consider chunking the data into multiple QR codes
- Current implementation works well for typical POS data volumes

## Security & Privacy

- All data transfer is local (device-to-device)
- No data is sent to external servers
- QR codes are temporary and only displayed during sync
- Device IDs help track sync sources

## Permissions Required

### Android
- **Camera**: Required for scanning QR codes
- Already configured in the app manifest

### iOS
- **Camera**: Required for scanning QR codes
- Permission request handled automatically

## Troubleshooting

### QR Code Won't Scan
- Ensure good lighting
- Hold devices steady
- Make sure QR code is fully visible on screen
- Try adjusting the distance between devices

### Sync Failed Error
- Check that both devices have sufficient storage
- Verify that the QR code was scanned completely
- Try using a different sync strategy
- Ensure app has necessary permissions

### Data Not Appearing After Sync
- Check the sync results screen for import counts
- Verify the correct sync strategy was selected
- If using "Append", data might not show if IDs already exist
- Try "Merge" strategy for better results

### Large Data Warning
- If you have thousands of items, sync may take longer
- Consider syncing in smaller batches
- Break data into categories if needed

## Future Enhancements

Potential improvements for future versions:
- [ ] Chunked QR codes for very large datasets
- [ ] Selective sync (choose specific data types)
- [ ] Sync history and logs
- [ ] Scheduled automatic sync
- [ ] Cloud backup integration
- [ ] Conflict resolution UI for manual merge
- [ ] Data compression for QR codes
- [ ] WiFi Direct transfer for faster sync

## API Reference

### SyncService Methods

```dart
// Get unique device identifier
Future<String> getDeviceId()

// Export all data
Future<SyncData> exportAllData()

// Convert SyncData to JSON
String syncDataToJson(SyncData syncData)

// Parse JSON to SyncData
SyncData jsonToSyncData(String jsonString)

// Import data with strategy
Future<SyncResult> importData(SyncData incomingData, {SyncStrategy strategy})

// Calculate data size
int calculateDataSize(SyncData syncData)

// Format size for display
String formatDataSize(int bytes)
```

### SyncProvider Methods

```dart
// Export data and prepare QR code
Future<void> exportData()

// Import from scanned QR code
Future<void> importData(String qrDataString)

// Start scanning mode
void startScanning()

// Reset to idle state
void reset()

// Set sync strategy
void setStrategy(SyncStrategy strategy)

// Get sync statistics
Map<String, dynamic> getSyncStats()
```

## File Structure

```
lib/
├── models/
│   └── sync_data.dart              # Data model for sync
├── services/
│   └── sync_service.dart           # Core sync logic
├── providers/
│   └── sync_provider.dart          # State management
├── repositories/
│   ├── product_repository.dart     # Updated with replaceAll
│   ├── category_repository.dart    # Updated with replaceAll
│   ├── customer_repository.dart    # New repository
│   ├── employee_repository.dart    # New repository
│   ├── store_repository.dart       # New repository
│   └── sale_repository.dart        # Updated with replaceAll
└── ui/
    └── pages/
        └── sync_page.dart          # UI for sync feature
```

## Dependencies Used

- `qr_flutter: ^4.1.0` - QR code generation
- `mobile_scanner: ^5.1.1` - QR code scanning
- `device_info_plus: ^10.1.0` - Device identification
- `provider: ^6.1.2` - State management

## Testing Recommendations

1. **Test with empty databases** - Verify sync works with no data
2. **Test with large datasets** - Ensure performance is acceptable
3. **Test all sync strategies** - Verify each strategy behaves correctly
4. **Test conflict scenarios** - Same ID, different timestamps
5. **Test camera permissions** - Handle denied permissions gracefully
6. **Test QR code generation** - Various data sizes
7. **Test error handling** - Invalid QR codes, malformed data

## Support

For issues or questions about the sync feature:
1. Check the troubleshooting section above
2. Review the sync results screen for detailed error messages
3. Verify all dependencies are properly installed
4. Check device permissions in system settings

---

**Version:** 1.0.0  
**Last Updated:** January 2026  
**Status:** ✅ Production Ready
