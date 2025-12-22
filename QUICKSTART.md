# Quick Start Guide - POS System

## 🚀 Getting Your POS System Running

### Step 1: Install Dependencies

Open terminal in the project directory and run:

```bash
flutter pub get
```

### Step 2: Run the Application

#### For Desktop (Windows)

```bash
flutter run -d windows
```

#### For Android Emulator

```bash
flutter run
```

#### For Web

```bash
flutter run -d chrome
```

### Step 3: Login

- The login page will appear
- Enter any email and password (authentication is not yet implemented)
- Click "Login" to access the dashboard

## 📱 Navigation Guide

### Main Menu (Drawer)

Access the menu by clicking the hamburger icon (☰) in the top-left:

- **Dashboard** - Overview & quick stats
- **Sales** - Process transactions
- **Products** - Product catalog
- **Inventory** - Stock management
- **Customers** - Customer database
- **Reports** - Analytics & reports
- **Employees** - Staff management
- **Stores** - Multi-location management
- **Promotions** - Discounts & offers
- **Hardware** - Connect devices
- **Settings** - Configuration

### Key Workflows

#### Processing a Sale

1. Go to **Sales** page
2. Click "+" button next to products to add to cart
3. Review cart items
4. Click **Checkout**
5. Select payment method (Cash/Card/Mobile Money)
6. Sale is completed!

#### Adding a Product

1. Go to **Products** page
2. Click **Add Product** button
3. Fill in product details
4. Click **Add Product**

#### Managing Inventory

1. Go to **Inventory** page
2. View low stock alerts
3. Click **Add Stock** for items that need restocking
4. Use **Bulk Update** for multiple items

#### Viewing Reports

1. Go to **Reports** page
2. View sales graphs
3. Check best-selling products
4. Export reports (PDF/Excel)

## 🎯 Key Features to Try

### Sales Processing
- **Barcode Scanner**: Click the scan icon to scan products
- **Multiple Items**: Add multiple quantities
- **Remove Items**: Use the (-) button in cart

### Customer Management
- Add customers with phone and email
- View purchase history
- Track loyalty points (coming soon)

### Hardware Integration
- Connect barcode scanners
- Setup receipt printers
- Configure cash drawers

## ⚙️ Configuration

### First-Time Setup

1. Go to **Settings**
2. Configure:
   - Business Information
   - Payment Methods
   - Receipt Format
   - User Permissions

### Hardware Setup

1. Go to **Hardware Setup**
2. Click **Connect** for each device
3. Follow on-screen instructions

## 🔧 Troubleshooting

### App Won't Run
```bash
# Clean the project
flutter clean

# Get dependencies again
flutter pub get

# Run the app
flutter run
```

### Hot Reload Not Working
- Press `r` in terminal for hot reload
- Press `R` for hot restart

### Build Errors
- Check that Flutter SDK is properly installed: `flutter doctor`
- Ensure all dependencies are installed: `flutter pub get`

## 📊 Sample Data

The app comes with sample data for testing:

**Products:**
- Coca Cola (120 in stock, 1000 RWF)
- Bread (30 in stock, 800 RWF)
- Sugar (12 in stock, 1500 RWF)

**Customers:**
- John Doe (12 purchases)
- Mary Jane (4 purchases)

**Employees:**
- Alice Johnson (Cashier)
- Bob Smith (Manager)

## 🔐 Security Features

### Default Credentials
- Email: any email
- Password: any password
- **Note**: Implement proper authentication before production use!

### User Permissions
Configure in **Settings > User Permissions**

## 💡 Tips & Best Practices

1. **Regular Backups**: Use Settings > Backup & Restore
2. **Low Stock Alerts**: Check Inventory page daily
3. **Daily Reports**: Review sales in Reports page
4. **Staff Training**: Use Help Center for training materials
5. **Hardware Testing**: Test all hardware before opening

## 📞 Need Help?

- Check the **Help Center** in the app
- Review the main README.md for detailed information
- Check the TODO list for features in development

## 🎨 Customization

### Change Theme Colors

Edit `lib/ui/themes/app_theme.dart`:

```dart
colorScheme: ColorScheme.fromSeed(
  seedColor: Colors.blue, // Change this color
  brightness: Brightness.light,
),
```

### Modify Currency

Search and replace "RWF" with your currency code throughout the app.

---

**Happy Selling! 🎉**
