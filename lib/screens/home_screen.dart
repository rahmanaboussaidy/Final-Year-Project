import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:inventory/screens/DashboardScreen.dart';
import 'package:inventory/screens/inventory/inventory_page.dart';
import 'package:inventory/screens/profile/profilescreen.dart';
import 'package:inventory/screens/reports/ReportDashboardPage.dart';
import 'package:inventory/screens/sales/SalesPage.dart';
import 'package:inventory/screens/scan/ProductRegistrationScreen%20.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String greeting = "";
  String username = "";

  final List<Widget> _pages = [
    DashboardScreen(),
    ProductRegistrationScreen(), 
    InventoryPage(),
    SalesPage(),
    SalesReportPage(),
  // Add your other pages here
    
  ];

  @override
  void initState() {
    super.initState();
    _setGreeting();
    _fetchUsernameFromRealtimeDatabase();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = "Good morning";
    } else if (hour < 17) {
      greeting = "Good afternoon";
    } else {
      greeting = "Good evening";
    }
  }

  Future<void> _fetchUsernameFromRealtimeDatabase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final DatabaseReference userRef =
          FirebaseDatabase.instance.ref().child('users/$uid');

      final DataSnapshot snapshot = await userRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          username = data['username'] ?? data['fullName'] ?? "User";
        });
      }
    }
  }

  void _goToProfile() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ProfileScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hi, $greeting ${username.isNotEmpty ? username : ''}",
            style: const TextStyle(fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A8A),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: _goToProfile,
          )
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF1E3A8A),
          currentIndex: _currentIndex,
          onTap: (index) => setState(() {
            _currentIndex = index;
          }),
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: "Scan"),
            BottomNavigationBarItem(icon: Icon(Icons.inventory), label: "Inventory"),
            BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: "Sales"),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Report"),
          ],
        ),
      ),
    );
  }
}


