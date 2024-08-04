import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class AudioRecorderScreen extends StatefulWidget {
  final String selectedNode;
  final mongo.Db? db;
  final String userId;

  const AudioRecorderScreen({
    super.key,
    required this.selectedNode,
    required this.db,
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
  mongo.DbCollection? _collection;
  List<Map<String, dynamic>> decibelData = [];
  DateTime? startTime;

  @override
  void initState() {
    super.initState();
    _noiseMeter = NoiseMeter();
    _collection = widget.db?.collection('Decibels');
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
        String formattedTime = DateFormat('dd-MM-yyyy HH:mm:ss').format(now);
        Map<String, dynamic> data = {
          'time': formattedTime,
          'decibels': _currentDecibel!.toStringAsFixed(2),
          'node': widget.selectedNode,
          'userId': widget.userId,
        };
        decibelData.add(data);
        if (_collection != null) {
          _uploadDecibelToDb(data); // Upload each data point immediately
        }
      } else {
        _currentDecibel = 0.0; // Set to 0.0 if reading is not finite
      }
    });
  }

  void onError(Object error) {
    print(error);
    _stopRecording();
  }

  Future<void> _uploadDecibelToDb(Map<String, dynamic> data) async {
    if (_collection == null) {
      print('Collection is not initialized.');
      return;
    }

    var result = await _collection!.insert({
      'time': data['time'],
      'decibels': data['decibels'],
      'node': data['node'],
      'userId': data['userId'],
    });
    print('Inserted document: $result');
  }

  Future<String> saveDecibelsToCsv(
      List<Map<String, dynamic>> decibelData) async {
    try {
      final directory = await getExternalStorageDirectory();
      String formattedStartTime = startTime!
          .toIso8601String()
          .replaceAll(':', '-'); // Replace ':' with '-'
      final path = '${directory!.path}/noise_readings_$formattedStartTime.csv';
      final file = File(path);
      List<List<String>> csvData = [
        ['Time', 'Decibels', 'Node'],
        ...decibelData.map((entry) => [
          entry['time'].toString(),
          entry['decibels'],
          entry['node'], // Add the node value to the CSV
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
          title: const Text('Data Collected',
            style: TextStyle(
              fontFamily: 'JetBrainsFont',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(filePath.isNotEmpty
              ? 'The data has been uploaded to the database and saved locally as a csv file.'
              : 'Error saving file.',
            style: const TextStyle(
            fontFamily: 'JetBrainsFont',
            fontSize: 16,
          ),),
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
                        text:
                        'Decibel Value:\n',
                        style: const TextStyle(fontSize: 37),
                      ),
                      TextSpan(
                        text:
                        '${_currentDecibel?.toStringAsFixed(2) ?? "N/A"} dB',
                        style: const TextStyle(fontSize: 50),
                      ),

                    ]
                        : [
                      const TextSpan(
                        text: 'Start ',
                      ),
                      const TextSpan(
                        text: 'recording',
                        style: TextStyle(
                            color: Colors.green), // 'recording' in green
                      ),
                      const TextSpan(
                        text: ' to collect data',
                      ),
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
        ],
      ),
    );
  }
}