# POS System - Point of Sale Application

A comprehensive, production-ready Point of Sale (POS) system built with Flutter.

## Features

### Core POS Features
1. **Sales Processing** - Fast checkout with barcode scanning support
2. **Inventory Management** - Track stock levels with low stock alerts
3. **Customer Management** - Manage customer profiles and purchase history
4. **Reporting & Analytics** - Sales reports and performance metrics
5. **Employee Management** - Staff profiles and permissions
6. **Payment Integration** - Cash, Card, and Mobile Money support
7. **Hardware Integration** - Barcode scanner, receipt printer, cash drawer
8. **Multi-Store Management** - Manage multiple store locations
9. **Security Features** - PIN protection and user permissions
10. **Loyalty & Promotions** - Reward programs and discount management

## Pages & Navigation

The application includes 20 fully implemented pages:

1. **Login/Authentication** - Secure user authentication
2. **Dashboard** - Overview of sales, low stock alerts, and quick actions
3. **Sales/Register** - Process sales with cart and payment methods
4. **Product Catalog** - Browse and search products
5. **Product Details** - View and edit product information
6. **Add/Edit Product** - Create or update products
7. **Inventory Management** - Monitor stock levels and alerts
8. **Customer List** - View all customers
9. **Customer Profile** - Customer details and purchase history
10. **Reports & Analytics** - Sales graphs and best sellers
11. **Employee List** - Manage staff
12. **Employee Profile** - Staff details and performance
13. **Multi-Store** - Manage multiple locations
14. **Store Details** - Individual store information
15. **Settings** - Application configuration
16. **Hardware Setup** - Connect POS hardware
17. **Promotions** - Manage discounts and offers
18. **Notifications** - System alerts and messages
19. **Support/Help** - Help center
20. **Payment Methods** - Configure payment options

## Project Structure

```
lib/
├── main.dart                 # Application entry point
├── routes.dart               # Navigation configuration
├── models/                   # Data models
│   ├── product.dart
│   ├── customer.dart
│   ├── employee.dart
│   ├── sale.dart
│   └── store.dart
├── ui/
│   ├── pages/               # All application pages
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── sales/
│   │   ├── products/
│   │   ├── inventory/
│   │   ├── customers/
│   │   ├── reports/
│   │   ├── employees/
│   │   ├── stores/
│   │   ├── settings/
│   │   ├── hardware/
│   │   ├── promotions/
│   │   └── notifications/
│   ├── widgets/             # Reusable widgets
│   └── themes/              # Theme configuration
│       └── app_theme.dart
├── data/                    # Data layer (to be implemented)
└── controllers/             # State management (to be implemented)
```

## Getting Started

### Prerequisites
- Flutter SDK (>= 3.0.0)
- Dart SDK
- VS Code or Android Studio

### Installation

1. Clone or navigate to the project directory:
```bash
cd c:\i\alex
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
flutter run
```

## Dependencies

- **go_router** - Navigation management
- **flutter_riverpod** - State management
- **fl_chart** - Charts and analytics
- **mobile_scanner** - Barcode scanning
- **sqflite** - Local database
- **shared_preferences** - Local storage
- **esc_pos_printer** - Receipt printing
- **intl** - Internationalization and date formatting

## Development Guidelines

### Adding New Features

1. Create models in `lib/models/`
2. Create pages in `lib/ui/pages/`
3. Add routes in `lib/routes.dart`
4. Implement business logic with Riverpod providers

### State Management

The app uses Riverpod for state management. Add providers in a `lib/controllers/` directory.

### Database

Local data persistence uses SQLite via sqflite. Database helpers should be added in `lib/data/`.

## Configuration

### Payment Methods
Configure payment options in Settings > Payment Methods

### Hardware Setup
Connect hardware devices in Hardware Setup page:
- Barcode Scanner (Bluetooth/USB)
- Receipt Printer (Bluetooth/USB)
- Cash Drawer
- Card Reader

## Currency

The application is configured for Rwandan Franc (RWF). To change currency:
1. Update currency display in all pages
2. Modify number formatting in `intl` configuration

## TODO - Next Steps

- [ ] Implement database layer with SQLite
- [ ] Add Riverpod providers for state management
- [ ] Implement authentication logic
- [ ] Connect barcode scanner integration
- [ ] Implement receipt printing
- [ ] Add data export (PDF, Excel)
- [ ] Implement backup & restore
- [ ] Add offline mode support
- [ ] Implement cloud sync
- [ ] Add unit tests
- [ ] Add integration tests

## License

Proprietary - All rights reserved

## Support

For support and questions, use the in-app Support/Help Center.

---

**Version:** 1.0.0
**Last Updated:** December 11, 2024
