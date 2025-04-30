import 'services/config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/event.dart';

class ItemFormDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  final Function(Map<String, dynamic>) onSubmit;

  const ItemFormDialog({
    super.key,
    this.item,
    required this.onSubmit,
  });

  @override
  State<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _qrCodeController = TextEditingController();
  int _statusId = 1;
  bool _damaged = false; // ✅ Pievienots damaged laukam

  static const Map<int, String> statusMap = {
    1: 'Noliktavā',
    2: 'Rezervēts',
    3: 'Izsniegts',
    4: 'Pazaudēts',
    5: 'Norakstīts',
  };

  String getStatusName(int statusId) {
    return statusMap[statusId] ?? '';
  }

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _codeController.text = widget.item!['code'] ?? '';
      _qrCodeController.text = widget.item!['qr_code'] ?? '';
      _statusId = int.tryParse(widget.item!['status_id'].toString()) ?? 1;
      _damaged = int.tryParse(widget.item!['damaged'].toString()) == 1;
    }
  }

  Future<void> _saveItem() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userUID = prefs.getString('userUID') ?? '';
    final Map<String, dynamic> itemData = {
      'user_uid': userUID,
      'code': _codeController.text,
      'qr_code': _qrCodeController.text,
      'status_id': _statusId,
      'damaged': _damaged, 
    };
    if (widget.item != null) {
      itemData['uid'] = widget.item!['uid'];
    }

    final response = await http.post(
      Uri.parse(AppConfig.endpointRequest),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_uid': userUID,
        'event': Events.updateItem.name,
        'item_data': jsonEncode(itemData),
      }),
    );

    if (response.statusCode == 200) {
      widget.onSubmit(itemData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Priekšmeta dati saglabāti'),
        ),
      );
      Navigator.of(context).pop();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Neizdevās saglabāt priekšmeta datus'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item != null ? 'Rediģēt priekšmetu' : 'Pievienot priekšmetu'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Kods'),
            ),
            TextField(
              controller: _qrCodeController,
              decoration: const InputDecoration(labelText: 'QR kods (6 cipari)'),
            ),
            DropdownButtonFormField<int>(
              value: _statusId,
              decoration: const InputDecoration(labelText: 'Statuss'),
              items: statusMap.entries
                  .map((entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _statusId = value!;
                });
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bojāts'), // ✅ Checkbox vizuāli
              value: _damaged,
              onChanged: (value) {
                setState(() {
                  _damaged = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Atcelt'),
        ),
        ElevatedButton(
          onPressed: _saveItem,
          child: Text(widget.item != null ? 'Saglabāt' : 'Pievienot'),
        ),
      ],
    );
  }
}
