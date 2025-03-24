import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'package:pothole/screens/send.dart';
import '../services/detection_service.dart';

class MapUserScreen extends StatefulWidget {
  const MapUserScreen({Key? key}) : super(key: key);

  @override
  State<MapUserScreen> createState() => MapUserScreenState();
}

class MapUserScreenState extends State<MapUserScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  PolylinePoints polylinePoints = PolylinePoints();
  Map<PolylineId, Polyline> polylines = {};
  late StreamSubscription<Position> _positionStreamSubscription;

  Set<Marker> _markers = {};
  late BitmapDescriptor _userIcon;
  late BitmapDescriptor _holeIcon;
  late BitmapDescriptor _crackIcon;
  late BitmapDescriptor _maintainIcon;

  List<dynamic> holes = [];
  List<dynamic> cracks = [];

  bool _iconsLoaded = false;
  Position? _currentPosition;

  static CameraPosition _kGooglePlex = const CameraPosition(target: LatLng(0, 0), zoom: 14.4746);

  @override
  void initState() {
    super.initState();
    _loadCustomIcons().then((_) {
      _iconsLoaded = true;
      _getUserLocation();
      _getCurrentLocation();
      _showMyLocation();
      fetchData();
      _startListeningToLocationChanges();
      _fetchAndDrawRoutes();
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription.cancel();
    super.dispose();
  }

  void _startListeningToLocationChanges() {
    const LocationSettings locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20);
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((position) {
      setState(() {
        _currentPosition = position;
        _updateMarkerPosition(position);
      });
      _moveCameraToUserLocation(position);
    });
  }

  Future<void> _loadCustomIcons() async {
    final user = await getBytesFromAsset('assets/images/car.png', 100);
    final hole = await getBytesFromAsset('assets/images/large_hole.png', 70);
    final crack = await getBytesFromAsset('assets/images/large_crack.png', 70);
    final maintain = await getBytesFromAsset('assets/images/fix_road.png', 70);

    setState(() {
      _userIcon = BitmapDescriptor.fromBytes(user);
      _holeIcon = BitmapDescriptor.fromBytes(hole);
      _crackIcon = BitmapDescriptor.fromBytes(crack);
      _maintainIcon = BitmapDescriptor.fromBytes(maintain);
    });
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  void _showMyLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _updateMarkerPosition(position);
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 17.0)));
  }

  Future<void> _getUserLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _currentPosition = position;
    _kGooglePlex = CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 14.4746);
    _updateMarkerPosition(position);
  }

  void _moveCameraToUserLocation(Position position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)));
  }

  void _updateMarkerPosition(Position position) {
    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _markers.removeWhere((marker) => marker.markerId.value == 'myLocation');
      _markers.add(
        Marker(
          markerId: MarkerId('myLocation'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: InfoWindow(title: 'Your Location', snippet: 'This is where you are.'),
          icon: _userIcon,
        ),
      );
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        await openAppSettings();
        return;
      }
    }
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> fetchData() async {
    final response = await DetectionCoordinateService.getDetectionCoordinates();
    if (!mounted) return;

    if (response['status'] == 'OK') {
      setState(() {
        holes = [...response['latLongSmallHole'], ...response['latLongLargeHole']];
        cracks = [...response['latLongSmallCrack'], ...response['latLongLargeCrack']];
      });
      if (_iconsLoaded) {
        polylines.clear();
        _fetchAndDrawRoutes();
        _updateMarkers();
      }
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();

      for (int i = 0; i < holes.length; i++) {
        _markers.add(Marker(
          markerId: MarkerId('hole$i'),
          position: LatLng(holes[i][0], holes[i][1]),
          infoWindow: InfoWindow(title: 'Hole'),
          icon: _holeIcon,
        ));
      }

      for (int i = 0; i < cracks.length; i++) {
        _markers.add(Marker(
          markerId: MarkerId('crack$i'),
          position: LatLng(cracks[i][0], cracks[i][1]),
          infoWindow: InfoWindow(title: 'Crack'),
          icon: _crackIcon,
        ));
      }

      if (_iconsLoaded && _currentPosition != null) {
        _markers.add(Marker(
          markerId: MarkerId('myLocation'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: InfoWindow(title: 'Your Location'),
          icon: _userIcon,
        ));
      }
    });
  }

  Future<void> _drawRouteForMap(LatLng source, LatLng destination, int date, String createdAt, String updatedAt) async {
    final response = await http.get(Uri.parse('https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&key=$api_key'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = polylinePoints.decodePolyline(data['routes'][0]['overview_polyline']['points']);
      List<LatLng> polylineCoordinates = points.map((p) => LatLng(p.latitude, p.longitude)).toList();

      if (!mounted) return;

      setState(() {
        final id = PolylineId(source.toString() + '_' + destination.toString());
        polylines[id] = Polyline(
          polylineId: id,
          color: Colors.red,
          points: polylineCoordinates,
          width: 5,
        );

        if (polylineCoordinates.length > 1) {
          LatLng midPoint = polylineCoordinates[(polylineCoordinates.length / 2).round()];
          _markers.add(Marker(
            markerId: MarkerId('midpoint_${id.value}'),
            position: midPoint,
            icon: _maintainIcon,
            infoWindow: InfoWindow(
              title: 'Date maintain: ${date}d',
              snippet: '$createdAt - $updatedAt',
            ),
          ));
        }
      });
    }
  }

  Future<void> _fetchAndDrawRoutes() async {
    final response = await getListMaintainService.getListMaintain();
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
    }
  }

  LatLng _parseLatLng(String latLngString) {
    final parts = latLngString.replaceAll('LatLng(', '').replaceAll(')', '').split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
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
              fetchData();
            },
            markers: _markers,
            polylines: Set<Polyline>.of(polylines.values),
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 130.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'sendBtn',
              backgroundColor: Colors.white,
              mini: true,
              shape: const CircleBorder(),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SendScreen()));
              },
              child: Icon(Icons.add_alert),
            ),
          ),
          Positioned(
            bottom: 85.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'locationBtn',
              backgroundColor: Colors.white,
              mini: true,
              shape: const CircleBorder(),
              onPressed: _showMyLocation,
              child: Image.asset('assets/images/car.png', width: 30, height: 30),
            ),
          ),
          Positioned(
            bottom: 175.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'reloadBtn',
              backgroundColor: Colors.white,
              mini: true,
              shape: const CircleBorder(),
              onPressed: fetchData,
              child: Icon(Icons.refresh),
            ),
          ),
          Positioned(
            bottom: 10.0,
            left: 25,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white70,
                border: Border.all(color: Colors.blueAccent),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      Text(
                        'Maintain',
                        style: GoogleFonts.beVietnamPro(
                          textStyle: const TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      //const SizedBox(width: 10),
                      Image.asset('assets/images/fix_road.png', width: 40, height: 40)
                    ],
                  ),
                  // Row(
                  //   children: [
                  //     Text(
                  //       'Small Hole',
                  //       style: GoogleFonts.beVietnamPro(
                  //         textStyle: const TextStyle(
                  //           fontSize: 15,
                  //           color: Colors.black,
                  //         ),
                  //       ),
                  //     ),
                  //     const SizedBox(width: 10),
                  //     Image.asset('assets/images/small_hole.png', width: 40, height: 40)
                  //   ],
                  // ),
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
                      Image.asset('assets/images/large_hole.png', width: 45, height: 45)
                    ],
                  ),
                  // const SizedBox(height: 10),
                  // Row(
                  //   children: [
                  //     Text(
                  //       'Small Crack',
                  //       style: GoogleFonts.beVietnamPro(
                  //         textStyle: const TextStyle(
                  //           fontSize: 15,
                  //           color: Colors.black,
                  //         ),
                  //       ),
                  //     ),
                  //     const SizedBox(width: 5),
                  //     Image.asset('assets/images/small_crack.png', width: 40, height: 40)
                  //   ],
                  // ),
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
                      Image.asset('assets/images/large_crack.png', width: 40, height: 40)
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
