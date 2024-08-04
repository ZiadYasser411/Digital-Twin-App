import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class AudioRecorderScreen extends StatefulWidget {
  final String selectedNode;
  final String userId;

  const AudioRecorderScreen({
    super.key,
    required this.selectedNode,
    required this.userId,
  });

  @override
  _AudioRecorderScreenState createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen> {
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  bool _isRecording = false;
  double? _currentDecibel;
  List<Map<String, dynamic>> decibelData = [];
  DateTime? startTime;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('Decibels');
  bool _isConnectedToDatabase = false;

  @override
  void initState() {
    super.initState();
    _noiseMeter = NoiseMeter();
    _checkDatabaseConnection();
  }

  Future<void> _checkDatabaseConnection() async {
    try {
      await _dbRef.child('test').set({'test': 'test'});
      setState(() {
        _isConnectedToDatabase = true;
      });
    } catch (e) {
      setState(() {
        _isConnectedToDatabase = false;
      });
      print('Error checking database connection: $e');
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      startTime = DateTime.now().toLocal();
      decibelData.clear();
    });
    _noiseSubscription = _noiseMeter!.noise.listen(onData, onError: onError);
  }

  Future<void> _stopRecording() async {
    _noiseSubscription?.cancel();
    setState(() {
      _isRecording = false;
      _currentDecibel = null;
    });
    String filePath = await saveDecibelsToCsv(decibelData); // Save CSV
    showDownloadDialog(context, filePath); // Show dialog
  }

  void onData(NoiseReading noiseReading) {
    setState(() {
      if (noiseReading.meanDecibel.isFinite) {
        _currentDecibel = noiseReading.meanDecibel;
        DateTime now = DateTime.now().toLocal();
        Map<String, dynamic> data = {
          'time': DateFormat('dd-MM-yyyy HH:mm:ss').format(now),
          'decibels': _currentDecibel!.toStringAsFixed(2),
          'node': widget.selectedNode,
          'userId': widget.userId,
        };
        decibelData.add(data);
        if (_isConnectedToDatabase) {
          _uploadDecibelToRealtimeDatabase(data); // Upload each data point immediately
        }
      } else {
        _currentDecibel = 0.0;
      }
    });
  }

  void onError(Object error) {
    print(error);
    _stopRecording();
  }

  Future<void> _uploadDecibelToRealtimeDatabase(Map<String, dynamic> data) async {
    try {
      await _dbRef.push().set(data);
      print('Data uploaded to Realtime Database: $data');
    } catch (e) {
      print('Error uploading data to Realtime Database: $e');
    }
  }

  Future<String> saveDecibelsToCsv(List<Map<String, dynamic>> decibelData) async {
    try {
      final directory = await getExternalStorageDirectory();
      String formattedStartTime = startTime!.toIso8601String().replaceAll(':', '-');
      final path = '${directory!.path}/noise_readings_$formattedStartTime.csv';
      final file = File(path);
      List<List<String>> csvData = [
        ['Time', 'Decibels', 'Node'],
        ...decibelData.map((entry) => [
          entry['time'].toString(),
          entry['decibels'],
          entry['node'],
        ])
      ];
      String csv = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csv);
      return path;
    } catch (e) {
      return "";
    }
  }

  void showDownloadDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Data Collected',
            style: TextStyle(
              fontFamily: 'JetBrainsFont',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            filePath.isNotEmpty
                ? _isConnectedToDatabase ? 'The data has been uploaded to the database and saved locally as a csv file.' : 'Data has been saved locally as a csv file.'
                : 'Error saving file.',
            style: const TextStyle(
              fontFamily: 'JetBrainsFont',
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.green, // Set the background color to green
                foregroundColor: Colors.white, // Set the text color to white
                textStyle: const TextStyle(
                  fontFamily: 'JetBrainsFont', // Set the font family
                  fontSize: 16, // Set the font size
                  fontWeight: FontWeight.w600, // Optional: Set the font weight
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
  void dispose() {
    _noiseSubscription?.cancel();
    _noiseMeter = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(40.0),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'JetBrainsFont',
                      fontSize: 50.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2.5,
                      height: 1,
                      color: Colors.black, // Default text color
                    ),
                    children: _isRecording
                        ? [
                      const TextSpan(
                        text: 'Decibel Value:\n',
                        style: TextStyle(fontSize: 37),
                      ),
                      TextSpan(
                        text: '${_currentDecibel?.toStringAsFixed(2) ?? "N/A"} dB',
                        style: const TextStyle(fontSize: 50),
                      ),
                    ]
                        : [
                      const TextSpan(text: 'Start '),
                      const TextSpan(
                        text: 'recording',
                        style: TextStyle(color: Colors.green),
                      ),
                      const TextSpan(text: ' to collect data'),
                    ],
                  ),
                ),
              ),
              const SizedBox.square(dimension: 20),
              ElevatedButton.icon(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(270, 50),
                  textStyle: const TextStyle(fontFamily: 'JetBrainsFont', fontSize: 18),
                ),
              ),
            ],
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 30),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          Positioned(
            top: 40,
            right: 40,
            child: Row(
              children: [
                Text(
                  _isConnectedToDatabase ? 'Connected ' : 'Not Connected ',
                  style: const TextStyle(color: Colors.black,
                      fontFamily: 'JetBrainsFont'),
                ),
                Container(
                  width: 10,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnectedToDatabase ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
