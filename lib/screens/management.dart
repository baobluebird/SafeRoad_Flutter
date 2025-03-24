import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'package:pothole/screens/road_detail.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../model/detection.dart';
import '../services/detection_service.dart';
import 'detection_for_detail.dart';

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

  late Detection? detection;

  List<dynamic>? _listHole;
  List<dynamic>? _listCrack;
  List<dynamic>? _listMaintain;

  // List<dynamic> smallHoles = [];
  // List<dynamic> largeHoles = [];
  // List<dynamic> smallCracks = [];
  // List<dynamic> largeCracks = [];

  List<dynamic> holes = [];
  List<dynamic> cracks = [];

  int _totalHole = 0;
  int _totalCrack = 0;
  int _totalMaintain = 0;

  bool _iconsLoaded = false;

  static CameraPosition _kGooglePlex = const CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _loadCustomIcons().then((_) {
      _iconsLoaded = true;
      _getUserLocation();
      _getListHoles();
      _getListCracks();
      _getListMaintain();
      _showMyLocation();
    });
    _startLocationUpdates();
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
        } else {
          _listMaintain!.removeWhere((maintain) => maintain['_id'] == detectionId);
          _totalMaintain = _listMaintain!.length;
        }
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$nameList deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _updateMarkers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete $nameList.'),
          backgroundColor: Colors.red,
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

        await _drawRouteFormap(
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

    setState(() {
      _userIcon = BitmapDescriptor.fromBytes(location);
      //_smallHoleIcon = BitmapDescriptor.fromBytes(smallHole);
      _largeHoleIcon = BitmapDescriptor.fromBytes(largeHole);
     // _smallCrackIcon = BitmapDescriptor.fromBytes(smallCrack);
      _largeCrackIcon = BitmapDescriptor.fromBytes(largeCrack);
      _maintainIcon = BitmapDescriptor.fromBytes(maintain);
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

  Future<void> _drawRouteFormap(String sourceName, String destinationName,
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
    var coordinates;
    if (type == 'Maintain') {
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
                  'Danh sách đoạn đường bảo trì: $_totalMaintain',
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
                                    // IconButton(
                                    //   onPressed: () {
                                    //     Navigator.of(context).pop();
                                    //     _drawRoute(_parseLatLng(item['locationA']));
                                    //   },
                                    //   icon:
                                    //   Icon(Icons.location_on, color: Colors.blueAccent),
                                    // ),
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
                                  '${DateFormat('yyyy/MM/dd ').format(DateTime.parse(item['createdAt']))} - ${DateFormat('yyyy/MM/dd ').format(DateTime.parse(item['updatedAt']))}',
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
            bottom: 265.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'uniqueTag5',
              mini: true,
              shape: const CircleBorder(),
              backgroundColor: Color(0xFFFFFFFF),
              onPressed: _updateMarkers,
              tooltip: 'Reload Data',
              child: Icon(Icons.refresh),
            ),
          ),
          Positioned(
            bottom: 220.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'uniqueTag4',
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
              heroTag: 'uniqueTag3',
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
              heroTag: 'uniqueTag2',
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
              heroTag: 'uniqueTag1',
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
