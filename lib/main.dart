import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ui/pages/simple_products_page.dart';
import 'ui/pages/simple_sales_page.dart';
import 'ui/pages/sync_page.dart';
import 'providers/sync_provider.dart';

void main() {
  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: MaterialApp(
        title: 'Simple POS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple POS System'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Add sync button in app bar
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Device Sync',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SyncPage()),
              );
            },
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? const SimpleProductsPage()
          : const SimpleSalesPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale),
            label: 'Sales',
          ),
        ],
      ),
    );
  }
}
