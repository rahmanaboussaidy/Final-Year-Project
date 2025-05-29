import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({Key? key}) : super(key: key);

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  final user = FirebaseAuth.instance.currentUser;
  final dbRef = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> salesList = [];
  bool isLoading = true;
  String errorMessage = '';

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    fetchSales();
  }

  Future<void> fetchSales() async {
    if (user == null) {
      setState(() {
        errorMessage = "User not logged in.";
        isLoading = false;
      });
      return;
    }

    try {
      final salesSnapshot = await dbRef.child('user_inventory/${user!.uid}/sales').get();

      if (salesSnapshot.exists && salesSnapshot.value != null) {
        final salesMap = Map<String, dynamic>.from(salesSnapshot.value as Map);

        List<Map<String, dynamic>> tempSalesList = salesMap.entries.map((entry) {
          final saleData = Map<String, dynamic>.from(entry.value);
          saleData['id'] = entry.key; // sale id

          // Convert products list safely
          if (saleData['products'] != null) {
            // Firebase sometimes returns products as Map or List, handle both
            if (saleData['products'] is List) {
              saleData['products'] = List<Map<String, dynamic>>.from(
                (saleData['products'] as List).map((p) => Map<String, dynamic>.from(p)),
              );
            } else if (saleData['products'] is Map) {
              // If products stored as Map of maps, convert to list
              final productMap = Map<String, dynamic>.from(saleData['products']);
              saleData['products'] = productMap.entries
                  .map((e) => Map<String, dynamic>.from(e.value))
                  .toList();
            } else {
              saleData['products'] = [];
            }
          } else {
            saleData['products'] = [];
          }

          return saleData;
        }).toList();

        setState(() {
          salesList = tempSalesList;
          isLoading = false;
        });
      } else {
        setState(() {
          salesList = [];
          isLoading = false;
          errorMessage = "No sales records found.";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching sales: $e";
        isLoading = false;
      });
    }
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

  Widget buildSalesTable() {
    if (salesList.isEmpty) {
      return const Center(child: Text("No sales data to display."));
    }

    final filteredSales = salesList.where((sale) {
      final dateStr = sale['saleDate'] ?? '';
      return _isWithinRange(dateStr);
    }).toList();

    return ListView.builder(
      itemCount: filteredSales.length,
      itemBuilder: (context, index) {
        final sale = filteredSales[index];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ExpansionTile(
            title: Text(
              "Sale ID: ${sale['id']}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Date: ${sale['saleDate'] ?? 'Unknown'}\n"
              "Total: ${sale['amountReceived'] ?? '0'}\n"
              // "Status: ${sale['status'] ?? 'Paid'}",
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Products:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Quantity')),
                    DataColumn(label: Text('Unit Price')),
                    DataColumn(label: Text('Subtotal')),
                    DataColumn(label: Text('Unit')),
                  ],
                  rows: sale['products'].map<DataRow>((product) {
                    final quantity = int.tryParse(product['quantity'].toString()) ?? 0;
                    final price = double.tryParse(product['price'].toString()) ?? 0.0;
                    final subtotal = quantity * price;

                    return DataRow(cells: [
                      DataCell(Text(product['name'] ?? '')),
                      DataCell(Text(quantity.toString())),
                      DataCell(Text(price.toStringAsFixed(2))),
                      DataCell(Text(subtotal.toStringAsFixed(2))),
                      DataCell(Text(product['unit'] ?? '')),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportSalesToCSV(List<Map<String, dynamic>> filteredSales) async {
    if (filteredSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No sales in selected date range.')));
      return;
    }

    String fromDate = _startDate != null
        ? "${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}"
        : "Beginning";
    String toDate = _endDate != null
        ? "${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}"
        : "Now";
    String generatedOn = DateTime.now().toString().split('.')[0];

    final List<List<dynamic>> rows = [
      ['Sales Report'],
      ['From:', fromDate, 'To:', toDate],
      ['Generated on:', generatedOn],
      [],
      ['Sale ID', 'Date', 'Total', 'Products'],
    ];
    for (final sale in filteredSales) {
      rows.add([
        sale['id'],
        sale['saleDate'] ?? '',
        sale['amountReceived'] ?? '',
        (sale['products'] as List).map((p) => "${p['name']} x${p['quantity']}").join('; ')
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sales_report.csv');
    await file.writeAsString(csvData);

    await OpenFile.open(file.path);
  }

  Future<void> _exportSalesToPDF(List<Map<String, dynamic>> filteredSales) async {
    if (filteredSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No sales in selected date range.')));
      return;
    }

    String fromDate = _startDate != null
        ? "${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}"
        : "Beginning";
    String toDate = _endDate != null
        ? "${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}"
        : "Now";
    String generatedOn = DateTime.now().toString().split('.')[0];

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Text('Sales Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('From: $fromDate    To: $toDate', style: pw.TextStyle(fontSize: 14)),
          pw.Text('Generated on: $generatedOn', style: pw.TextStyle(fontSize: 12, color: PdfColor.fromInt(0xFF888888))),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Sale ID', 'Date', 'Total', 'Products'],
            data: filteredSales.map((sale) => [
              sale['id'],
              sale['saleDate'] ?? '',
              sale['amountReceived'] ?? '',
              (sale['products'] as List).map((p) => "${p['name']} x${p['quantity']}").join('; ')
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
    final file = File('${dir.path}/sales_report.pdf');
    await file.writeAsBytes(await pdf.save());

    await OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = '';
              });
              fetchSales();
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () {
              final filteredSales = salesList.where((sale) {
                final dateStr = sale['saleDate'] ?? '';
                return _isWithinRange(dateStr);
              }).toList();
              _exportSalesToPDF(filteredSales);
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Export CSV',
            onPressed: () {
              final filteredSales = salesList.where((sale) {
                final dateStr = sale['saleDate'] ?? '';
                return _isWithinRange(dateStr);
              }).toList();
              _exportSalesToCSV(filteredSales);
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
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
                              child: Text(
                                _startDate == null
                                    ? 'Start Date'
                                    : _startDate!.toString().split(' ')[0],
                              ),
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
                              child: Text(
                                _endDate == null
                                    ? 'End Date'
                                    : _endDate!.toString().split(' ')[0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: buildSalesTable()),
                  ],
                ),
    );
  }
}
