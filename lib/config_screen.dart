import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'recorder_screen.dart';

class DatabaseConnectionScreen extends StatefulWidget {
  const DatabaseConnectionScreen({super.key});

  @override
  _DatabaseConnectionScreenState createState() =>
      _DatabaseConnectionScreenState();
}

class _DatabaseConnectionScreenState extends State<DatabaseConnectionScreen> {
  String _selectedOption = '';
  bool _showTextField = false;
  String _customValue = '';
  String? userId;

  final List<String> _options = [
    'Node 1 (Creeks)',
    'Node 2 (Arabella)',
    'Node 3 (Gate 1)',
    'Use my location'
  ];

  @override
  void initState() {
    super.initState();
    _getUserId();
    _requestPermissions(); // Request permissions at start
  }

  Future<void> _getUserId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      userId = androidInfo.id; // Use id as user ID
    }
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.storage,
    ].request();

    // Handle each permission status
    statuses.forEach((permission, status) {
      if (status.isDenied || status.isPermanentlyDenied) {
        _showErrorDialog(
          'Permission for ${permission.toString()} denied. Please enable it in settings.',
        );
      }
    });
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Error',
            style: TextStyle(
              fontFamily: 'JetBrainsFont',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            errorMessage,
            style: const TextStyle(
              fontFamily: 'JetBrainsFont',
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontFamily: 'JetBrainsFont',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40.0),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'JetBrainsFont',
                    fontSize: 50.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -3,
                    height: 1,
                    color: Colors.black, // Default text color
                  ),
                  children: [
                    TextSpan(
                      text: 'Select the ',
                    ),
                    TextSpan(
                      text: 'location',
                      style: TextStyle(
                          color: Colors.green), // 'the database' in green
                    ),
                    TextSpan(
                      text: ' to proceed',
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 270,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 35),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        hint: const Text(
                          'Select a node',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'JetBrainsFont',
                          ),
                        ),
                        value: _selectedOption.isEmpty ? null : _selectedOption,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedOption = newValue ?? '';
                            _showTextField = newValue == 'Use my location';
                            if (!_showTextField) {
                              _customValue = '';
                            }
                          });
                        },
                        selectedItemBuilder: (BuildContext context) {
                          return _options.map<Widget>((String value) {
                            return Container(
                              alignment: Alignment.center,
                              child: Text(
                                value,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'JetBrainsFont',
                                ),
                              ),
                            );
                          }).toList();
                        },
                        items: _options
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                color: Colors.black,
                                fontFamily: 'JetBrainsFont',
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_showTextField)
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
                child: SizedBox(
                  width: 270,
                  child: TextField(
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                            color: Colors.green), // Green focus
                        borderRadius: BorderRadius.circular(25),
                      ),
                      labelText: 'Enter your location',
                      labelStyle: const TextStyle(
                          fontFamily: 'JetBrainsFont', color: Colors.grey),
                      floatingLabelStyle: const TextStyle(
                          color: Colors.green), // Green focus
                    ),
                    cursorColor: Colors.green,
                    onChanged: (text) {
                      setState(() {
                        _customValue = text;
                      });
                    },
                  ),
                ),
              ),
            Column(
              children: [
                const SizedBox.square(dimension: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AudioRecorderScreen(
                          selectedNode: _selectedOption == 'Use my location'
                              ? _customValue.isNotEmpty
                              ? _customValue
                              : 'Custom location not provided'
                              : _selectedOption,
                          userId: userId!,
                        ),
                      ),
                    );
                  },
                  label: const Text('Proceed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(270, 50),
                    textStyle: const TextStyle(
                        fontFamily: 'JetBrainsFont', fontSize: 18),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 24),
                ),
                const SizedBox(height: 40), // Spacing from bottom
              ],
            ),
          ],
        ),
      ),
    );
  }
}