import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();
  late String uid;

  int totalSalesToday = 0;
  int totalRevenueToday = 0;
  int totalProductsInStock = 0;
  int lowStockCount = 0;
  int allTimeRevenue = 0;
  List<Map<String, dynamic>> recentSales = [];
  List<Map<String, dynamic>> lowStockItems = [];

  @override
  void initState() {
    super.initState();
    uid = _auth.currentUser!.uid;
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final salesSnapshot = await _dbRef.child('user_inventory/$uid/sales').get();
    final productsSnapshot = await _dbRef.child('user_inventory/$uid/products').get();

    if (salesSnapshot.exists) {
      List<Map<String, dynamic>> salesList = [];
      int todaySales = 0;
      int todayRevenue = 0;
      int totalRevenue = 0;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (final saleEntry in salesSnapshot.children) {
        final data = saleEntry.value as Map;
        final saleDateStr = data['saleDate'] as String?;
        final totalAmount = int.tryParse(data['totalAmount'].toString()) ?? 0;

        if (saleDateStr != null) {
          final saleDate = DateTime.parse(saleDateStr);
          if (DateFormat('yyyy-MM-dd').format(saleDate) == today) {
            todaySales++;
            todayRevenue += totalAmount;
          }
        }

        totalRevenue += totalAmount;
        salesList.add({
          'date': saleDateStr ?? '',
          'amount': totalAmount,
        });
      }

      salesList.sort((a, b) => b['date'].compareTo(a['date']));

      setState(() {
        totalSalesToday = todaySales;
        totalRevenueToday = todayRevenue;
        allTimeRevenue = totalRevenue;
        recentSales = salesList.take(5).toList();
      });
    }

    if (productsSnapshot.exists) {
      int totalStock = 0;
      int lowStock = 0;
      List<Map<String, dynamic>> lowStockList = [];

      for (final product in productsSnapshot.children) {
        final data = product.value as Map;
        final quantity = int.tryParse(data['quantity'].toString()) ?? 0;

        totalStock += quantity;
        if (quantity <= 2) {
          lowStock++;
          lowStockList.add({
            'name': data['name'],
            'quantity': quantity
          });
        }
      }

      setState(() {
        totalProductsInStock = totalStock;
        lowStockCount = lowStock;
        lowStockItems = lowStockList;
      });
    }
  }

  Widget _buildCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(children: [
              _buildCard("Today's Sales", "$totalSalesToday", Colors.blue),
              _buildCard("Revenue Today", "Tsh $totalRevenueToday", Colors.green),
            ]),
            Row(children: [
              _buildCard("Products In Stock", "$totalProductsInStock", Colors.purple),
              _buildCard("Low Stock Count", "$lowStockCount", Colors.redAccent),
            ]),
            Row(children: [
              _buildCard("All-Time Revenue", "Tsh $allTimeRevenue", Colors.teal),
              const Expanded(child: SizedBox()),
            ]),
           const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Low Stock Items", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                ),
                child: DataTable(
                columnSpacing: (constraints.maxWidth - 40) / 2, // Adjust spacing to fill width
                columns: const [
                  DataColumn(label: Text('Product Name')),
                  DataColumn(label: Text('Quantity')),
                ],
                rows: lowStockItems.map((item) {
                  return DataRow(
                  cells: [
                    DataCell(Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Text(item['name'].toString()),
                    ],
                    )),
                    DataCell(Text(item['quantity'].toString())),
                  ],
                  );
                }).toList(),
                dividerThickness: 1,
                dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                  if (states.contains(MaterialState.selected)) {
                    return Colors.grey.shade100;
                  }
                  return null;
                  },
                ),
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                ),
              );
              },
            ),
            
          
            
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Recent Sales", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...recentSales.map((sale) => Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                title: Text(
                  "Amount: Tsh ${sale['amount']}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "Date: ${sale['date']}",
                  style: const TextStyle(color: Colors.grey),
                ),
                leading: const Icon(Icons.attach_money, color: Colors.green),
                ),
              )),
           
          ],
        ),
      ),
    );
  }
}
