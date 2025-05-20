import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter/services.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';

import '../../services/detection_service.dart';

class MaintainMapScreen extends StatefulWidget {
  const MaintainMapScreen({Key? key}) : super(key: key);

  @override
  State<MaintainMapScreen> createState() => MaintainMapScreenState();
}

class MaintainMapScreenState extends State<MaintainMapScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  Set<Marker> _markers = {};
  Map<PolylineId, Polyline> polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _iconsLoaded = false;
  Position? _currentPosition;
  LatLng? _sourcePosition;
  LatLng? _destinationPosition;
  late BitmapDescriptor _maintainIcon;
  late BitmapDescriptor _userIcon;

  bool _isSelectingSource = true;
  bool _isSelectingByHand = false;

  static CameraPosition _kGooglePlex = const CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _loadCustomIcons().then((_) {
      _getUserLocation();
      _fetchAndDrawRoutes();
      _showMyLocation();
    });
  }

  void reload() {
    _showMyLocation();
  }

  Future<void> _loadCustomIcons() async {
    final Uint8List location = await getBytesFromAsset(
      'assets/images/car.png',
      100,
    );
    final Uint8List maintain = await getBytesFromAsset(
      'assets/images/fix_road.png',
      130,
    );
    setState(() {
      _userIcon = BitmapDescriptor.fromBytes(location);
      _maintainIcon = BitmapDescriptor.fromBytes(maintain);
    });
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

  void _showMyLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 17.0,
        ),
      ),
    );
  }

  Future<void> _getUserLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _kGooglePlex = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 14.4746,
    );
    _addMarker(position);
  }

  void _addMarker(Position position) {
    setState(() {
      _markers.add(
        Marker(
          icon: _userIcon,
          markerId: MarkerId('myLocation'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: InfoWindow(
            title: 'Your Location',
            snippet: 'This is where you are.',
          ),
        ),
      );
    });
  }

  void _updateMarkerPosition(Position position) {
    setState(() {
      _currentPosition = position;
      _markers.removeWhere((marker) => marker.markerId.value == 'myLocation');
      _markers.add(
        Marker(
          markerId: MarkerId('myLocation'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: InfoWindow(
            title: 'Your Location',
            snippet: 'This is where you are.',
          ),
        ),
      );
    });
  }

  Future<List<String>> _fetchSuggestions(String query) async {
    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$api_key',
      ),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final predictions = data['predictions'];
      return List<String>.from(predictions.map((p) => p['description']));
    } else {
      throw Exception('Failed to load suggestions');
    }
  }

  Future<void> _searchLocation(String address, bool isSource) async {
    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$api_key',
      ),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final location = data['results'][0]['geometry']['location'];
      final LatLng position = LatLng(location['lat'], location['lng']);

      setState(() {
        if (isSource) {
          _sourcePosition = position;
          _markers.add(
            Marker(
              markerId: MarkerId('sourceLocation'),
              position: position,
              infoWindow: InfoWindow(title: 'Source Location'),
            ),
          );
        } else {
          _destinationPosition = position;
          _markers.add(
            Marker(
              markerId: MarkerId('destinationLocation'),
              position: position,
              infoWindow: InfoWindow(title: 'Destination Location'),
            ),
          );
        }
      });

      if (_sourcePosition != null && _destinationPosition != null) {
        await _drawRoute(_sourcePosition!, _destinationPosition!);
      }
    } else {
      throw Exception('Failed to load location');
    }
  }

  Future<void> _drawRoute(LatLng source, LatLng destination) async {
    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&key=$api_key',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = polylinePoints.decodePolyline(
        data['routes'][0]['overview_polyline']['points'],
      );
      List<LatLng> polylineCoordinates = [];
      if (points.isNotEmpty) {
        points.forEach((point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });
      }

      setState(() {
        final id = PolylineId(source.toString() + '_' + destination.toString());
        Polyline polyline = Polyline(
          polylineId: id,
          color: Colors.blue,
          points: polylineCoordinates,
          width: 5,
        );
        polylines[id] = polyline;
      });
    } else {
      throw Exception('Failed to load directions');
    }
  }

  Future<void> _drawRouteForMap(LatLng source, LatLng destination, int date, String createdAt, String updatedAt) async {
    final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&key=$api_key'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = polylinePoints.decodePolyline(data['routes'][0]['overview_polyline']['points']);
      List<LatLng> polylineCoordinates = [];

      if (points.isNotEmpty) {
        points.forEach((point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });
      }

      if (!mounted) return; // 🔥 Kiểm tra widget còn mounted không trước khi gọi setState()

      setState(() {
        final id = PolylineId(source.toString() + '_' + destination.toString());
        Polyline polyline = Polyline(
          polylineId: id,
          color: Colors.red,
          points: polylineCoordinates,
          width: 5,
        );
        polylines[id] = polyline;

        if (polylineCoordinates.length > 1) {
          LatLng midPoint = polylineCoordinates[(polylineCoordinates.length / 2).round()];
          _markers.add(
            Marker(
              markerId: MarkerId('midpoint_${id.value}'),
              position: midPoint,
              icon: _maintainIcon,
              infoWindow: InfoWindow(
                title: 'Date maintain: ${date}d',
                snippet: '${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(createdAt))} - ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(updatedAt))}',
              ),
            ),
          );
        }
      });
    } else {
      if (!mounted) return; // 🔥 Kiểm tra nếu widget đã bị dispose
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load directions'))
      );
    }
  }

  int _calculateTotalDays() {
    if (_startDate != null && _endDate != null) {
      return _endDate!.difference(_startDate!).inDays;
    }
    return 0;
  }

  Future<void> _showMaintainDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Chọn thời gian bảo trì'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(
                        _startDate == null
                            ? "Chọn ngày bắt đầu"
                            : "Ngày bắt đầu: ${DateFormat('yyyy/MM/dd').format(_startDate!)}",
                      ),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime.now(), // Restrict to today or later
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _startDate = pickedDate;
                            // Reset endDate if it's before the new startDate
                            if (_endDate != null && _endDate!.isBefore(pickedDate)) {
                              _endDate = null;
                              _endTime = null;
                            }
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        _startTime == null
                            ? "Chọn giờ bắt đầu"
                            : "Giờ bắt đầu: ${_startTime!.format(context)}",
                      ),
                      trailing: Icon(Icons.access_time),
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _startTime ?? TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setState(() {
                            _startTime = pickedTime;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        _endDate == null
                            ? "Chọn ngày kết thúc"
                            : "Ngày kết thúc: ${DateFormat('yyyy/MM/dd').format(_endDate!)}",
                      ),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? (_startDate ?? DateTime.now()),
                          firstDate: _startDate ?? DateTime.now(), // Restrict to startDate or later
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _endDate = pickedDate;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        _endTime == null
                            ? "Chọn giờ kết thúc"
                            : "Giờ kết thúc: ${_endTime!.format(context)}",
                      ),
                      trailing: Icon(Icons.access_time),
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _endTime ?? TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setState(() {
                            _endTime = pickedTime;
                          });
                        }
                      },
                    ),
                    if (_startDate != null && _endDate != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Tổng số ngày bảo trì: ${_calculateTotalDays()} ngày",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Hủy'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Gửi'),
                  onPressed: () {
                    if (_startDate == null ||
                        _endDate == null ||
                        _startTime == null ||
                        _endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Vui lòng chọn đầy đủ ngày và giờ bắt đầu, kết thúc',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    // Validate endDateTime is not before startDateTime
                    final startDateTime = DateTime(
                      _startDate!.year,
                      _startDate!.month,
                      _startDate!.day,
                      _startTime!.hour,
                      _startTime!.minute,
                    );
                    final endDateTime = DateTime(
                      _endDate!.year,
                      _endDate!.month,
                      _endDate!.day,
                      _endTime!.hour,
                      _endTime!.minute,
                    );
                    if (endDateTime.isBefore(startDateTime)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ngày kết thúc phải sau ngày bắt đầu',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    _sendMaintainRequest();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendMaintainRequest() async {
    if (_sourcePosition != null &&
        _destinationPosition != null &&
        _startDate != null &&
        _endDate != null &&
        _startTime != null &&
        _endTime != null) {
      // Kết hợp ngày và giờ
      final startDateTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );
      final endDateTime = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );

      final response = await http.post(
        Uri.parse('$ip/detection/create-maintain-road'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'locationA': _sourcePosition.toString(),
          'locationB': _destinationPosition.toString(),
          'startDate': startDateTime.toIso8601String(),
          'endDate': endDateTime.toIso8601String(),
          'totalDays': _calculateTotalDays(),
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gửi dữ liệu thành công'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
        _markers.removeWhere((marker) => marker.markerId.value != 'myLocation');
        await _fetchAndDrawRoutes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi dữ liệu'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng nhập đầy đủ thông tin'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchAndDrawRoutes() async {
    final response = await getListMaintainForMapService.getListMaintainForMap();

    if (!mounted) return;

    if (response['status'] == 'OK') {
      final data = response['data'];
      for (var route in data) {
        final locationA = _parseLatLng(route['locationA']);
        final locationB = _parseLatLng(route['locationB']);
        final date = route['dateMaintain'];
        final createdAt = route['createdAt'];
        final updatedAt = route['updatedAt'];
        await _drawRouteForMap(locationA, locationB, date, createdAt, updatedAt);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to fetch routes')),
      );
    }
  }

  LatLng _parseLatLng(String latLngString) {
    final parts = latLngString
        .replaceAll('LatLng(', '')
        .replaceAll(')', '')
        .split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }

  void _clearMarkersAndPolylines() {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value != 'myLocation');
      polylines.clear();
      _fetchAndDrawRoutes();
      _sourcePosition = null;
      _destinationPosition = null;
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectingByHand = !_isSelectingByHand;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSelectingByHand
              ? 'Chế độ chọn bằng tay: Bật'
              : 'Chế độ chọn bằng tay: Tắt',
        ),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handleMapTap(LatLng tappedPoint) {
    if (_isSelectingByHand) {
      setState(() {
        if (_isSelectingSource) {
          _sourcePosition = tappedPoint;
          _markers.add(
            Marker(
              markerId: MarkerId('sourceLocation'),
              position: tappedPoint,
              infoWindow: InfoWindow(title: 'Source Location'),
            ),
          );
          _isSelectingSource = false; // Switch to selecting destination next
        } else {
          _destinationPosition = tappedPoint;
          _markers.add(
            Marker(
              markerId: MarkerId('destinationLocation'),
              position: tappedPoint,
              infoWindow: InfoWindow(title: 'Destination Location'),
            ),
          );
          _isSelectingSource = true; // Switch back to selecting source next

          if (_sourcePosition != null && _destinationPosition != null) {
            _drawRoute(_sourcePosition!, _destinationPosition!);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Maintain Road')),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.terrain,
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            markers: _markers,
            polylines: Set<Polyline>.of(polylines.values),
            onTap: _handleMapTap,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
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
                          return ListTile(title: Text(suggestion));
                        },
                        onSelected: (suggestion) {
                          _sourceController.text = suggestion;
                          _searchLocation(suggestion, true);
                        },
                        builder: (context, controller, focusNode) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Enter source location',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.search),
                      onPressed: () {
                        _searchLocation(_sourceController.text, true);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TypeAheadField<String>(
                        suggestionsCallback: (pattern) async {
                          return await _fetchSuggestions(pattern);
                        },
                        itemBuilder: (context, suggestion) {
                          return ListTile(title: Text(suggestion));
                        },
                        onSelected: (suggestion) {
                          _destinationController.text = suggestion;
                          _searchLocation(suggestion, false);
                        },
                        builder: (context, controller, focusNode) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Enter destination location',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.search),
                      onPressed: () {
                        _searchLocation(_destinationController.text, false);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: <Widget>[
          Positioned(
            bottom: 85.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'Show My Location Maintain road',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: reload,
              tooltip: 'Show My Location',
              child: Image.asset(
                'assets/images/car.png',
                width: 30,
                height: 30,
              ),
            ),
          ),
          Positioned(
            bottom: 130.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'Upload Maintain Road',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _showMaintainDialog,
              tooltip: 'Upload Maintain Road',
              child: Icon(Icons.upload),
            ),
          ),
          Positioned(
            bottom: 170.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'Toggle Select Mode',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _toggleSelectMode,
              tooltip: 'Toggle Select Mode',
              child: Icon(
                _isSelectingByHand ? Icons.touch_app : Icons.pan_tool,
              ),
            ),
          ),
          Positioned(
            bottom: 210.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'Clear All Maintain Road',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _clearMarkersAndPolylines,
              tooltip: 'Clear All',
              child: const Icon(Icons.clear),
            ),
          ),
        ],
      ),
    );
  }
}
