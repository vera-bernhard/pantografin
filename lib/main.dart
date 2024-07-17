import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:geolocator/geolocator.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

// Define modeIcons as a global constant
final Map<String, IconData> modeIcons = {
  'FUN': Icons.directions_subway,
  'S': Icons.train,
  'SN': Icons.train,
  'IR': Icons.train,
  'RE': Icons.train,
  'IC': Icons.train,
  'TGV': Icons.train,
  'ICE': Icons.train,
  'RJX': Icons.train,
  'EC': Icons.train,
  'PE': Icons.train,
  'R': Icons.train,
  'ARZ': Icons.train,
  'EXT': Icons.train,
  'B': Icons.directions_bus,
  'BN': Icons.directions_bus,
  'T': Icons.tram,
  'BAT': Icons.directions_boat,
  'sl-icon-type-strain': Icons.train,
  'sl-icon-type-train': Icons.train,
  'sl-icon-type-bus': Icons.directions_bus,
  'sl-icon-type-tram': Icons.tram,
  'sl-icon-type-ship': Icons.directions_boat,
  'sl-icon-type-funicular': Icons.directions_subway,
  'train': Icons.train,
  'bus': Icons.directions_bus,
  'tram': Icons.tram,
  'cableway': Icons.directions_subway,
  'ship': Icons.directions_boat
  // Add more mode-icon pairs as needed
};

final Map<String, List<String>> transportFilter = {
  'train': ['ICE/TGV/RJX', 'EC/IC', 'IR/PE', 'RE', 'S/SN/R'],
  'bus': ['Bus'],
  'tram': ['Tram'],
  'ship': ['Schiff'],
  'cableway': ['Seilbahn/Zahnradbahn'],
};

final Map<String, List<String>> filterToModes = {
  'ICE/TGV/RJX': ['ICE', 'TGV', 'RJX'],
  'EC/IC': ['EC', 'IC'],
  'IR/PE': ['IR', 'PE'],
  'RE': ['RE'],
  'S/SN/R': ['S', 'SN', 'R'],
  'Bus': ['B', 'BN'],
  'Tram': ['T'],
  'Schiff': ['BAT'],
  'Seilbahn/Zahnradbahn': ['FUN'],
};

final List<String> transportFilterFlat =
    transportFilter.values.expand((e) => e).toList();

final Map<String, IconData> transportFilterIcons = Map.fromEntries(
    transportFilter.entries.expand((entry) => entry.value.map(
        (filter) => MapEntry(filter, modeIcons[entry.key] ?? Icons.error))));

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
  List<String> _allStops = [];
  List<String> _allArrivalTimes = [];
  bool _isLoadingDeparture = false;
  List<String> _selectedFilters =
      transportFilterFlat; // Initialize with default filters

  String _formatDateTime(String dateTimeString) {
    tz.initializeTimeZones();
    DateTime dateTime = DateTime.parse(dateTimeString);
    tz.Location gmtPlus2 = tz.getLocation('Europe/Paris');
    tz.TZDateTime gmtPlus2DateTime = tz.TZDateTime.from(dateTime, gmtPlus2);
    String formattedTime = DateFormat('HH:mm').format(gmtPlus2DateTime);
    return formattedTime;
  }

  void updateSelectedFilters(List<String> filters) {
    setState(() {
      _selectedFilters = filters;
    });
  }

  void resetDeparture() {
    setState(() {
      _track = '';
      _departureTime = '';
      _destination = '';
      _mode = '';
      _delay = 'null';
      _modeIdentifier = '';
      _error = '';
      _allStops = [];
      _allArrivalTimes = [];
    });
  }

  Future<void> _getRandomDeparture() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoadingDeparture = true;
    });
    const int limit = 50;
    final String api =
        'http://transport.opendata.ch/v1/stationboard?station=$_station&limit=$limit';
    final response = await http.get(Uri.parse(api));

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      resetDeparture();
      if (responseData['station']['name'] == null) {
        setState(() {
          _error = 'Bahnhof/Haltestelle nicht gefunden';
          _isLoadingDeparture = false;
        });
      } else {
        _error = '';

        // limit connections to only those in the next 30 minutes
        final departureStation = responseData['station']['name'];
        var connections = responseData['stationboard'];
        connections.removeWhere((connection) {
          var departureTime = DateTime.parse(connection['stop']['departure']);
          var now = DateTime.now();
          return departureTime.difference(now).inMinutes > 30;
        });

        // filter connections based on selected filters
        final List<String> filterModes = filterToModes.entries
            .where((entry) => _selectedFilters.contains(entry.key))
            .expand((entry) => entry.value)
            .toList();
        connections.removeWhere((connection) {
          var mode = connection['category'];
          return !filterModes.contains(mode);
        });

        // remove connections where destination is not of type string
        connections.removeWhere((connection) {
          var destination = connection['to'];
          return destination.runtimeType != String;
        });

        if (connections.isEmpty) {
          setState(() {
            _error = 'Keine Verbindungen in den nächsten 30 Minuten';
            _isLoadingDeparture = false;
          });
          return;
        } else {
          var random = Random();
          var randomNumber = random.nextInt(min<int>(10, connections.length));

          final connection = responseData['stationboard'][randomNumber];
          var departureTime = _formatDateTime(connection['stop']['departure']);

          // iterate thourgh connection['passList'] and add all stops to _allStops
          for (var stop in connection['passList']) {
            var name = stop['station']['name'];
            var arrival = stop['arrival'];
            if (name == null) {
              _allStops.add(departureStation);
            } else {
              _allStops.add(name);
            }
            if (arrival == null) {
              _allArrivalTimes.add(departureTime);
            } else {
              _allArrivalTimes.add(_formatDateTime(arrival));
            }
          }
          setState(() {
            if (connection['stop']['platform'] != null) {
              _track = connection['stop']['platform'];
            }
            _station = departureStation;
            _departureTime = departureTime;
            _delay = connection['stop']['delay'].toString();
            _destination = connection['to'];
            _mode = connection['category'];
            _modeIdentifier = _mode + connection['number'];
          });
        }
      }
    } else {
      print('API request failed with status code: ${response.statusCode}');
    }
    setState(() {
      _isLoadingDeparture = false;
    });
  }

  void _navigateToNewPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StopsPage(
          mode: _mode,
          modeIdentifier: _modeIdentifier,
          destination: _destination,
          departureTime: _departureTime,
          delay: _delay,
          track: _track,
          stops: _allStops,
          arrivalTimes: _allArrivalTimes,
        ),
      ),
    );
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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            StationSearchForm(
              onStationChanged: (station) {
                setState(() {
                  _station = station;
                });
              },
              homePageState: this,
              selectedFilters:
                  transportFilterFlat, // Make sure transportFilterFlat is defined or imported
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _getRandomDeparture,
              child: const Text('Zufällige Verbindung'),
            ),
            Center(
                child: Visibility(
              visible: _isLoadingDeparture,
              child: LoadingAnimationWidget.waveDots(
                color: Theme.of(context).colorScheme.primary,
                size: 50,
              ),
            )),
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
            Visibility(
              visible: !_isLoadingDeparture,
              child: _ConnectionDetails(
                mode: _mode,
                modeIdentifier: _modeIdentifier,
                destination: _destination,
                departureTime: _departureTime,
                delay: _delay,
                track: _track,
              ),
            ), // Call the extracted widget here
            const SizedBox(height: 30),
            Visibility(
              visible: !_isLoadingDeparture && _departureTime != '',
              child: ElevatedButton(
                onPressed: _navigateToNewPage, // Call the navigation function
                child: const Text('Los gehts!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StationSearchForm extends StatefulWidget {
  final ValueChanged<String> onStationChanged;
  final _MyHomePageState? homePageState;
  final List<String> selectedFilters; // Define selectedFilters as a field

  const StationSearchForm({
    Key? key,
    required this.onStationChanged,
    this.homePageState,
    required this.selectedFilters, // Initialize selectedFilters
  }) : super(key: key);

  @override
  _StationSearchFormState createState() => _StationSearchFormState();
}

class _StationSearchFormState extends State<StationSearchForm> {
  final TextEditingController _stationController = TextEditingController();
  List<dynamic> _possibleStations = [];
  bool _isLoadingLocations = false;
  String _error = '';
  List<String> _selectedFilters = [];

  @override
  void initState() {
    super.initState();
    if (_selectedFilters.isEmpty) {
      _selectedFilters = transportFilterFlat;
    }
  }

  Future<List<double>?> _getCurrentLocationCoords() async {
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) {
      return null;
    }
    setState(() {
      _possibleStations = [];
    });

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

    return [position.latitude, position.longitude];
  }

  Future<void> _getClosestStations() async {
    setState(() {
      _isLoadingLocations = true;
    });

    if (widget.homePageState != null) {
      widget.homePageState!.resetDeparture();
    }

    FocusScope.of(context).unfocus();

    List<double>? locationString = await _getCurrentLocationCoords();
    final x = locationString?[0];
    final y = locationString?[1];
    if (locationString == null) {
      setState(() {
        _error = 'Standortsuche fehlgeschlagen, brauch das Suchfeld';
      });
    } else {
      final String api = 'http://transport.opendata.ch/v1/locations?x=$x&y=$y';
      final response = await http.get(Uri.parse(api));
      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        var possibleStations = responseData['stations'];
        // remove where id is null = proxy for stations (as type==station not working)
        possibleStations.removeWhere((item) => item['id'] == null);
        possibleStations =
            possibleStations.sublist(0, min<int>(10, possibleStations.length));

        setState(() {
          _possibleStations = possibleStations;
        });
      } else {
        print('API request failed with status code: ${response.statusCode}');
      }
    }
    setState(() {
      _isLoadingLocations = false;
    });
  }

  Future<void> _getStationsByString(String stationString) async {
    setState(() {
      _isLoadingLocations = true;
      _error = '';
    });

    if (widget.homePageState != null) {
      widget.homePageState!.resetDeparture();
    }
    final String api =
        'http://transport.opendata.ch/v1/locations?query=$stationString';
    final response = await http.get(Uri.parse(api));
    if (response.statusCode == 200) {
      var responseData = jsonDecode(response.body);
      var possibleStations = responseData['stations'];
      // remove where id is null = proxy for stations (as type==station not working)
      possibleStations.removeWhere((item) => item['id'] == null);
      possibleStations =
          possibleStations.sublist(0, min<int>(10, possibleStations.length));
      // if only one station is found, set the station name in the text field
      if (possibleStations.length == 1) {
        _stationController.text = possibleStations[0]['name'];
        widget.onStationChanged(possibleStations[0]['name']);
        setState(() {
          _possibleStations = [];
        });
      } else if (possibleStations.length == 0) {
        setState(() {
          _error = 'Bahnhof/Haltestelle nicht gefunden';
          _possibleStations = [];
        });
      } else {
        setState(() {
          _possibleStations = possibleStations;
        });
      }
    } else {
      setState(() {
        _error = 'API Anfrage fehlgeschlagen';
      });
      print('API request failed with status code: ${response.statusCode}');
    }
    setState(() {
      _isLoadingLocations = false;
    });
  }

  Future<void> _openFilterDialog() async {
    final selectedFilters = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        return FilterDialog(selectedFilters: _selectedFilters);
      },
    );
    if (selectedFilters != null) {
      setState(() {
        _selectedFilters = selectedFilters;
      });
      // Pass selected filters back to _MyHomePageState
      widget.homePageState?.updateSelectedFilters(selectedFilters);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 350,
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
                  onSubmitted: (String value) {
                    _getStationsByString(value);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.location_on),
                onPressed: _getClosestStations,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _openFilterDialog,
                color: _selectedFilters.length != transportFilterFlat.length
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.tertiary,
              )
            ],
          ),
          Center(
            child: Visibility(
              visible: _isLoadingLocations,
              child: LoadingAnimationWidget.waveDots(
                color: Theme.of(context).colorScheme.primary,
                size: 50,
              ),
            ),
          ),
          if (_error != '') ...[
            const SizedBox(
                height: 20), // Add some space before the error message
            Center(
              child: Text(
                _error,
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
          const SizedBox(
              height: 10), // Add some spacing between TextField and buttons
          ListView.builder(
              shrinkWrap: true,
              itemCount: _possibleStations.length,
              itemBuilder: (BuildContext context, int index) {
                final stationData = _possibleStations[index];
                // if icon is null, set it to 'train' as default
                final icon = stationData['icon'] ?? 'train';
                final stationName = stationData['name'];
                var distance = stationData['distance'];

                return ElevatedButton(
                  onPressed: () {
                    _stationController.text = stationName;
                    widget.onStationChanged(stationName);
                    setState(() {
                      _possibleStations = [];
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            modeIcons[icon],
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(stationName),
                        ],
                      ), // only show if distance is available, else shrink the row
                      if (distance != null) Text('$distance m'),
                    ],
                  ),
                );
              }),
        ],
      ),
    );
  }
}

class StopsPage extends StatefulWidget {
  final String mode;
  final String modeIdentifier;
  final String destination;
  final String departureTime;
  final String delay;
  final String track;
  final List<String> stops;
  final List<String> arrivalTimes;

  const StopsPage({
    super.key,
    required this.mode,
    required this.modeIdentifier,
    required this.destination,
    required this.departureTime,
    required this.delay,
    required this.track,
    required this.stops,
    required this.arrivalTimes,
  });

  @override
  State<StopsPage> createState() => _StopsPageState();
}

class _StopsPageState extends State<StopsPage> {
  final ScrollController _scrollController = ScrollController();

  List<bool> highlightedStops = [];

  @override
  void initState() {
    super.initState();
    highlightedStops = List.generate(widget.stops.length, (index) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Center(child: Text("Meine Verbindung")),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            // Include the BuildConnectionDetails widget to show connection details
            _ConnectionDetails(
              mode: widget.mode,
              modeIdentifier: widget.modeIdentifier,
              destination: widget.destination,
              departureTime: widget.departureTime,
              delay: widget.delay,
              track: widget.track,
            ),
            // Add a scrollable list of stops
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey, // Set the border color
                    width: 1.0, // Set the border width
                  ),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 5.0,
                  controller: _scrollController,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: widget.stops.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        title: Row(
                          children: [
                            Transform.rotate(
                              angle: 45 * pi / 90,
                              child: const IconButton(
                                icon: Icon(
                                  Icons.commit,
                                  color: Colors.black,
                                ),
                                onPressed: null,
                              ),
                            ),
                            Text(
                              widget.arrivalTimes[index],
                              style: TextStyle(
                                color: highlightedStops[index]
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.black,
                                fontWeight: index == 0 ||
                                        index == widget.stops.length - 1
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              widget.stops[index],
                              style: TextStyle(
                                color: highlightedStops[index]
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.black,
                                fontWeight: index == 0 ||
                                        index == widget.stops.length - 1
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Add a button
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                int randomIndex = 1 + Random().nextInt(widget.stops.length - 1);
                setState(() {
                  // Set the selected stop as highlighted and scroll it into view
                  highlightedStops = List.generate(
                      widget.stops.length, (index) => index == randomIndex);
                  _scrollController.animateTo(
                    randomIndex * 56.0, // 56.0 is the height of each ListTile
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              },
              child: const Text('Zufälliger Halt'),
            ),
            const SizedBox(height: 30)
          ],
        ),
      ),
    );
  }
}

class _ConnectionDetails extends StatelessWidget {
  final String mode;
  final String modeIdentifier;
  final String destination;
  final String departureTime;
  final String delay;
  final String track;

  const _ConnectionDetails({
    required this.mode,
    required this.modeIdentifier,
    required this.destination,
    required this.departureTime,
    required this.delay,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    if (departureTime.isEmpty) {
      return const SizedBox
          .shrink(); // Return an empty SizedBox if departureTime is empty
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              modeIcons[mode],
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 5),
            Text(
              modeIdentifier,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Richtung $destination',
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Abfahrt um $departureTime',
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (delay != 'null' && delay != '0') ...[
              Text(
                '+$delay',
                style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
            const SizedBox(width: 5),
            if (track.isNotEmpty) ...[
              Text(
                'auf Gleis $track',
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class FilterDialog extends StatefulWidget {
  final List<String> selectedFilters;

  const FilterDialog({Key? key, required this.selectedFilters})
      : super(key: key);

  @override
  _FilterDialogState createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  final List<String> _filters = transportFilterFlat;
  List<String> _selectedFilters = [];

  @override
  void initState() {
    super.initState();
    _selectedFilters = List.from(widget.selectedFilters);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Verbindungen'),
      content: SingleChildScrollView(
        child: ListBody(
          children: _filters.map((filter) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Icon(
                    transportFilterIcons[filter],
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(
                      width: 6), // Adjust spacing between icon and checkbox

                  // Checkbox
                  Expanded(
                    child: CheckboxListTile(
                      dense:
                          true, // Makes the checkbox smaller to fit alongside the icon
                      title: Text(filter),
                      value: _selectedFilters.contains(filter),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedFilters.add(filter);
                          } else {
                            _selectedFilters.remove(filter);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Abbrechen'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Anwenden'),
          onPressed: () {
            Navigator.of(context).pop(_selectedFilters);
          },
        ),
      ],
    );
  }
}
