import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: AudioRecorderScreen(),
    );
  }
}

class AudioRecorderScreen extends StatefulWidget {
  const AudioRecorderScreen({super.key});

  @override
  _AudioRecorderScreenState createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen> {
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  bool _isRecording = false;
  double? _currentDecibel;
  List<List<String>> decibelData = [];

  @override
  void initState() {
    super.initState();
    _noiseMeter = NoiseMeter();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      decibelData.clear();
      decibelData.add(['Time', 'Decibels']); // Add CSV headers
    });
    _noiseSubscription = _noiseMeter!.noise.listen(onData, onError: onError);
  }

  Future<void> _stopRecording() async {
    _noiseSubscription?.cancel();
    setState(() {
      _isRecording = false;
      _currentDecibel = null;
    });
    String filePath = await saveDecibelsToCsv(decibelData);
    showDownloadDialog(context, filePath);
  }

  void onData(NoiseReading noiseReading) {
    setState(() {
      if (noiseReading.meanDecibel.isFinite) {
        _currentDecibel = noiseReading.meanDecibel;
        String formattedTime = DateTime.now().toLocal().toString().substring(0, 19);
        decibelData.add([formattedTime, _currentDecibel!.toStringAsFixed(2)]);
      } else {
        _currentDecibel = 0.0; // Set to 0.0 if reading is not finite
      }
    });
  }

  void onError(Object error) {
    print(error);
    _stopRecording();
  }

  Future<String> saveDecibelsToCsv(List<List<String>> decibelData) async {
    try {
      final directory = await getExternalStorageDirectory();
      final path = '${directory!.path}/decibels.csv';
      final file = File(path);
      String csvData = const ListToCsvConverter().convert(decibelData);
      await file.writeAsString(csvData);
      print("File saved at $path"); // Debugging line
      return path;
    } catch (e) {
      print("Error saving file: $e");
      return "";
    }
  }

  void showDownloadDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Data Collected'),
          content: Text(filePath.isNotEmpty
              ? 'The CSV file has been saved to: $filePath'
              : 'Error saving file.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green
              ),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40.0),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'JetBrainsFont',
                    fontSize: 45.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2.5,
                    height: 1,
                    color: Colors.black, // Default text color
                  ),
                  children: _isRecording
                      ? [
                          TextSpan(
                            text: 'Decibel Value: ${_currentDecibel?.toStringAsFixed(2) ?? "N/A"} dB',
                            style: const TextStyle(fontSize: 37),
                          ),
                        ]
                      : [
                          const TextSpan(
                            text: 'Start ',
                          ),
                          const TextSpan(
                            text: 'recording',
                            style: TextStyle(color: Colors.green), // 'recording' in green
                          ),
                          const TextSpan(
                            text: ' and collect data',
                          ),
                        ],
                ),
              ),
            ),
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
      ),
    );
  }
}
