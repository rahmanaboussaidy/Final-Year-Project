import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late DatabaseReference dbRef;
  late String userId;
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid;
    dbRef = FirebaseDatabase.instance.ref().child('user_inventory/$userId/products');
  }

  Future<List<String>> _fetchUnits() async {
    final unitsSnapshot = await FirebaseDatabase.instance.ref('user_inventory/$userId/units').get();
    if (unitsSnapshot.exists) {
      final unitsMap = Map<String, dynamic>.from(unitsSnapshot.value as Map);
      return unitsMap.values.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<List<String>> _fetchCategories() async {
    final categoriesSnapshot = await FirebaseDatabase.instance.ref('user_inventory/$userId/categories').get();
    if (categoriesSnapshot.exists) {
      final categoriesMap = Map<String, dynamic>.from(categoriesSnapshot.value as Map);
      return categoriesMap.values.map((e) => e.toString()).toList();
    }
    return [];
  }

  void _showEditDialog(String barcode, Map<String, dynamic> product) async {
    final nameController = TextEditingController(text: product['name']);
    final priceController = TextEditingController(text: product['price']);
    final quantityController = TextEditingController(text: product['quantity']);
    String selectedUnit = product['unit'];
    String selectedCategory = product['category'];

    final units = await _fetchUnits();
    final categories = await _fetchCategories();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
              TextField(controller: quantityController, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                items: units.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                onChanged: (value) => setState(() => selectedUnit = value ?? selectedUnit),
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (value) => setState(() => selectedCategory = value ?? selectedCategory),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              dbRef.child(barcode).update({
                'name': nameController.text,
                'price': priceController.text,
                'quantity': quantityController.text,
                'unit': selectedUnit,
                'category': selectedCategory,
              }).then((_) => Navigator.pop(context));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(String barcode) {
    dbRef.child(barcode).remove();
  }

  Future<void> _exportToCSV() async {
    if (_filteredProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No products in selected date range.')));
      return;
    }

    // Prepare date range strings
    String fromDate = _startDate != null
        ? "${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}"
        : "Beginning";
    String toDate = _endDate != null
        ? "${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}"
        : "Now";
    String generatedOn = DateTime.now().toString().split('.')[0];

    final List<List<dynamic>> rows = [
      ['Inventory Report'],
      ['From:', fromDate, 'To:', toDate],
      ['Generated on:', generatedOn],
      [], // Empty row for spacing
      ['Barcode', 'Name', 'Price', 'Quantity', 'Unit', 'Category', 'Date Added'],
    ];
    for (final p in _filteredProducts) {
      rows.add([
        p['barcode'],
        p['name'],
        p['price'],
        p['quantity'],
        p['unit'],
        p['category'],
        p['date_added'],
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/inventory_export.csv');
    await file.writeAsString(csvData);

    await OpenFile.open(file.path);
  }

  Future<void> _exportToPDF() async {
    if (_filteredProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No products in selected date range.')));
      return;
    }

    final pdf = pw.Document();

    // Prepare date range strings
    String fromDate = _startDate != null ? "${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}" : "Beginning";
    String toDate = _endDate != null ? "${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}" : "Now";
    String generatedOn = DateTime.now().toString().split('.')[0];

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Text(
            'Inventory Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('From: $fromDate    To: $toDate', style: pw.TextStyle(fontSize: 14)),
          pw.Text('Generated on: $generatedOn', style: pw.TextStyle(fontSize: 12, color: PdfColor.fromInt(0xFF888888))),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Barcode', 'Name', 'Price', 'Quantity', 'Unit', 'Category', 'Date Added'],
            data: _filteredProducts.map((p) => [
              p['barcode'],
              p['name'],
              p['price'],
              p['quantity'],
              p['unit'],
              p['category'],
              p['date_added'],
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFFFFFFFF)),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF1976D2)),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(fontSize: 10),
            cellHeight: 25,
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/inventory_export.pdf');
    await file.writeAsBytes(await pdf.save());

    await OpenFile.open(file.path);
  }

  bool _isWithinRange(String dateStr) {
    if (_startDate == null && _endDate == null) return true;
    try {
      final date = DateTime.parse(dateStr);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final start = _startDate != null ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day) : null;
      final end = _endDate != null ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day) : null;

      if (start != null && dateOnly.isBefore(start)) return false;
      if (end != null && dateOnly.isAfter(end)) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {}); // This will rebuild and refresh the StreamBuilder
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _exportToPDF,
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Export CSV',
            onPressed: _exportToCSV,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: StreamBuilder<DatabaseEvent>(
          stream: dbRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return const Center(child: Text('Something went wrong.'));
            final data = snapshot.data?.snapshot.value;
            if (data == null) return const Center(child: Text('No products found.'));

            final productsMap = Map<String, dynamic>.from(data as Map);
            final products = productsMap.entries.map((entry) {
              final product = Map<String, dynamic>.from(entry.value);
              return {'barcode': entry.key, ...product};
            }).toList();

            final filteredProducts = products.where((p) {
              final dateStr = p['date_added'];
              return _isWithinRange(dateStr);
            }).toList();

            _filteredProducts = filteredProducts;

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _startDate = picked);
                        },
                        child: Text(_startDate == null ? 'Start Date' : _startDate!.toString().split(' ')[0]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _endDate = picked);
                        },
                        child: Text(_endDate == null ? 'End Date' : _endDate!.toString().split(' ')[0]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final p = filteredProducts[index];
                      final int quantity = int.tryParse(p['quantity'].toString()) ?? 0;

                      String status = 'Out of Stock';
                      Color statusColor = Colors.red;
                      if (quantity > 10) {
                        status = 'In Stock';
                        statusColor = Colors.green;
                      } else if (quantity > 0) {
                        status = 'Low in Stock';
                        statusColor = Colors.orange;
                      }

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(p['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Quantity: $quantity ${p['unit']}'),
                              Text('Category: ${p['category']}'),
                              Text('Added: ${p['date_added']}'),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text('Status: '),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      border: Border.all(color: statusColor),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showEditDialog(p['barcode'], p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteProduct(p['barcode']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
