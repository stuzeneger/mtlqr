import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ItemFormDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  final Function(Map<String, dynamic>) onSubmit;

  const ItemFormDialog({
    Key? key,
    this.item,
    required this.onSubmit,
  }) : super(key: key);

  @override
  _ItemFormDialogState createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _qrCodeController = TextEditingController();
  int _statusId = 1;

  static const Map<int, String> statusMap = {
    1: 'Noliktavā',
    2: 'Rezervēts',
    3: 'Izsniegts',
    4: 'Pazaudēts',
    5: 'Bojāts',
    6: 'Norakstīts',
  };

  String getStatusName(int statusId) {
    return statusMap[statusId] ?? 'Nezināms';
  }

  @override
  void initState() {
    super.initState();

    if (widget.item != null) {
      _codeController.text = widget.item!['code'] ?? '';
      _qrCodeController.text = widget.item!['qr_code'] ?? '';
      _statusId = int.tryParse(widget.item!['status_id'].toString()) ?? 1;
    }
  }

  Future<void> _saveItem() async {
    final Map<String, dynamic> newItem = {
      'code': _codeController.text,
      'qr_code': _qrCodeController.text,
      'status_id': _statusId,
    };

    if (widget.item != null) {
      newItem['uid'] = widget.item!['uid'];
    }

    final response = await http.post(
      Uri.parse(widget.item != null ? 'https://droniem.lv/mtlqr/update_item.php' : 'https://droniem.lv/mtlqr/add_item.php'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(newItem),
    );

      print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      widget.onSubmit(newItem);
      Navigator.of(context).pop();
    } else {
      throw Exception('Neizdevās saglabāt priekšmetu');
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
              decoration: const InputDecoration(labelText: 'Code'),
            ),
            TextField(
              controller: _qrCodeController,
              decoration: const InputDecoration(labelText: 'QR Code'),
            ),
            DropdownButtonFormField<int>(
              value: _statusId,
              decoration: const InputDecoration(labelText: 'Statuss'),
              items: statusMap.entries.map((entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  _statusId = value!;
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
