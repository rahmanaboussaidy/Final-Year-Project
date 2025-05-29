import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:inventory/screens/scan/BarcodeScannerScreen%20.dart';
import 'package:intl/intl.dart';

class ProductRegistrationScreen extends StatefulWidget {
  const ProductRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<ProductRegistrationScreen> createState() =>
      _ProductRegistrationScreenState();
}

class _ProductRegistrationScreenState extends State<ProductRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  late final DatabaseReference _userRef;
  late final DatabaseReference _productRef;

  String? barcode;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  String? selectedUnit;
  String? selectedCategory;

  List<String> units = [];
  List<String> categories = [];

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _userRef = FirebaseDatabase.instance.ref().child(
        'user_inventory/${currentUser!.uid}',
      );
      _productRef = _userRef.child('products');
      _fetchUnits();
      _fetchCategories();
    }
  }

  void _fetchUnits() async {
    final snapshot = await _userRef.child('units').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      setState(() {
        units = data.values.map<String>((e) => e.toString()).toList();
      });
    }
  }

  void _fetchCategories() async {
    final snapshot = await _userRef.child('categories').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      setState(() {
        categories = data.values.map<String>((e) => e.toString()).toList();
      });
    }
  }

  void _showAddDialog(String type) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Add New ${type == 'unit' ? 'Unit' : 'Category'}'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '${type == 'unit' ? 'Unit' : 'Category'} Name',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) {
                    await _userRef
                        .child(type == 'unit' ? 'units' : 'categories')
                        .push()
                        .set(value);
                    Navigator.pop(context);
                    if (type == 'unit') {
                      _fetchUnits();
                    } else {
                      _fetchCategories();
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  void _scanBarcode() async {
    final barcodeResult = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );

    if (barcodeResult != null && mounted) {
      setState(() {
        barcode = barcodeResult;
      });
    }
  }

  void _submitProduct() async {
    if (_formKey.currentState!.validate() && barcode != null) {
      final snapshot = await _productRef.child(barcode!).get();
      final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      if (snapshot.exists) {
        final existingData = snapshot.value as Map;
        final existingQty =
            int.tryParse(existingData['quantity'].toString()) ?? 0;
        final addedQty = int.tryParse(quantityController.text) ?? 0;

        await _productRef.child(barcode!).update({
          'quantity': existingQty + addedQty,
        });
      } else {
        await _productRef.child(barcode!).set({
          'barcode': barcode!,
          'name': nameController.text,
          'price': priceController.text,
          'unit': selectedUnit,
          'quantity': quantityController.text,
          'category': selectedCategory,
          'date_added': now,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product saved successfully')),
      );

      nameController.clear();
      priceController.clear();
      quantityController.clear();
      setState(() {
        barcode = null;
        selectedUnit = null;
        selectedCategory = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the form and scan the barcode'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Product")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(
                  barcode != null ? "Scanned: $barcode" : "Scan Barcode",
                  style: const TextStyle(color: Colors.white),
                ),
                onPressed: _scanBarcode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Product Name',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter product name',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) => value!.isEmpty ? 'Enter product name' : null,
              ),

              const SizedBox(height: 8),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Price',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter price',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Enter price' : null,
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Unit',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedUnit,
                      items:
                          units.map((unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                      onChanged:
                          (value) => setState(() => selectedUnit = value),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select unit',
                      ),
                      validator:
                          (value) => value == null ? 'Select unit' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () => _showAddDialog('unit'),
                      tooltip: 'Add Unit',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quantity',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter quantity',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Enter quantity' : null,
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Category',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items:
                          categories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                      onChanged:
                          (value) => setState(() => selectedCategory = value),
                      decoration: const InputDecoration(
                        hintText: 'Select category',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (value) => value == null ? 'Select category' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () => _showAddDialog('category'),
                      tooltip: 'Add Category',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Submit Product"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
