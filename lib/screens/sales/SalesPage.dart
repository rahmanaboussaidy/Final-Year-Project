import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'barcode_scanner_page.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({Key? key}) : super(key: key);

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Map<String, dynamic> cart = {};
  double totalAmount = 0.0;
  bool isScanning = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    if (isScanning) return;
    setState(() {
      isScanning = true;
    });

    final barcode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
    );

    if (barcode != null && barcode is String) {
      await _addProductToCart(barcode);
    }

    setState(() {
      isScanning = false;
    });
  }

  Future<void> _addProductToCart(String barcode) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showMessage('User not logged in');
      return;
    }
    final userId = user.uid;

    final productSnap =
        await _db.child('user_inventory/$userId/products/$barcode').get();

    if (!productSnap.exists) {
      _showMessage('Product not found in inventory!');
      return;
    }

    final product = Map<String, dynamic>.from(productSnap.value as Map);
    final availableQuantity = int.tryParse(product['quantity'].toString()) ?? 0;
    final price = double.tryParse(product['price'].toString()) ?? 0.0;

    if (cart.containsKey(barcode)) {
      int currentQty = cart[barcode]['quantity'];
      if (currentQty + 1 > availableQuantity) {
        _showMessage('Cannot add more than available stock!');
        return;
      }
      cart[barcode]['quantity'] = currentQty + 1;
      cart[barcode]['subtotal'] = (currentQty + 1) * price;
    } else {
      if (availableQuantity == 0) {
        _showMessage('Product is out of stock!');
        return;
      }
      cart[barcode] = {
        'name': product['name'],
        'price': price,
        'quantity': 1,
        'unit': product['unit'],
        'subtotal': price,
      };
    }

    _calculateTotal();
    setState(() {});
  }

  void _calculateTotal() {
    totalAmount = 0.0;
    cart.forEach((key, product) {
      totalAmount += product['subtotal'];
    });
  }

  void _removeFromCart(String barcode) {
    cart.remove(barcode);
    _calculateTotal();
    setState(() {});
  }

  void _updateQuantity(String barcode, int newQty) {
    if (newQty <= 0) {
      _removeFromCart(barcode);
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    final userId = user.uid;

    _db.child('user_inventory/$userId/products/$barcode').get().then((snap) {
      if (!snap.exists) {
        _showMessage('Product no longer exists in inventory!');
        return;
      }
      final productData = Map<String, dynamic>.from(snap.value as Map);
      final availableQuantity =
          int.tryParse(productData['quantity'].toString()) ?? 0;

      if (newQty > availableQuantity) {
        _showMessage('Cannot set quantity more than available stock!');
        return;
      }

      final price = double.tryParse(productData['price'].toString()) ?? 0.0;
      cart[barcode]['quantity'] = newQty;
      cart[barcode]['subtotal'] = newQty * price;
      _calculateTotal();
      setState(() {});
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _cancelSale() {
    cart.clear();
    totalAmount = 0.0;
    setState(() {});
  }

  Future<void> _finalizeSale() async {
    if (cart.isEmpty) {
      _showMessage('Cart is empty. Please add products before finalizing.');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _showMessage('User not logged in');
      return;
    }
    final userId = user.uid;

    final saleId = _db.child('user_inventory/$userId/sales').push().key;
    if (saleId == null) {
      _showMessage('Failed to create sale record.');
      return;
    }

    // Check stock and update inventory atomically
    for (final barcode in cart.keys) {
      final soldQty = cart[barcode]['quantity'];
      final productRef = _db.child('user_inventory/$userId/products/$barcode');
      final productSnap = await productRef.get();

      if (!productSnap.exists) {
        _showMessage('Product $barcode no longer exists in inventory!');
        return;
      }

      final productData = Map<String, dynamic>.from(productSnap.value as Map);
      int currentQty = int.tryParse(productData['quantity'].toString()) ?? 0;
      if (soldQty > currentQty) {
        _showMessage(
          'Insufficient stock for product ${cart[barcode]['name']}!',
        );
        return;
      }
    }

    // Update inventory quantities
    for (final barcode in cart.keys) {
      final soldQty = cart[barcode]['quantity'];
      final productRef = _db.child('user_inventory/$userId/products/$barcode');
      final productSnap = await productRef.get();

      final productData = Map<String, dynamic>.from(productSnap.value as Map);
      int currentQty = int.tryParse(productData['quantity'].toString()) ?? 0;
      int newQty = (currentQty - soldQty).toInt();
      await productRef.update({'quantity': newQty.toString()});
    }

    // Save sale record - amountReceived is always equal to totalAmount
    await _db.child('user_inventory/$userId/sales/$saleId').set({
      'products':
          cart.entries
              .map(
                (e) => {
                  'barcode': e.key,
                  'name': e.value['name'],
                  'quantity': e.value['quantity'],
                  'unit': e.value['unit'],
                  'price': e.value['price'],
                  'subtotal': e.value['subtotal'],
                },
              )
              .toList(),
      'totalAmount': totalAmount,
      'amountReceived': totalAmount, // force full payment
      'changeDue': 0,
      'saleDate': DateTime.now().toIso8601String(),
    });

    _showMessage(
      'Sale completed! Payment received: TZs ${totalAmount.toStringAsFixed(2)}',
    );

    _cancelSale();
  }

  Widget _buildCartList() {
    if (cart.isEmpty) {
      return const Center(child: Text('Cart is empty. Scan products to add.'));
    }

    return ListView(
      shrinkWrap: true,
      children:
          cart.entries.map((entry) {
            final barcode = entry.key;
            final product = entry.value;

            return ListTile(
              title: Text('${product['name']} (${product['unit']})'),
              subtitle: Text(
                'Unit Price: TZs ${product['price']} | Subtotal: TZs ${product['subtotal'].toStringAsFixed(2)}',
              ),
              trailing: SizedBox(
                width: 180,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle),
                      onPressed: () {
                        int newQty = product['quantity'] - 1;
                        _updateQuantity(barcode, newQty);
                      },
                    ),
                    Text(product['quantity'].toString()),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: () {
                        int newQty = product['quantity'] + 1;
                        _updateQuantity(barcode, newQty);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeFromCart(barcode),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Product'),
              onPressed: isScanning ? null : _scanBarcode,
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildCartList()),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Total: TSh ${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: cart.isEmpty ? null : _finalizeSale,
                  child: const Text('Finalize Sale'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: cart.isEmpty ? null : _cancelSale,
                  child: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
