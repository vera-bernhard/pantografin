import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Import the dart:convert library
import 'dart:math';
import 'package:intl/intl.dart'; // Import the intl library
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SBB Roulette',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(198, 0, 24, 1.0)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'SBB Roulette'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _track = '';
  String _departureTime = '';
  String _destination = '';
  String _station = '';
  String _mode = '';
  String _delay = '';
  String _modeIdentifier = '';
  String _error = '';

  String formatDateTime(String dateTimeString) {
    // Load the time zone data
    tz.initializeTimeZones();

    // Parse the input date string into a DateTime object
    DateTime dateTime = DateTime.parse(dateTimeString);

    // Get the time zone for GMT+2 (Central European Time, CET)
    tz.Location gmtPlus2 = tz.getLocation('Europe/Paris');

    // Convert the input DateTime to GMT+2
    tz.TZDateTime gmtPlus2DateTime = tz.TZDateTime.from(dateTime, gmtPlus2);

    // Format the time as HH:mm
    String formattedTime = DateFormat('HH:mm').format(gmtPlus2DateTime);

    return formattedTime;
  }

  // Define a map that maps each mode to its corresponding icon
  final Map<String, IconData> modeIcons = {
    'S': Icons.train,
    'IR': Icons.train,
    'IC': Icons.train,
    'ICE': Icons.train,
    'EC': Icons.train,
    'B': Icons.directions_bus,
    'T': Icons.tram,
    'BAT': Icons.directions_boat,
    // Add more mode-icon pairs as needed
  };

  Future<void> _getRandomDeparture() async {
    // Replace 'YOUR_API_ENDPOINT' with the actual API endpoint URL

    const int limit = 10;
    final String api =
        'http://transport.opendata.ch/v1/stationboard?station=$_station&limit=$limit';
    final response = await http.get(Uri.parse(api));

    // generate a random number between 0 and limit
    var random = Random();
    var randomNumber = random.nextInt(limit);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      if (responseData['station']['name'] == null) {
        setState(() {
          _error = 'Bahnhof/Haltestelle nicht gefunden';
        });
      } else {
        // API request was successful

        final connection = responseData['stationboard'][randomNumber];

        setState(() {
          if (connection['stop']['platform'] != null) {
            _track = connection['stop']['platform'];
          }
          _departureTime = formatDateTime(connection['stop']['departure']);
          _delay = connection['stop']['delay'].toString();
          _destination = connection['to'];
          _mode = connection['category'];
          _modeIdentifier = _mode + connection['number'];
        });
      }
    } else {
      // API request failed
      // You can handle errors here, e.g., show a snackbar or error message
      print('API request failed with status code: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Center(child: Text(widget.title)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MyCustomForm(
              onStationChanged: (station) {
                setState(() {
                  print(station);
                  _station = station;
                });
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _getRandomDeparture,
              child: const Text('Zufällige Verbindung'),
            ),
            const SizedBox(height: 30),
            if (_error != '') ...[
              Text(_error,
                  style: const TextStyle(
                    fontSize: 18.0, // Set the font size to 24
                    fontWeight: FontWeight.bold, // Set the font weight to bold
                    color: Colors.red,
                  ))
            ],
            if (_departureTime != '') ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                // conditional icon depending on mode
                Icon(
                  modeIcons[_mode],
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 5),
                Text('$_modeIdentifier',
                    style: const TextStyle(
                      fontSize: 18.0, // Set the font size to 24
                      fontWeight:
                          FontWeight.bold, // Set the font weight to bold
                    )),
                const SizedBox(width: 10),
                Text('Richtung $_destination',
                    style: const TextStyle(
                      fontSize: 18.0, // Set the font size to 24
                      fontWeight:
                          FontWeight.bold, // Set the font weight to bold
                    )),
              ])
            ],
            if (_departureTime != '') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Abfahrt um $_departureTime',
                      style: const TextStyle(
                        fontSize: 18.0, // Set the font size to 24
                        fontWeight:
                            FontWeight.bold, // Set the font weight to bold
                      )),
                  if (_delay != '0') ...[
                    Text('+$_delay',
                        style: const TextStyle(
                          fontSize: 12.0, // Set the font size to 24
                          fontWeight:
                              FontWeight.bold, // Set the font weight to bold
                          color: Colors.red,
                        )),
                  ],
                  SizedBox(width: 5),
                  if (_track != '') ...[
                    Text('auf Gleis $_track',
                        style: const TextStyle(
                          fontSize: 18.0, // Set the font size to 24
                          fontWeight:
                              FontWeight.bold, // Set the font weight to bold
                        )),
                  ],
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}

class MyCustomForm extends StatefulWidget {
  final ValueChanged<String> onStationChanged;

  const MyCustomForm({Key? key, required this.onStationChanged})
      : super(key: key);

  @override
  _MyCustomFormState createState() => _MyCustomFormState();
}

class _MyCustomFormState extends State<MyCustomForm> {
  final TextEditingController _stationController = TextEditingController();

  @override
  void dispose() {
    _stationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Bahnhof/Haltestelle'),
          TextField(
            controller: _stationController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'z.B. Zürich HB',
            ),
            onChanged: (String value) {
              widget.onStationChanged(value);
            },
          ),
        ],
      ),
    );
  }
}
