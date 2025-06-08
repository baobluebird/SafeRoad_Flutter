import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'package:pothole/screens/detection/road_detail.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../model/detection.dart';
import '../../services/detection_service.dart';
import '../detection/damage_detail.dart';
import '../detection/detection_for_detail.dart';
import '../detection/edit_screen.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  PolylinePoints polylinePoints = PolylinePoints();
  Map<PolylineId, Polyline> polylines = {};

  Set<Marker> _markers = {};
  late BitmapDescriptor _userIcon;
  late BitmapDescriptor _smallHoleIcon;
  late BitmapDescriptor _largeHoleIcon;
  late BitmapDescriptor _smallCrackIcon;
  late BitmapDescriptor _largeCrackIcon;
  late BitmapDescriptor _maintainIcon;
  late BitmapDescriptor _damageIcon;

  late Detection? detection;

  List<dynamic>? _listHole;
  List<dynamic>? _listCrack;
  List<dynamic>? _listMaintain;
  List<dynamic>? _listDamage;

  // List<dynamic> smallHoles = [];
  // List<dynamic> largeHoles = [];
  // List<dynamic> smallCracks = [];
  // List<dynamic> largeCracks = [];

  List<dynamic> holes = [];
  List<dynamic> cracks = [];

  int _totalHole = 0;
  int _totalCrack = 0;
  int _totalMaintain = 0;
  int _totalDamage = 0;

  late IO.Socket socket;

  bool _iconsLoaded = false;

  static CameraPosition _kGooglePlex = const CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();

    socket = IO.io(socketIp, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('Connected to server');
    });

    socket.onDisconnect((_) {
      print('Disconnected from server');
    });

    socket.on('newDamageRoad', (data) {
      print('New damage road received: $data');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('New damage road added: ${data['name']}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1)
        ),
      );
      if (data != null && data is Map<String, dynamic>) {
        setState(() {
          // Add the new damage to the _listDamage
          _listDamage ??= [];
          _listDamage!.add({
            '_id': data['id'],
            'name': data['name'],
            'sourceName': data['sourceName'],
            'destinationName': data['destinationName'],
            'locationA': data['locationA'],
            'locationB': data['locationB'],
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
          });
          _totalDamage = _listDamage!.length;
        });

        // Draw the new damage route on the map
        final locationA = _parseLatLng(data['locationA']);
        final locationB = _parseLatLng(data['locationB']);
        if (locationA != null && locationB != null) {
          _drawRouteDamageFormap(
            data['name'],
            data['sourceName'],
            data['destinationName'],
            locationA,
            locationB,
            data['createdAt'],
          );
        }
      }
    });

    socket.on('newDataAdded', (data) {
      print('New detection received: $data');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('New detection added: ${data['name']}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1)
        ),
      );
      if (data != null && data is Map<String, dynamic>) {
        setState(() {
          if (data['name'] == 'Ổ gà') {
            _listHole ??= [];
            _listHole!.add({
              '_id': data['_id'],
              'name': data['name'],
              'location': data['location'],
              'address': data['address'],
              'description': data['description'],
              'image': data['image'],
              'createdAt': data['createdAt'],
              'updatedAt': data['updatedAt'],
            });
            _totalHole = _listHole!.length;
            holes = _listHole!;
          } else if (data['name'] == 'Vết nứt') {
            _listCrack ??= [];
            _listCrack!.add({
              '_id': data['_id'],
              'name': data['name'],
              'location': data['location'],
              'address': data['address'],
              'description': data['description'],
              'image': data['image'],
              'createdAt': data['createdAt'],
              'updatedAt': data['updatedAt'],
            });
            _totalCrack = _listCrack!.length;
            cracks = _listCrack!;
          }
        });

        // Add marker for the new detection
        if (_iconsLoaded) {
          final coordinates = _parseLocation(data['location']);
          if (coordinates != null) {
            setState(() {
              _markers.add(
                Marker(
                  markerId: MarkerId(data['location']),
                  position: coordinates,
                  onTap: () {
                    if (data['name'] == 'Ổ gà') {
                      _getDetailHole(data['_id']);
                    } else if (data['name'] == 'Vết nứt') {
                      _getDetailCrack(data['_id']);
                    }
                  },
                  infoWindow: InfoWindow(title: data['name']),
                  icon: data['name'] == 'Ổ gà' ? _largeHoleIcon : _largeCrackIcon,
                ),
              );
            });
          } else {
            print('Invalid coordinates for new detection: $data');
          }
        }
      }
    });

    // Listener for newMaintainRoad
    socket.on('newMaintainRoad', (data) {
      print('New maintain road received: $data');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('New maintain road added'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1)
        ),
      );
      if (data != null && data is Map<String, dynamic>) {
        setState(() {
          _listMaintain ??= [];
          _listMaintain!.add({
            '_id': data['id'],
            'sourceName': data['sourceName'],
            'destinationName': data['destinationName'],
            'locationA': data['locationA'],
            'locationB': data['locationB'],
            'startDate': data['startDate'],
            'endDate': data['endDate'],
            'dateMaintain': data['dateMaintain'],
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
          });
          _totalMaintain = _listMaintain!.length;
        });

        final locationA = _parseLatLng(data['locationA']);
        final locationB = _parseLatLng(data['locationB']);
        if (locationA != null && locationB != null) {
          _drawRouteMaintainFormap(
            data['sourceName'],
            data['destinationName'],
            locationA,
            locationB,
            data['dateMaintain'],
            data['startDate'],
            data['endDate'],
          );
        } else {
          print('Invalid coordinates for new maintain road: $data');
        }
      }
    });

    _loadCustomIcons().then((_) {
      _iconsLoaded = true;
      _getUserLocation();
      _getListHoles();
      _getListCracks();
      _getListMaintain();
      _getListDamage();
      _showMyLocation();
    });
    _startLocationUpdates();
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }

  void _updateMarkers() {
    // smallHoles = [];
    // largeHoles = [];
    // smallCracks = [];
    // largeCracks = [];
    holes = [];
    cracks = [];
    _markers.clear();
    polylines.clear();
    _getUserLocation();
    _getListHoles();
    _getListCracks();
    _getListMaintain();
    _getListDamage();
    _showMyLocation();
  }

  void _startLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _updateUserLocationMarker(position);
    });
  }

  void _updateUserLocationMarker(Position position) {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'myLocation');
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

  LatLng? _parseLocation(String? location) {
    if (location == null) return null;
    var latitudeRegExp = RegExp(r'latitude:([0-9.]+)');
    var longitudeRegExp = RegExp(r'longitude:([0-9.]+)');
    var latitudeMatch = latitudeRegExp.firstMatch(location);
    var longitudeMatch = longitudeRegExp.firstMatch(location);
    if (latitudeMatch != null && longitudeMatch != null) {
      var latitude = double.tryParse(latitudeMatch.group(1)!);
      var longitude = double.tryParse(longitudeMatch.group(1)!);
      if (latitude != null && longitude != null) {
        return LatLng(latitude, longitude);
      }
    }
    return null;
  }

//get list hole
  Future<void> _getListHoles() async {
    final Map<String, dynamic> response =
        await getListHolesService.getListHoles();
    if (response['status'] == 'OK') {
      if (response['data'] is String && response['data'] == 'null') {
        setState(() {
          _listHole = [];
        });
      } else {
        setState(() {
          _listHole = response['data'];
          _totalHole = response['total'];
          holes = _listHole!;
          // for (var item in _listHole!) {
          //   if (item['description'] == 'Small') {
          //     smallHoles.add(item);
          //   } else {
          //     largeHoles.add(item);
          //   }
          // }
        });
        if (_iconsLoaded) {
          _addMarkersHoles();
        }
      }
    } else {
      print('Error occurred: ${response['message']}');
    }
  }

  void _addMarkersHoles() {
    for (var item in holes) {
      var location = item['location'];
      var coordinates = _parseLocation(location);
      if (coordinates != null) {
        _markers.add(
          Marker(
            markerId: MarkerId(location),
            position: coordinates,
            onTap: () {
              _getDetailHole(item['_id']);
            },
            infoWindow: InfoWindow(
              title: 'Hole',
            ),
            icon: _largeHoleIcon, // luôn dùng icon large
          ),
        );
        setState(() {});
      }
    }
  }

  Future<void> _getDetailHole(String id) async {
    final Map<String, dynamic> response =
        await getDetailHoleService.getDetailHole(id);
    if (response['status'] == 'OK') {
      final Map<String, dynamic> detectionData = response['data'];
      detection = Detection.fromJson(detectionData);

      String? imageData;
      if (response['image'] != null) {
        imageData = response['image'];
      }
      if (imageData != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetectionForDetailScreen(
              detection: detection,
              imageData: imageData!,
            ),
          ),
        );
      }
    } else {
      print('Error occurred: ${response['message']}');
    }
  }

  Future<void> _deleteDetection(String detectionId, String nameList) async {
    final response = await deleteDetectionService.deleteDetection(detectionId, nameList);

    if (response['status'] == 'OK') {
      setState(() {
        if (nameList == 'Hole') {
          _listHole!.removeWhere((hole) => hole['_id'] == detectionId);
          _totalHole = _listHole!.length;
        } else if (nameList == 'Crack') {
          _listCrack!.removeWhere((crack) => crack['_id'] == detectionId);
          _totalCrack = _listCrack!.length;
        } else if (nameList == 'Damage')
        {
          _listDamage!.removeWhere((damage) => damage['_id'] == detectionId);
          _totalDamage = _listDamage!.length;
        }else {
          _listMaintain!.removeWhere((maintain) => maintain['_id'] == detectionId);
          _totalMaintain = _listMaintain!.length;
        }
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$nameList deleted successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1)
        ),
      );

      _updateMarkers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete $nameList.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 1)
        ),
      );
    }
  }


  Future<void> _showDeleteConfirmationDialog(
      String detectionId, String nameList) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Xác nhận xóa"),
          content: Text("Bạn có chắc chắn muốn xóa đơn vị này không?"),
          actions: <Widget>[
            TextButton(
              child: Text("Hủy"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Xác nhận"),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteDetection(detectionId, nameList);
              },
            ),
          ],
        );
      },
    );
  }

  //get list crack
  Future<void> _getListCracks() async {
    final Map<String, dynamic> response =
        await getListCracksService.getListCracks();
    if (response['status'] == 'OK') {
      if (response['data'] is String && response['data'] == 'null') {
        setState(() {
          _listCrack = [];
        });
      } else {
        setState(() {
          _listCrack = response['data'];
          _totalCrack = response['total'];
          cracks = _listCrack!;
        });
        // for (var item in _listCrack!) {
        //   if (item['description'] == 'Small') {
        //     smallCracks.add(item);
        //   } else {
        //     largeCracks.add(item);
        //   }
        // }
        if (_iconsLoaded) {
          _addMarkersCracks();
        }
      }
    } else {
      print('Error occurred: ${response['message']}');
    }
  }

  void _addMarkersCracks() {
    for (var item in cracks) {
      var location = item['location'];
      var coordinates = _parseLocation(location);
      if (coordinates != null) {
        _markers.add(
          Marker(
            markerId: MarkerId(location),
            position: coordinates,
            onTap: () {
              _getDetailCrack(item['_id']);
            },
            infoWindow: InfoWindow(
              title: 'Crack',
            ),
            icon: _largeCrackIcon,
          ),
        );
        setState(() {});
      }
    }
  }


  Future<void> _getDetailCrack(String id) async {
    final Map<String, dynamic> response =
        await getDetailCrackService.getDetailCrack(id);
    if (response['status'] == 'OK') {
      final Map<String, dynamic> detectionData = response['data'];
      detection = Detection.fromJson(detectionData);

      String? imageData;
      if (response['image'] != null) {
        imageData = response['image'];
      }
      if (imageData != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetectionForDetailScreen(
              detection: detection,
              imageData: imageData!,
            ),
          ),
        );
      }
    } else {
      print('Error occurred: ${response['message']}');
    }
  }

  //get list maintain
  Future<void> _getListMaintain() async {
    final response = await getListMaintainService.getListMaintain();

    if (response['status'] == 'OK') {
      final data = response['data'];
      setState(() {
        _listMaintain = data;
        _totalMaintain = data.length;
      });

      for (var route in data) {
        final locationA = _parseLatLng(route['locationA']);
        final locationB = _parseLatLng(route['locationB']);
        final dateMaintain = route['dateMaintain'];
        final createdAt = route['createdAt'];
        final updatedAt = route['updatedAt'];

        await _drawRouteMaintainFormap(
          route['sourceName'],
          route['destinationName'],
          locationA,
          locationB,
          dateMaintain,
          createdAt,
          updatedAt,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch maintain list')),
      );
    }
  }

  //get list damage
  Future<void> _getListDamage() async {
    final response = await getListDamageForMapService.getListDamageForMap();

    if (response['status'] == 'OK') {
      final data = response['data'];
      setState(() {
        _listDamage = data;
        _totalDamage = data.length;
      });

      for (var route in data) {
        final locationA = _parseLatLng(route['locationA']);
        final locationB = _parseLatLng(route['locationB']);

        await _drawRouteDamageFormap(
          route['name'],
          route['sourceName'],
          route['destinationName'],
          locationA,
          locationB,
          route['createdAt'],
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch damage list')),
      );
    }
  }

  Future<void> _loadCustomIcons() async {
    final Uint8List location =
        await getBytesFromAsset('assets/images/car.png', 100);
    // final Uint8List smallHole =
    //     await getBytesFromAsset('assets/images/small_hole.png', 50);
    final Uint8List largeHole =
        await getBytesFromAsset('assets/images/large_hole.png', 70);
    // final Uint8List smallCrack =
    //     await getBytesFromAsset('assets/images/small_crack.png', 50);
    final Uint8List largeCrack =
        await getBytesFromAsset('assets/images/large_crack.png', 70);
    final Uint8List maintain =
        await getBytesFromAsset('assets/images/fix_road.png', 70);
    final Uint8List damage =
        await getBytesFromAsset('assets/images/damage.png', 70);

    setState(() {
      _userIcon = BitmapDescriptor.fromBytes(location);
      //_smallHoleIcon = BitmapDescriptor.fromBytes(smallHole);
      _largeHoleIcon = BitmapDescriptor.fromBytes(largeHole);
     // _smallCrackIcon = BitmapDescriptor.fromBytes(smallCrack);
      _largeCrackIcon = BitmapDescriptor.fromBytes(largeCrack);
      _maintainIcon = BitmapDescriptor.fromBytes(maintain);
      _damageIcon = BitmapDescriptor.fromBytes(damage);
    });
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  void reload() {
    _showMyLocation();
    _updateMarkers();
  }

  void _showMyLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 17.0),
    ));
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

  Future<void> _drawRouteMaintainFormap(String sourceName, String destinationName,
      LatLng source, LatLng destination, int date, String startDate, String endDate) async {
    final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&key=$api_key'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = polylinePoints
          .decodePolyline(data['routes'][0]['overview_polyline']['points']);
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
          color: Colors.red,
          points: polylineCoordinates,
          width: 5,
        );
        polylines[id] = polyline;
        if (polylineCoordinates.length > 1) {
          LatLng midPoint =
              polylineCoordinates[(polylineCoordinates.length / 2).round()];
          _markers.add(
            Marker(
              markerId: MarkerId('midpoint_${id.value}'),
              position: midPoint,
              icon: _maintainIcon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MaintainRoadDetailScreen(
                      sourceName: sourceName,
                      destinationName: destinationName,
                      locationA: source,
                      locationB: destination,
                      dateMaintain: date,
                      startDate: startDate,
                      endDate: endDate,
                    ),
                  ),
                );
              },
              infoWindow:
                  InfoWindow(title: 'Number of maintenance days: $date'),
            ),
          );
        }
      });
    } else {
      throw Exception('Failed to load directions');
    }
  }

  Future<void> _drawRouteDamageFormap(
      String name,
      String sourceName,
      String destinationName,
      LatLng source,
      LatLng destination,
      dateDamage) async {
    final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&key=$api_key'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = polylinePoints
          .decodePolyline(data['routes'][0]['overview_polyline']['points']);
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
          color: Colors.red,
          points: polylineCoordinates,
          width: 5,
        );
        polylines[id] = polyline;
        if (polylineCoordinates.length > 1) {
          LatLng midPoint =
              polylineCoordinates[(polylineCoordinates.length / 2).round()];
          _markers.add(
            Marker(
              markerId: MarkerId('midpoint_${id.value}'),
              position: midPoint,
              icon: _damageIcon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DamageRoadDetailScreen(
                      name: name,
                      sourceName: sourceName,
                      destinationName: destinationName,
                      locationA: source,
                      locationB: destination,
                      dateDamage: dateDamage,
                    ),
                  ),
                );
              },
              infoWindow:
                  InfoWindow(title: name, snippet: 'Click for details'),
            ),
          );
        }
      });
    } else {
      throw Exception('Failed to load directions');
    }
  }

  LatLng _parseLatLng(String latLngString) {
    final parts =
        latLngString.replaceAll('LatLng(', '').replaceAll(')', '').split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }

  Future<void> _getUserLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    _kGooglePlex = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 14.4746);
    _addMarker(position);
  }

  LatLng? _parseLocationForMaintain(String location) {
    try {
      String cleanedLocation =
          location.replaceAll('LatLng(', '').replaceAll(')', '');

      List<String> latLngList = cleanedLocation.split(',');

      double latitude = double.parse(latLngList[0].trim());
      double longitude = double.parse(latLngList[1].trim());

      return LatLng(latitude, longitude);
    } catch (e) {
      print("Error parsing location: $e");
      return null;
    }
  }

  void _goToMarkerDuringParking(
      String location, String type, String description) async {
    print(type);
    var coordinates;
    if (type == 'Maintain' || type == 'Damage') {
      coordinates = _parseLocationForMaintain(location);
    } else {
      coordinates = _parseLocation(location);
    }
    if (coordinates != null) {
      setState(() {
        polylines.clear();
        _markers.clear();
        _markers.add(
          Marker(
            markerId: MarkerId('Detection'),
            position: coordinates,
            infoWindow: InfoWindow(
              title: '$type',
              snippet: '$description',
            ),
          ),
        );
      });

      final GoogleMapController controller = await _controller.future;
      await controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(coordinates.latitude, coordinates.longitude),
          zoom: 19.0,
        ),
      ));
    } else {
      print("Invalid location string format");
    }
  }

  void _goToMarkerDuringParkingForDamage(
      String location, String name, String description) async {
    var coordinates;
    coordinates = _parseLocationForMaintain(location);
    if (coordinates != null) {
      setState(() {
        polylines.clear();
        _markers.clear();
        _markers.add(
          Marker(
            markerId: MarkerId('Detection'),
            position: coordinates,
            infoWindow: InfoWindow(
              title: '$name',
              snippet: '$description',
            ),
          ),
        );
      });

      final GoogleMapController controller = await _controller.future;
      await controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(coordinates.latitude, coordinates.longitude),
          zoom: 19.0,
        ),
      ));
    } else {
      print("Invalid location string format");
    }
  }

  void _showHoleDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Container(
              height: 70.0,
              child: DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.blue,
                ),
                child: Text(
                  'Danh sách các ổ gà: $_totalHole',
                  style: GoogleFonts.beVietnamPro(
                    textStyle: const TextStyle(
                      fontSize: 23,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            ...?_listHole
                ?.map((item) => ListTile(
                      title: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.blueAccent,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              item['address'],
                              style: GoogleFonts.beVietnamPro(
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['description'],
                                  style: GoogleFonts.beVietnamPro(
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        _showDeleteConfirmationDialog(
                                            item['_id'], 'Hole');
                                      },
                                      icon:
                                          Icon(Icons.delete, color: Colors.red),
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditScreen(
                                              item: item,
                                              type: 'hole',
                                              onUpdate: (){
                                                Navigator.of(context).pop();
                                                _updateMarkers();
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    IconButton(
                                        onPressed: () {
                                          _getDetailHole(item['_id']);
                                        },
                                        icon: Icon(Icons.library_add_sharp)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _goToMarkerDuringParking(
                            item['location'], 'Hole', item['description']);
                      },
                    ))
                .toList(),
          ],
        );
      },
    );
  }

  void _showCrackDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Container(
              height: 70.0,
              child: DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.blue,
                ),
                child: Text(
                  'Danh sách các vết nứt: $_totalCrack',
                  style: GoogleFonts.beVietnamPro(
                    textStyle: const TextStyle(
                      fontSize: 23,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            ...?_listCrack
                ?.map((item) => ListTile(
                      title: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.blueAccent,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              item['address'],
                              style: GoogleFonts.beVietnamPro(
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['description'],
                                  style: GoogleFonts.beVietnamPro(
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        _showDeleteConfirmationDialog(
                                            item['_id'], 'Crack');
                                      },
                                      icon:
                                          Icon(Icons.delete, color: Colors.red),
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditScreen(
                                              item: item,
                                              type: 'crack',
                                              onUpdate: (){
                                                Navigator.of(context).pop();
                                                _updateMarkers();
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    IconButton(
                                        onPressed: () {
                                          _getDetailCrack(item['_id']);
                                        },
                                        icon: Icon(Icons.library_add_sharp)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _goToMarkerDuringParking(
                            item['location'], 'Crack', item['description']);
                      },
                    ))
                .toList(),
          ],
        );
      },
    );
  }

  void _showMaintainDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Container(
              height: 70.0,
              child: DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.blue,
                ),
                child: Text(
                  'Danh sách bảo trì: $_totalMaintain',
                  style: GoogleFonts.beVietnamPro(
                    textStyle: const TextStyle(
                      fontSize: 23,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            ...?_listMaintain
                ?.map((item) => ListTile(
                      title: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.blueAccent,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              item['sourceName'],
                              style: GoogleFonts.beVietnamPro(
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Date: ${item['dateMaintain']}',
                                  style: GoogleFonts.beVietnamPro(
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        _showDeleteConfirmationDialog(
                                            item['_id'], 'Maintain');
                                      },
                                      icon:
                                          Icon(Icons.delete, color: Colors.red),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditScreen(
                                              item: item,
                                              type: 'maintain',
                                              onUpdate: (){
                                                Navigator.of(context).pop();
                                                _updateMarkers();
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  MaintainRoadDetailScreen(
                                                sourceName: item['sourceName'],
                                                destinationName:
                                                    item['destinationName'],
                                                locationA: _parseLatLng(
                                                    item['locationA']),
                                                locationB: _parseLatLng(
                                                    item['locationB']),
                                                dateMaintain:
                                                    item['dateMaintain'],
                                                    startDate: item['startDate'],
                                                    endDate: item['endDate'],
                                              ),
                                            ),
                                          );
                                        },
                                        icon: Icon(Icons.library_add_sharp)),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  '${DateFormat('yyyy/MM/dd ').format(DateTime.parse(item['startDate']))} - ${DateFormat('yyyy/MM/dd ').format(DateTime.parse(item['endDate']))}',
                                  style: GoogleFonts.beVietnamPro(
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        print(item['locationA']);
                        Navigator.of(context).pop();
                        _goToMarkerDuringParking(item['locationA'], 'Maintain',
                            'Date: ${item['dateMaintain']}');
                      },
                    ))
                .toList(),
          ],
        );
      },
    );
  }

  void _showDamageDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Container(
              height: 70.0,
              child: DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.blue,
                ),
                child: Text(
                  'Danh sách sự cố đường: $_totalDamage',
                  style: GoogleFonts.beVietnamPro(
                    textStyle: const TextStyle(
                      fontSize: 23,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            ...?_listDamage
                ?.map((item) => ListTile(
              title: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.blueAccent,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: GoogleFonts.beVietnamPro(
                        textStyle: const TextStyle(
                          fontSize: 13,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      item['sourceName'],
                      style: GoogleFonts.beVietnamPro(
                        textStyle: const TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Row(
                      children: [],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Created: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(item['createdAt']))}',
                          style: GoogleFonts.beVietnamPro(
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                _showDeleteConfirmationDialog(
                                    item['_id'], 'Damage');
                              },
                              icon:
                              Icon(Icons.delete, color: Colors.red),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditScreen(
                                      item: item,
                                      type: 'damage',
                                      onUpdate: (){
                                        Navigator.of(context).pop();
                                        _updateMarkers();
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DamageRoadDetailScreen(
                                            name: item['name'],
                                            sourceName: item['sourceName'],
                                            destinationName:
                                            item['destinationName'],
                                            locationA: _parseLatLng(
                                                item['locationA']),
                                            locationB: _parseLatLng(
                                                item['locationB']),
                                            dateDamage: item['createdAt'],
                                          ),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.library_add_sharp)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              onTap: () {
                print(item['locationA']);
                Navigator.of(context).pop();
                _goToMarkerDuringParkingForDamage(item['locationA'], item['name'],
                    'Date Created: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(item['createdAt']))}');
              },
            ))
                .toList(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: <Widget>[
          Positioned(
            bottom: 310.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'Reload Data Management',
              mini: true,
              shape: const CircleBorder(),
              backgroundColor: Color(0xFFFFFFFF),
              onPressed: _updateMarkers,
              tooltip: 'Reload Data',
              child: Icon(Icons.refresh),
            ),
          ),
          Positioned(
            bottom: 265.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'List Damage Management',
              mini: true,
              shape: const CircleBorder(),
              backgroundColor: Color(0xFFFFFFFF),
              onPressed: () {
                _showDamageDrawer(context);
              },
              tooltip: 'List Damage',
              child: Image.asset('assets/images/damage.png',
                  width: 30, height: 30),
            ),
          ),
          Positioned(
            bottom: 220.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'List Maintain Management',
              mini: true,
              shape: const CircleBorder(),
              backgroundColor: Color(0xFFFFFFFF),
              onPressed: () {
                _showMaintainDrawer(context);
              },
              tooltip: 'List Maintain',
              child: Image.asset('assets/images/fix_road.png',
                  width: 30, height: 30),
            ),
          ),
          Positioned(
            bottom: 175.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'List Crack Management',
              mini: true,
              shape: const CircleBorder(),
              backgroundColor: Color(0xFFFFFFFF),
              onPressed: () {
                _showCrackDrawer(context);
              },
              tooltip: 'List Crack',
              child: Image.asset('assets/images/large_crack.png',
                  width: 30, height: 30),
            ),
          ),
          Positioned(
            bottom: 130.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'List Hole Management',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: () {
                _showHoleDrawer(context);
              },
              tooltip: 'List Hole',
              child: Image.asset('assets/images/large_hole.png',
                  width: 30, height: 30),
            ),
          ),
          Positioned(
            bottom: 85.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'Show My Location Management',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: reload,
              tooltip: 'Show My Location',
              child:
                  Image.asset('assets/images/car.png', width: 30, height: 30),
            ),
          ),
          Positioned(
              bottom: 10.0,
              left: 25,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white70,
                  border: Border.all(color: Colors.blueAccent),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Damage',
                          style: GoogleFonts.beVietnamPro(
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Image.asset('assets/images/damage.png',
                            width: 40, height: 40)
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Maintain',
                          style: GoogleFonts.beVietnamPro(
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Image.asset('assets/images/fix_road.png',
                            width: 40, height: 40)
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Hole',
                          style: GoogleFonts.beVietnamPro(
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Image.asset('assets/images/large_hole.png',
                            width: 45, height: 45)
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Crack',
                          style: GoogleFonts.beVietnamPro(
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Image.asset('assets/images/large_crack.png',
                            width: 40, height: 40)
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
