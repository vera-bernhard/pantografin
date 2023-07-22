import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SBB Roulette',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(198, 0, 24, 1.0),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'SBB Roulette'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title});

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
  String _delay = 'null';
  String _modeIdentifier = '';
  String _error = '';

  String formatDateTime(String dateTimeString) {
    tz.initializeTimeZones();
    DateTime dateTime = DateTime.parse(dateTimeString);
    tz.Location gmtPlus2 = tz.getLocation('Europe/Paris');
    tz.TZDateTime gmtPlus2DateTime = tz.TZDateTime.from(dateTime, gmtPlus2);
    String formattedTime = DateFormat('HH:mm').format(gmtPlus2DateTime);
    return formattedTime;
  }

  final Map<String, IconData> modeIcons = {
    'S': Icons.train,
    'SN': Icons.train,
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
    const int limit = 10;
    final String api =
        'http://transport.opendata.ch/v1/stationboard?station=$_station&limit=$limit';
    final response = await http.get(Uri.parse(api));

    var random = Random();
    var randomNumber = random.nextInt(limit);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      if (responseData['station']['name'] == null) {
        setState(() {
          _error = 'Bahnhof/Haltestelle nicht gefunden';
        });
      } else {
        _error = '';
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
              Text(
                _error,
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
            if (_departureTime != '') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    modeIcons[_mode],
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$_modeIdentifier',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Richtung $_destination',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            if (_departureTime != '') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Abfahrt um $_departureTime',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_delay != 'null') ...[
                    Text(
                      '+$_delay',
                      style: const TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                  const SizedBox(width: 5),
                  if (_track != '') ...[
                    Text(
                      'auf Gleis $_track',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
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
  List<dynamic> _possibleStations = [];

  Future<String?> getCurrentLocationString() async {
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!isLocationServiceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    String locationString = '${position.latitude},${position.longitude}';
    return locationString;
  }

  final Map<String, IconData> modeIcons = {
    'sl-icon-type-strain': Icons.train,
    'sl-icon-type-bus': Icons.directions_bus,
    'sl-icon-type-tram': Icons.tram,
    'sl-icon-type-ship': Icons.directions_boat,
    // Add more mode-icon pairs as needed
  };

  Future<void> _getClosestStations() async {
    String? locationString = await getCurrentLocationString();

    if (locationString == null) {
      return;
    } else {
      final String api =
          'https://timetable.search.ch/api/completion.json?latlon=$locationString';
      final response = await http.get(Uri.parse(api));

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        responseData
            .removeWhere((item) => item["iconclass"] == "sl-icon-type-adr");
        var possibleStations =
            responseData.sublist(0, min<int>(5, responseData.length));

        setState(() {
          _possibleStations = possibleStations;
        });
      } else {
        print('API request failed with status code: ${response.statusCode}');
      }
    }
  }

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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stationController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'z.B. Zürich HB',
                  ),
                  onChanged: (String value) {
                    widget.onStationChanged(value);
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.location_on),
                onPressed: _getClosestStations,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
