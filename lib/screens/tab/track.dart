import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'dart:ui' as ui;
import 'package:vibration/vibration.dart';

class TrackingMapScreen extends StatefulWidget {
  @override
  _TrackingMapScreenState createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends State<TrackingMapScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  late Position _currentPosition;
  List<dynamic> largeHoles = [];
  List<dynamic> maintainRoad = [];
  LatLng? _selectedPosition;
  int _currentHoleIndex = 0;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final TextEditingController _destinationController = TextEditingController();
  String _sessionToken = '';
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isMounted = false;
  late BitmapDescriptor _userIcon;
  late BitmapDescriptor _largeHoleIcon;
  late BitmapDescriptor _maintainRoadIcon;
  bool _isWarningDisplayed = false;
  Map<int, Set<String>> _holeWarnings = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  double? _currentDistance;
  final myBox = Hive.box('myBox');
  String _idUser = '';
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(16.0736, 108.1499),
    zoom: 14.4746,
  );

  void _clearSearch() {
    setState(() {
      _destinationController.clear();
      _selectedPosition = null;
      _polylines.clear();
      _markers.removeWhere((marker) => marker.markerId.value == 'selectedLocation');
      _sessionToken = '';
      _currentDistance = 0;
      largeHoles = [];
      maintainRoad = [];
      _holeWarnings.clear();
    });
    FocusScope.of(context).unfocus(); // Ẩn bàn phím
  }

  Future<void> _triggerAlert() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate();
    }
    await _audioPlayer.play(AssetSource('alert_10.mp3'));
  }

  Future<void> _triggerAlert2() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate();
    }
    await _audioPlayer.play(AssetSource('alert_50.mp3'));
  }

  Future<void> _triggerAlert3() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate();
    }
    await _audioPlayer.play(AssetSource('alert_100.mp3'));
  }

  Future<void> _triggerAlert4() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate();
    }
    await _audioPlayer.play(AssetSource('alert_near.mp3'));
  }

  Future<void> _stopAlert() async {
    await _audioPlayer.stop();
  }

  Future<void> _loadCustomIcons() async {
    final Uint8List location = await getBytesFromAsset(
      'assets/images/car.png',
      160,
    );
    final Uint8List maintain = await getBytesFromAsset(
      'assets/images/fix_road.png',
      160,
    );
    final Uint8List largeHole = await getBytesFromAsset(
      'assets/images/large_hole.png',
      130,
    );

    if (mounted) {
      setState(() {
        _userIcon = BitmapDescriptor.fromBytes(location);
        _largeHoleIcon = BitmapDescriptor.fromBytes(largeHole);
        _maintainRoadIcon = BitmapDescriptor.fromBytes(maintain);
      });
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  }

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _loadCustomIcons().then((_) {
      if (_isMounted) {
        _getCurrentLocation();
      }
    });
    _destinationController.addListener(() {
      if (_sessionToken.isEmpty && mounted) {
        setState(() {
          _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    _positionStreamSubscription?.cancel();
    _destinationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _updateMarkers() {
    if (_isMounted) {
      setState(() {
        _markers.removeWhere(
          (marker) =>
              marker.markerId.value.contains('largeHole') ||
              marker.markerId.value.contains('maintainRoad'),
        );
        _markers.add(
          Marker(
            markerId: MarkerId('currentLocation'),
            position: LatLng(
              _currentPosition.latitude,
              _currentPosition.longitude,
            ),
            infoWindow: InfoWindow(title: 'Current Location'),
            icon: _userIcon,
          ),
        );

        int largeHoleIndex = 0;
        for (var item in largeHoles) {
          _markers.add(
            Marker(
              markerId: MarkerId('largeHole$largeHoleIndex'),
              position: LatLng(item[0], item[1]),
              infoWindow: InfoWindow(
                title: 'Large Hole',
                snippet: 'Be cautious!',
              ),
              icon: _largeHoleIcon,
            ),
          );
          largeHoleIndex++;
        }
        int maintainRoadIndex = 0;
        for (var item in maintainRoad) {
          _markers.add(
            Marker(
              markerId: MarkerId('maintainRoad$maintainRoadIndex'),
              position: LatLng(item[0], item[1]),
              infoWindow: InfoWindow(
                title: 'Maintain Road',
                snippet: 'Be cautious!',
              ),
              icon: _maintainRoadIcon,
            ),
          );
          maintainRoadIndex++;
        }
        if (_selectedPosition != null) {
          _markers.add(
            Marker(
              markerId: MarkerId('selectedLocation'),
              position: _selectedPosition!,
              infoWindow: InfoWindow(title: 'Selected Location'),
            ),
          );
        }
      });
    }
  }

  void _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    if (!_isMounted) return;
    if (_isMounted) {
      setState(() {
        _currentPosition = position;
        _markers.add(
          Marker(
            markerId: MarkerId('currentLocation'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: InfoWindow(title: 'Current Location'),
            icon: _userIcon,
          ),
        );
      });
    }
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 16.0,
        ),
      ),
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (_isMounted) {
        setState(() {
          _currentPosition = position;
          _markers.removeWhere((m) => m.markerId.value == 'currentLocation');
          _markers.add(
            Marker(
              markerId: MarkerId('currentLocation'),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: InfoWindow(title: 'Current Location'),
              icon: _userIcon,
            ),
          );
        });
        _updateCameraPosition(position);
        _checkProximityToLargeHoles();
      }
    });
  }

  Future<void> _updateCameraPosition(Position position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 18.0,
        ),
      ),
    );
  }

  void _checkProximityToLargeHoles() async {
    if (_currentHoleIndex < largeHoles.length && !_isWarningDisplayed) {
      var hole = largeHoles[_currentHoleIndex];
      final double distance = Geolocator.distanceBetween(
        _currentPosition.latitude,
        _currentPosition.longitude,
        hole[0],
        hole[1],
      );
      if (_isMounted) {
        setState(() {
          _currentDistance = distance;
        });
      }
      print('Distance to large hole: $distance');
      print('Current hole index: $_currentHoleIndex');

      if (distance < 10 && !_hasWarningBeenShown(_currentHoleIndex, '10m')) {
        _triggerAlert();
        _isWarningDisplayed = true; // Set the warning displayed flag to true
        await _showWarningDialog(
          'You are within 10 meters of a large hole!',
          3,
        );
        _markWarningAsShown(_currentHoleIndex, '10m');
        if (_currentHoleIndex < largeHoles.length - 1) {
          var nextHole = largeHoles[_currentHoleIndex + 1];
          final double nextDistance = Geolocator.distanceBetween(
            hole[0],
            hole[1],
            nextHole[0],
            nextHole[1],
          );
          print('nextDistance: $nextDistance');
          if (nextDistance < 30) {
            _triggerAlert4();
            _isWarningDisplayed = true;
            await _showWarningDialog(
              'Another hole in the front, be careful!',
              3,
            );
            _currentHoleIndex++;
            _isWarningDisplayed = false;
          }
        }
        _currentHoleIndex++;
        _isWarningDisplayed = false; // Reset the warning displayed flag
        _stopAlert();
      } else if (30 < distance &&
          distance < 50 &&
          !_hasWarningBeenShown(_currentHoleIndex, '50m')) {
        _isWarningDisplayed = true;
        _triggerAlert2();
        await _showWarningDialog(
          'You are within 50 meters of a large hole!',
          3,
        );
        _markWarningAsShown(_currentHoleIndex, '50m');
        _isWarningDisplayed = false;
        _stopAlert();
      } else if (80 < distance &&
          distance < 100 &&
          !_hasWarningBeenShown(_currentHoleIndex, '100m')) {
        _triggerAlert3();
        _isWarningDisplayed = true;
        await _showWarningDialog(
          'You are within 100 meters of a large hole!',
          3,
        );
        _markWarningAsShown(_currentHoleIndex, '100m');
        _isWarningDisplayed = false;
        _stopAlert();
      }
    } else {
      if (_isMounted) {
        setState(() {
          _currentDistance = 0;
        });
      }
    }
  }

  Future<void> _showWarningDialog(String message, int seconds) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        Future.delayed(Duration(seconds: seconds), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });

        return AlertDialog(title: Text('Warning'), content: Text(message));
      },
    );
  }

  bool _hasWarningBeenShown(int holeIndex, String distanceLabel) {
    return _holeWarnings[holeIndex]?.contains(distanceLabel) ?? false;
  }

  void _markWarningAsShown(int holeIndex, String distanceLabel) {
    if (_holeWarnings[holeIndex] == null) {
      _holeWarnings[holeIndex] = {};
    }
    _holeWarnings[holeIndex]!.add(distanceLabel);
  }

  Future<void> _drawRoute(LatLng destination) async {
    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition.latitude},${_currentPosition.longitude}&destination=${destination.latitude},${destination.longitude}&key=$api_key',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = PolylinePoints().decodePolyline(
        data['routes'][0]['overview_polyline']['points'],
      );
      if (!_isMounted) return;
      if (_isMounted) {
        setState(() {
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route'),
              points:
                  points
                      .map((point) => LatLng(point.latitude, point.longitude))
                      .toList(),
              color: Colors.blue,
              width: 5,
            ),
          );
        });
      }
      // Print the coordinates of the route and upload them to the server
      List<Map<String, double>> coordinates = [];
      points.forEach((point) {
        coordinates.add({
          'latitude': point.latitude,
          'longitude': point.longitude,
        });
        print('Coordinate: ${point.latitude}, ${point.longitude}');
      });
      await _uploadCoordinates(coordinates);
    } else {
      throw Exception('Failed to load directions');
    }
  }

  Future<void> _sendHelp() async {
    _idUser = myBox.get('userId', defaultValue: '');
    String location =
        '(${_currentPosition.latitude}, ${_currentPosition.longitude})';
    final Map<String, dynamic> requestBody = {"location": location};
    try {
      final response = await http.post(
        Uri.parse('$ip/user/send-help/$_idUser'),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );
      print(response.statusCode);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Send help successfully!'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error send!'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      print('Error: $error');
    }
  }

  Future<void> _showMaintenanceWarningDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cảnh báo'),
          content: Text(
            'Đoạn đường bạn đi đang được bảo trì, bạn có muốn tiếp tục không?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text('Tiếp tục'),
            ),
            TextButton(
              onPressed: () {
                _clearTrack();
                Navigator.of(context).pop(false);
              },
              child: Text('Hủy bỏ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadCoordinates(List<Map<String, double>> coordinates) async {
    final response = await http.post(
      Uri.parse('$ip/detection/post-location-tracking'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'coordinates': coordinates}),
    );

    if (response.statusCode == 200) {
      print('Response: ${response.body}');

      List<dynamic> Hole = jsonDecode(response.body)['matchingCoordinatesHole'];
      List<dynamic> MaintainRoad =
          jsonDecode(response.body)['matchingCoordinatesMaintainRoad'];

      if (_isMounted) {
        setState(() {
          largeHoles = Hole;
          maintainRoad = MaintainRoad;
          _currentHoleIndex = 0;
          _holeWarnings.clear();
        });
      }
      _updateMarkers();
      if (maintainRoad.isNotEmpty) {
        _showMaintenanceWarningDialog();
      }
      if (largeHoles.isEmpty) {
        if (_isMounted) {
          setState(() {
            _currentDistance = 0;
          });
        }
      } else {
        var hole = largeHoles[0];
        final double distance = Geolocator.distanceBetween(
          _currentPosition.latitude,
          _currentPosition.longitude,
          hole[0],
          hole[1],
        );
        if (_isMounted) {
          setState(() {
            _currentDistance = distance;
          });
        }
      }

      print('Coordinates uploaded successfully');
      print('Matching Coordinates: $largeHoles');
    } else {
      throw Exception('Failed to upload coordinates');
    }
  }

  Future<void> _searchDestination(String address) async {
    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$api_key',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final location = data['results'][0]['geometry']['location'];
      final LatLng destination = LatLng(location['lat'], location['lng']);

      if (!_isMounted) return;
      if (_isMounted) {
        setState(() {
          _selectedPosition = destination;
          _markers.add(
            Marker(
              markerId: MarkerId('selectedLocation'),
              position: destination,
              infoWindow: InfoWindow(title: 'Selected Location'),
            ),
          );
        });
      }
      _drawRoute(destination);
    } else {
      throw Exception('Failed to load geocoding data');
    }
  }

  Future<List<String>> _fetchSuggestions(String input) async {
    if (_sessionToken.isEmpty) {
      return [];
    }

    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$api_key&sessiontoken=$_sessionToken',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final predictions = data['predictions'];
      return List<String>.from(predictions.map((p) => p['description']));
    } else {
      throw Exception('Failed to load place predictions');
    }
  }

  void _onMapTapped(LatLng position) {
    if (_isMounted) {
      setState(() {
        _selectedPosition = position;
        _markers.add(
          Marker(
            markerId: MarkerId('selectedLocation'),
            position: position,
            infoWindow: InfoWindow(title: 'Selected Location'),
          ),
        );
      });
    }
    _drawRoute(position);
  }

  void _clearTrack() {
    if (_isMounted) {
      setState(() {
        _markers.removeWhere(
          (marker) =>
              marker.markerId.value.contains('largeHole') ||
              marker.markerId.value.contains('maintainRoad') ||
              marker.markerId.value == 'selectedLocation',
        );
        _polylines.clear();
        _selectedPosition = null;
        _currentHoleIndex = 0;
        _currentDistance = 0;
        largeHoles = [];
        maintainRoad = [];
        _holeWarnings.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.terrain,
            initialCameraPosition: _initialPosition,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onTap: _onMapTapped,
            onCameraMove: (CameraPosition position) {
              _selectedPosition = position.target;
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TypeAheadField<String>(
                        suggestionsCallback: (pattern) async {
                          return await _fetchSuggestions(pattern);
                        },
                        itemBuilder: (context, suggestion) {
                          return ListTile(
                            title: Text(suggestion),
                          );
                        },
                        onSelected: (suggestion) {
                          _destinationController.text = suggestion;
                          _searchDestination(suggestion);
                          FocusScope.of(context).unfocus();
                        },
                        controller: _destinationController,
                        builder: (context, controller, focusNode) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Nhập điểm đến',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          );
                        },
                        emptyBuilder: (context) => Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Không tìm thấy kết quả!',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _destinationController,
                      builder: (context, value, child) {
                        return value.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.cancel),
                          onPressed: _clearSearch,
                          tooltip: 'Hủy tìm kiếm',
                        )
                            : IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () {
                            _searchDestination(_destinationController.text);
                          },
                        );
                      },
                    ),
                  ],
                ),
                if (_currentDistance != null)
                  Container(
                    padding: EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 5.0,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Khoảng cách đến ổ gà gần nhất: ${_currentDistance!.toStringAsFixed(2)} mét',
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 85.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'tracking-location',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _getCurrentLocation,
              tooltip: 'Hiển thị vị trí của tôi',
              child: Image.asset('assets/images/car.png', width: 30, height: 30),
            ),
          ),
          Positioned(
            bottom: 130.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'tracking-clear',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _clearTrack,
              tooltip: 'Xóa lộ trình',
              child: const Icon(Icons.clear),
            ),
          ),
          Positioned(
            bottom: 175.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'tracking-help',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: () => _sendHelp(),
              tooltip: 'Gửi trợ giúp',
              child: const Icon(Icons.health_and_safety),
            ),
          ),
        ],
      ),
    );
  }
}
