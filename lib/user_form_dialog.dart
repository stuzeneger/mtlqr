import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class UserFormDialog extends StatefulWidget {
  final Map<String, dynamic>? user;
  final Function(Map<String, dynamic>) onSubmit;

  const UserFormDialog({Key? key, this.user, required this.onSubmit}) : super(key: key);

  @override
  _UserFormDialogState createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _phone;
  late String _status;
  late String _selectedCountryCode;

  final List<String> countryCodes = ["+371", "+370", "+372", "+49", "+44", "+1"];

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _name = widget.user!['name'];
      _phone = widget.user!['phone'];
      _status = widget.user!['status_id'].toString();
      _selectedCountryCode = widget.user!['phone_country_code'] ?? '+371';
    } else {
      _name = '';
      _phone = '';
      _status = '1';
      _selectedCountryCode = '+371';
    }
  }

  Map<String, String> getStatusOptions() {
    if (widget.user != null) {
      return {
        '1': 'Lietotājs',
        '2': 'Pārzinis',
        '3': 'Bloķēts',
      };
    } else {
      return {
        '1': 'Lietotājs',
        '2': 'Pārzinis',
      };
    }
  }

  Future<void> _saveUser() async {
    if (_formKey.currentState?.validate() ?? false) {
      final Map<String, dynamic> userData = {
        'name': _name,
        'phone': _phone,
        'status_id': _status,
        'country_code': _selectedCountryCode.replaceFirst('+', ''),
      };

      if (widget.user != null) {
        userData['uid'] = widget.user!['uid'];
      }

      try {
        print("sūtu PHP");
        print(json.encode(userData));

        final response = await http.post(
          Uri.parse('https://droniem.lv/mtlqr/manage_user.php'),
          headers: {"Content-Type": "application/json"},
          body: json.encode(userData),
        );

     

        final responseData =
         json.decode(response.body);
        print(response.body);

        if (response.statusCode == 200 && responseData['status'] == 'success') {
          widget.onSubmit(userData);
          Navigator.of(context).pop();
        } else {
          _showError(responseData['message']);
        }
      } catch (e) {
        _showError('Kļūda, mēģiniet vēlreiz');
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kļūda'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Labi'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? 'Pievienot lietotāju' : 'Rediģēt lietotāju'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(labelText: 'Vārds'),
              onChanged: (value) => _name = value,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lūdzu ievadiet vārdu';
                }
                return null;
              },
            ),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCountryCode,
                    decoration: const InputDecoration(labelText: 'Valsts kods'),
                    items: countryCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(code),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCountryCode = value!;
                      });
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    initialValue: _phone,
                    decoration: const InputDecoration(labelText: 'Mobilā tālruņa numurs'),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => _phone = value,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lūdzu ievadiet tālruņa numuru';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Statuss'),
              items: getStatusOptions().entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _status = newValue;
                  });
                }
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
          onPressed: _saveUser,
          child: Text(widget.user == null ? 'Pievienot' : 'Saglabāt'),
        ),
      ],
    );
  }
}
