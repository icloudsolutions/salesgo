import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/models/discount.dart';
import 'package:salesgo/models/category.dart';

class ProductManagement extends StatefulWidget {
  const ProductManagement({super.key});

  @override
  _ProductManagementState createState() => _ProductManagementState();
}

class _ProductManagementState extends State<ProductManagement> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedProductCategory;
  final _barcodeController = TextEditingController();
  String? _imageUrl;
  bool _isLoading = false;
  bool _hasDateRange = false; // New flag for date range toggle

  // For categories
  final _categoryNameController = TextEditingController();

  // For discounts
  final _discountNameController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _discountTypeController = TextEditingController();
  String? _selectedDiscountCategory;
  DateTime? _discountStartDate;
  DateTime? _discountEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _barcodeController.dispose();
    _categoryNameController.dispose();
    _discountNameController.dispose();
    _discountValueController.dispose();
    _discountTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('product_images/${DateTime.now().millisecondsSinceEpoch}');
        
        await ref.putFile(File(pickedFile.path));
        _imageUrl = await ref.getDownloadURL();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {

        final categoryRef = FirebaseFirestore.instance
            .collection('categories')
            .doc(_selectedProductCategory);

        final product = Product(
          id: FirebaseFirestore.instance.collection('products').doc().id,
          name: _nameController.text,
          price: double.parse(_priceController.text),
          categoryRef: categoryRef, 
          barcode: _barcodeController.text,
          imageUrl: _imageUrl,
        );

        await FirebaseFirestore.instance
            .collection('products')
            .doc(product.id)
            .set(product.toMap());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );

        // Clear form
        _formKey.currentState!.reset();
        setState(() {
          _imageUrl = null;
          _selectedProductCategory = null;
        });
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProduct(String productId) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {

        final categoryRef = FirebaseFirestore.instance
            .collection('categories')
            .doc(_selectedProductCategory);

        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .update({
              'name': _nameController.text,
              'price': double.parse(_priceController.text),
              'categoryRef': categoryRef, // Using DocumentReference
              'barcode': _barcodeController.text,
              'imageUrl': _imageUrl,
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating product: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addCategory() async {
    if (_categoryNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category name is required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('categories').add({
        'name': _categoryNameController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category added successfully')),
      );

      // Clear form
      _categoryNameController.clear();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding category: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateCategory(String categoryId) async {
    if (_categoryNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category name is required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final categoryRef = FirebaseFirestore.instance.collection('categories').doc(categoryId);
      final oldName = (await categoryRef.get()).data()?['name'];
      final newName = _categoryNameController.text;

      // 1. First update the category name
      await categoryRef.update({'name': newName});

      // 2. Update all products in this category
      final productsQuery = await FirebaseFirestore.instance
          .collection('products')
          .where('categoryId', isEqualTo: oldName)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in productsQuery.docs) {
        batch.update(doc.reference, {'categoryId': newName});
      }

      // 3. Update all discounts for this category
      final discountsQuery = await FirebaseFirestore.instance
          .collection('discounts')
          .where('categoryId', isEqualTo: oldName)
          .get();

      for (final doc in discountsQuery.docs) {
        batch.update(doc.reference, {'categoryId': newName});
      }

      // Commit all updates in a single batch
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category and related items updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating category: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addDiscount() async {
    if (_discountNameController.text.isEmpty ||
        _discountValueController.text.isEmpty ||
        _discountTypeController.text.isEmpty ||
        _selectedDiscountCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Required fields are missing')),
      );
      return;
    }

    // Only validate dates if the user has enabled date range
    if (_hasDateRange) {
      if (_discountStartDate == null || _discountEndDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Date range is enabled but not set')),
        );
        return;
      }

      if (_discountEndDate!.isBefore(_discountStartDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End date must be after start date')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final categoryRef = FirebaseFirestore.instance
          .collection('categories')
          .doc(_selectedDiscountCategory);

      final discountData = {
        'id': FirebaseFirestore.instance.collection('discounts').doc().id,
        'name': _discountNameController.text,
        'categoryRef': categoryRef,  // Store DocumentReference
        'value': double.parse(_discountValueController.text),
        'type': _discountTypeController.text,
        'hasDateRange': _hasDateRange,
        if (_hasDateRange) 'startDate': _discountStartDate!,
        if (_hasDateRange) 'endDate': _discountEndDate!,
      };

      await FirebaseFirestore.instance
          .collection('discounts')
          .doc(discountData['id'] as String?)
          .set(discountData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount added successfully')),
      );

      // Clear form
      _discountNameController.clear();
      _discountValueController.clear();
      _discountTypeController.clear();
      setState(() {
        _selectedDiscountCategory = null;
        _discountStartDate = null;
        _discountEndDate = null;
        _hasDateRange = false;
      });
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding discount: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateDiscount(String discountId) async {
    if (_discountNameController.text.isEmpty ||
        _discountValueController.text.isEmpty ||
        _discountTypeController.text.isEmpty ||
        _selectedDiscountCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Required fields are missing')),
      );
      return;
    }

    // Only validate dates if date range is enabled
    if (_hasDateRange) {
      if (_discountStartDate == null || _discountEndDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Date range is enabled but dates are not set')),
        );
        return;
      }
      if (_discountEndDate!.isBefore(_discountStartDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End date must be after start date')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final categoryRef = FirebaseFirestore.instance
          .collection('categories')
          .doc(_selectedDiscountCategory);

      final updateData = {
        'name': _discountNameController.text,
        'categoryRef': categoryRef,  // Store DocumentReference
        'value': double.parse(_discountValueController.text),
        'type': _discountTypeController.text,
        'hasDateRange': _hasDateRange,
      };

      // Conditionally update dates
      if (_hasDateRange) {
        updateData['startDate'] = _discountStartDate!;
        updateData['endDate'] = _discountEndDate!;
      } else {
        // Remove dates if date range is disabled
        updateData['startDate'] = FieldValue.delete();
        updateData['endDate'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('discounts')
          .doc(discountId)
          .update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating discount: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  // Update the _editDiscount method to handle the new hasDateRange field
  Future<void> _editDiscount(DocumentSnapshot discount) async {
    final data = discount.data() as Map<String, dynamic>;
    _discountNameController.text = data['name'] ?? '';
    _discountValueController.text = data['value'].toString();
    _discountTypeController.text = data['type'];
    // Get the category ID from the DocumentReference
    final categoryRef = data['categoryRef'] as DocumentReference;
    final categorySnapshot = await categoryRef.get();
    _selectedDiscountCategory = categorySnapshot.id;    

    setState(() {
      _hasDateRange = data['hasDateRange'] ?? false;
      if (_hasDateRange) {
        _discountStartDate = (data['startDate'] as Timestamp).toDate();
        _discountEndDate = (data['endDate'] as Timestamp).toDate();
      } else {
        _discountStartDate = null;
        _discountEndDate = null;
      }
    });

    await showDialog(
      context: context,
      builder: (context) => _buildDiscountForm(isEditing: true, discountId: discount.id),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting product: $e')),
      );
    }
  }

  Future<void> _deleteCategory(String categoryId) async {
    try {
      await FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting category: $e')),
      );
    }
  }

  Future<void> _deleteDiscount(String discountId) async {
    try {
      await FirebaseFirestore.instance
          .collection('discounts')
          .doc(discountId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting discount: ${e.toString()}')),
      );
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _discountStartDate) {
      setState(() {
        _discountStartDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _discountStartDate ?? DateTime.now(),
      firstDate: _discountStartDate ?? DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _discountEndDate) {
      setState(() {
        _discountEndDate = picked;
      });
    }
  }

  Future<void> _editProduct(Product product) async {
    _nameController.text = product.name;
    _priceController.text = product.price.toString();
    
    // Get the category ID from the DocumentReference
    final categorySnapshot = await product.categoryRef.get();
    _selectedProductCategory = categorySnapshot.id;
    
    _barcodeController.text = product.barcode;
    setState(() => _imageUrl = product.imageUrl);

    await showDialog(
      context: context,
      builder: (context) => _buildProductForm(isEditing: true, productId: product.id),
    );
  }

  Future<void> _editCategory(DocumentSnapshot category) async {
    _categoryNameController.text = category['name'];

    await showDialog(
      context: context,
      builder: (context) => _buildCategoryForm(isEditing: true, categoryId: category.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag), text: 'Products'),
            Tab(icon: Icon(Icons.category), text: 'Categories'),
            Tab(icon: Icon(Icons.discount), text: 'Discounts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Products Tab
          _buildProductsTab(),
          // Categories Tab
          _buildCategoriesTab(),
          // Discount & Loyalty Tab
          _buildDiscountsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          switch (_tabController.index) {
            case 0: // Products tab
              _nameController.clear();
              _priceController.clear();
              _barcodeController.clear();
              setState(() {
                _imageUrl = null;
                _selectedProductCategory = null;
              });
              showDialog(
                context: context,
                builder: (context) => _buildProductForm(),
              );
              break;
            case 1: // Categories tab
              _categoryNameController.clear();
              //setState(() => _categoryImageUrl = null);
              showDialog(
                context: context,
                builder: (context) => _buildCategoryForm(),
              );
              break;
            case 2: // Discounts tab
              _discountNameController.clear();
              _discountValueController.clear();
              _discountTypeController.clear();
              setState(() {
                _selectedDiscountCategory = null;
                _discountStartDate = null;
                _discountEndDate = null;
              });
              showDialog(
                context: context,
                builder: (context) => _buildDiscountForm(),
              );
              break;
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final product = Product.fromFirestore(doc);
              
              return FutureBuilder<DocumentSnapshot>(
                future: product.categoryRef.get(),
                builder: (context, categorySnapshot) {
                  if (!categorySnapshot.hasData) {
                    return ListTile(
                      leading: product.imageUrl != null 
                          ? Image.network(product.imageUrl!, width: 50, height: 50)
                          : const Icon(Icons.shopping_bag),
                      title: Text(product.name),
                      subtitle: Text('€${product.price} - Loading category...'),
                    );
                  }
                  
                  final categoryName = categorySnapshot.data!['name'] ?? 'Unknown';
                  
                  return ListTile(
                    leading: product.imageUrl != null 
                        ? Image.network(product.imageUrl!, width: 50, height: 50)
                        : const Icon(Icons.shopping_bag),
                    title: Text(product.name),
                    subtitle: Text('€${product.price} - $categoryName'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editProduct(product),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteProduct(doc.id),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              return ListTile(
                leading: const Icon(Icons.category),
                title: Text(doc['name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editCategory(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteCategory(doc.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Update the _buildDiscountsTab method to show date range info
  Widget _buildDiscountsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('discounts').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No discounts available',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final discount = Discount.fromFirestore(doc);

              return FutureBuilder<DocumentSnapshot>(
                future: discount.categoryRef.get(),
                builder: (context, categorySnapshot) {
                  final categoryName = categorySnapshot.hasData
                      ? categorySnapshot.data!.get('name') ?? 'Unknown Category'
                      : 'Loading...';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.discount, color: Colors.orange),
                      title: Text(discount.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category: $categoryName'),
                          Text(
                            '${discount.value}${discount.type} discount',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Valid: ${DateFormat('MMM dd').format(discount.startDate)} - '
                            '${DateFormat('MMM dd, yyyy').format(discount.endDate)}',
                          ),
                          if (discount.isActive)
                            Chip(
                              label: const Text('Active'),
                              backgroundColor: Colors.green[100],
                            )
                          else
                            Chip(
                              label: const Text('Expired'),
                              backgroundColor: Colors.red[100],
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editDiscount(doc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteDiscount(doc.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildProductForm({bool isEditing = false, String? productId}) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  
                  final categories = snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList();
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedProductCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories,
                    onChanged: (value) {
                      setState(() {
                        _selectedProductCategory = value;
                      });
                    },
                    validator: (value) => value == null ? 'Please select a category' : null,
                  );
                },
              ),
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(labelText: 'Barcode'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              _imageUrl != null
                  ? Image.network(_imageUrl!, height: 150)
                  : Container(),
              ElevatedButton(
                onPressed: _isLoading ? null : _pickImage,
                child: _isLoading 
                    ? const CircularProgressIndicator()
                    : const Text('Upload Image'),
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => isEditing 
              ? _updateProduct(productId!)
              : _addProduct(),
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  Widget _buildCategoryForm({bool isEditing = false, String? categoryId}) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Category' : 'Add New Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _categoryNameController,
              decoration: const InputDecoration(labelText: 'Category Name'),
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => isEditing 
              ? _updateCategory(categoryId!)
              : _addCategory(),
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  // Update the _buildDiscountForm method
Widget _buildDiscountForm({bool isEditing = false, String? discountId}) {
  return StatefulBuilder(
    builder: (BuildContext context, StateSetter setDialogState) {
      return AlertDialog(
        title: Text(isEditing ? 'Edit Discount' : 'Add New Discount'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _discountNameController,
                decoration: const InputDecoration(labelText: 'Discount Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _discountValueController,
                decoration: const InputDecoration(labelText: 'Value'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _discountTypeController,
                decoration: const InputDecoration(labelText: 'Type (e.g., %, \$)'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  
                  final categories = snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,  // Use document ID instead of name
                      child: Text(doc['name']),
                    );
                  }).toList();
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedDiscountCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories,
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedDiscountCategory = value;
                      });
                    },
                    validator: (value) => value == null ? 'Please select a category' : null,
                    );
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('Date Range'),
                  value: _hasDateRange,
                  onChanged: (bool value) {
                    setDialogState(() {
                      _hasDateRange = value;
                      if (!value) {
                        _discountStartDate = null;
                        _discountEndDate = null;
                      }
                    });
                  },
                ),
                if (_hasDateRange) ...[
                  const SizedBox(height: 10),
                  ListTile(
                    title: Text(
                      _discountStartDate == null 
                          ? 'Select Start Date' 
                          : 'Start: ${_formatDate(_discountStartDate!)}'
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2101),
                      );
                      if (date != null) {
                        setDialogState(() => _discountStartDate = date);
                      }
                    },
                  ),
                  ListTile(
                    title: Text(
                      _discountEndDate == null 
                          ? 'Select End Date' 
                          : 'End: ${_formatDate(_discountEndDate!)}'
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _discountStartDate ?? DateTime.now(),
                        firstDate: _discountStartDate ?? DateTime.now(),
                        lastDate: DateTime(2101),
                      );
                      if (date != null) {
                        setDialogState(() => _discountEndDate = date);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (isEditing) {
                  _updateDiscount(discountId!);
                } else {
                  _addDiscount();
                }
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        );
      },
    );
  }
}