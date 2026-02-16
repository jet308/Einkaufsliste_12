import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const ShoppingListApp());
}

class ShoppingListApp extends StatelessWidget {
  const ShoppingListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Einkaufsliste',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.black,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Colors.black,
        ),
      ),
      home: const ShoppingListPage(),
    );
  }
}

class ShoppingItem {
  String text;
  bool done;

  ShoppingItem({required this.text, this.done = false});

  Map<String, dynamic> toMap() => {'text': text, 'done': done};

  factory ShoppingItem.fromMap(Map<String, dynamic> map) =>
      ShoppingItem(text: map['text'], done: map['done']);
}

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<ShoppingItem> _items = [];

  ShoppingItem? _lastDeleted;
  int? _lastDeletedIndex;

  @override
  void initState() {
    super.initState();
    _loadItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('shopping_items');
    if (data != null) {
      final List list = jsonDecode(data);
      setState(() {
        _items = list.map((e) => ShoppingItem.fromMap(e)).toList();
        _sortItems();
      });
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_items.map((e) => e.toMap()).toList());
    await prefs.setString('shopping_items', data);
  }

  void _sortItems() {
    _items.sort((a, b) {
      if (a.done == b.done) return 0;
      return a.done ? 1 : -1;
    });
  }

  void _addItem(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _items.insert(0, ShoppingItem(text: text.trim()));
      _sortItems();
      _saveItems();
    });
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _toggleDone(int index) {
    setState(() {
      _items[index].done = !_items[index].done;
      _sortItems();
      _saveItems();
    });
  }

  void _deleteItem(int index) {
    if (_lastDeleted != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    setState(() {
      _lastDeleted = _items[index];
      _lastDeletedIndex = index;
      _items.removeAt(index);
      _saveItems();
    });

    final snackBar = SnackBar(
      content: const Text('Eintrag gelöscht'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          if (_lastDeleted != null && _lastDeletedIndex != null) {
            setState(() {
              _items.insert(_lastDeletedIndex!, _lastDeleted!);
              _sortItems();
              _saveItems();
              _lastDeleted = null;
              _lastDeletedIndex = null;
            });
          }
        },
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  void _editItem(int index) {
    final editController = TextEditingController(text: _items[index].text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eintrag bearbeiten'),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Text ändern'),
          onSubmitted: (value) {
            _applyEdit(index, value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _applyEdit(index, editController.text);
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  void _applyEdit(int index, String newText) {
    if (newText.trim().isEmpty) return;
    setState(() {
      _items[index].text = newText.trim();
      _saveItems();
    });
  }

  void _clearAll() {
    if (_items.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gesamte Liste löschen?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _items.clear();
                _saveItems();
              });
              Navigator.pop(context);
            },
            child: const Text('Löschen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = _items[index];
    return Dismissible(
      key: Key(item.text + index.toString()),
      background: Container(color: Colors.transparent),
      secondaryBackground: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => _editItem(index),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () => _deleteItem(index),
            ),
          ),
        ],
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async => false,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          title: Text(
            item.text,
            style: TextStyle(
                decoration: item.done ? TextDecoration.lineThrough : null,
                color: Colors.black),
          ),
          leading: Checkbox(
            value: item.done,
            onChanged: (_) => _toggleDone(index),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Neuen Eintrag hinzufügen',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onSubmitted: _addItem,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    color: Colors.black,
                    onPressed: () => _addItem(_controller.text),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: _buildItem,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                ),
                onPressed: _clearAll,
                child: const Text('Gesamte Liste löschen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}