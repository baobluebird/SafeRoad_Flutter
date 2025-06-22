import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'package:pothole/screens/detection/send_detection.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/detection_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  PolylinePoints polylinePoints = PolylinePoints();
  Map<PolylineId, Polyline> polylines = {};
  late StreamSubscription<Position> _positionStreamSubscription;

  Set<Marker> _markers = {};
  late BitmapDescriptor _userIcon;
  late BitmapDescriptor _largeHoleIcon;
  late BitmapDescriptor _largeCrackIcon;
  late BitmapDescriptor _maintainIcon;
  late BitmapDescriptor _damageIcon;

  List<dynamic> holes = [];
  List<dynamic> cracks = [];

  bool _iconsLoaded = false;
  bool _permissionGranted = false;
  Position? _currentPosition;

  static CameraPosition _kGooglePlex = const CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _checkAndRequestLocationPermission();
  }

  @override
  void dispose() {
    _stopListeningLocation();
    super.dispose();
  }

  void _stopListeningLocation() {
    if (_permissionGranted) {
      _positionStreamSubscription.cancel();
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Kiểm tra dịch vụ vị trí
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }

    // Kiểm tra quyền vị trí
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDeniedForeverDialog();
      return;
    }

    // Quyền đã được cấp
    setState(() {
      _permissionGranted = true;
    });

    // Khởi tạo các chức năng bản đồ
    await _loadCustomIcons();
    setState(() {
      _iconsLoaded = true;
    });
    _getUserLocation();
    _getCurrentLocation();
    _showMyLocation();
    fetchData();
    _startListeningToLocationChanges();
    _fetchAndDrawRoutes();
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dịch vụ vị trí bị tắt'),
        content: Text('Vui lòng bật dịch vụ vị trí để sử dụng bản đồ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              await Geolocator.openLocationSettings();
              Navigator.pop(context);
              _checkAndRequestLocationPermission();
            },
            child: Text('Mở cài đặt'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quyền vị trí bị từ chối'),
        content: Text('Ứng dụng cần quyền vị trí để hiển thị bản đồ. Vui lòng cấp quyền.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkAndRequestLocationPermission();
            },
            child: Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quyền vị trí bị từ chối vĩnh viễn'),
        content: Text('Vui lòng vào cài đặt ứng dụng để cấp quyền vị trí.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              Navigator.pop(context);
              _checkAndRequestLocationPermission();
            },
            child: Text('Mở cài đặt'),
          ),
        ],
      ),
    );
  }

  void _moveCameraToUserLocation(Position position) async {
    if (!mounted) return;

    final GoogleMapController? controller = await _controller.future;
    if (controller != null) {
      try {
        controller.animateCamera(CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ));
      } catch (e) {
        print("Lỗi animateCamera: $e");
      }
    }
  }

  void _startListeningToLocationChanges() {
    if (!_permissionGranted) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
          setState(() {
            _currentPosition = position;
            _updateMarkerPosition(position);
          });

          _moveCameraToUserLocation(position);
        });
  }

  Future<void> _loadCustomIcons() async {
    try {
      final Uint8List location = await getBytesFromAsset('assets/images/car.png', 100);
      final Uint8List largeHole = await getBytesFromAsset('assets/images/large_hole.png', 70);
      final Uint8List largeCrack = await getBytesFromAsset('assets/images/large_crack.png', 70);
      final Uint8List maintain = await getBytesFromAsset('assets/images/fix_road.png', 70);
      final Uint8List damage = await getBytesFromAsset('assets/images/damage.png', 70);

      setState(() {
        _userIcon = BitmapDescriptor.fromBytes(location);
        _largeHoleIcon = BitmapDescriptor.fromBytes(largeHole);
        _largeCrackIcon = BitmapDescriptor.fromBytes(largeCrack);
        _maintainIcon = BitmapDescriptor.fromBytes(maintain);
        _damageIcon = BitmapDescriptor.fromBytes(damage);
      });
    } catch (e) {
      print('Lỗi khi tải icon: $e');
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    try {
      ByteData data = await rootBundle.load(path);
      ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(), targetWidth: width);
      ui.FrameInfo fi = await codec.getNextFrame();
      return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    } catch (e) {
      print("Lỗi khi tải icon từ $path: $e");
      throw Exception("Không thể tải icon từ $path");
    }
  }

  void _showMyLocation() async {
    if (!_permissionGranted) {
      _checkAndRequestLocationPermission();
      return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _updateMarkerPosition(position);
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 17.0),
    ));
  }

  Future<void> fetchData() async {
    if (!_permissionGranted) return;

    final response = await DetectionCoordinateService.getDetectionCoordinates();

    if (!mounted) return;
    print('reload data: $response');
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Error loading data')),
      );
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();

      int holeIndex = 0;
      for (var item in holes) {
        _markers.add(
          Marker(
            markerId: MarkerId('hole$holeIndex'),
            position: LatLng(item[0], item[1]),
            infoWindow: InfoWindow(title: 'Hole'),
            icon: _largeHoleIcon,
          ),
        );
        holeIndex++;
      }

      int crackIndex = 0;
      for (var item in cracks) {
        _markers.add(
          Marker(
            markerId: MarkerId('crack$crackIndex'),
            position: LatLng(item[0], item[1]),
            infoWindow: InfoWindow(title: 'Crack'),
            icon: _largeCrackIcon,
          ),
        );
        crackIndex++;
      }

      if (_iconsLoaded && _currentPosition != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('myLocation'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: InfoWindow(title: 'Your Location'),
            icon: _userIcon,
          ),
        );
      }
    });
  }

  Future<void> _drawRouteMaintainForMap(LatLng source, LatLng destination, int date, String createdAt, String updatedAt) async {
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

      if (!mounted) return;

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load directions'))
      );
    }
  }

  Future<void> _drawRouteDamageForMap(String name, LatLng source, LatLng destination, String createdAt, String updatedAt) async {
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

      if (!mounted) return;

      setState(() {
        final id = PolylineId(source.toString() + '_' + destination.toString());
        Polyline polyline = Polyline(
          polylineId: id,
          color: Colors.blueAccent,
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
              icon: _damageIcon,
              infoWindow: InfoWindow(
                title: name,
                snippet: 'Warning',
              ),
            ),
          );
        }
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load directions'))
      );
    }
  }

  Future<void> _fetchAndDrawRoutes() async {
    if (!_permissionGranted) return;

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
        await _drawRouteMaintainForMap(locationA, locationB, date, createdAt, updatedAt);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to fetch routes')),
      );
    }

    final responseDamage = await getListDamageForMapService.getListDamageForMap();

    if (responseDamage['status'] == 'OK') {
      final data = responseDamage['data'];
      for (var route in data) {
        final name = route['name'];
        final locationA = _parseLatLng(route['locationA']);
        final locationB = _parseLatLng(route['locationB']);
        final createdAt = route['createdAt'];
        final updatedAt = route['updatedAt'];
        await _drawRouteDamageForMap(name, locationA, locationB, createdAt, updatedAt);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(responseDamage['message'] ?? 'Failed to fetch routes')),
      );
    }
  }

  LatLng _parseLatLng(String latLngString) {
    final parts =
    latLngString.replaceAll('LatLng(', '').replaceAll(')', '').split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }

  Future<void> _getCurrentLocation() async {
    if (!_permissionGranted) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    print('Vị trí hiện tại: ${position.latitude}, ${position.longitude}');
  }

  Future<void> _getUserLocation() async {
    if (!_permissionGranted) return;

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _currentPosition = position;
    _kGooglePlex = CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 14.4746);
    _updateMarkerPosition(position);
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

  void _reloadData() {
    fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _permissionGranted
              ? GoogleMap(
            mapType: MapType.terrain,
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              _reloadData();
            },
            markers: _markers,
            polylines: Set<Polyline>.of(polylines.values),
          )
              : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Yêu cầu quyền vị trí để sử dụng bản đồ.'),
                ElevatedButton(
                  onPressed: _checkAndRequestLocationPermission,
                  child: Text('Cấp quyền vị trí'),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _permissionGranted
          ? Stack(
        children: <Widget>[
          Positioned(
            bottom: 130.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'Send Report Map',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SendScreen()),
                );
              },
              tooltip: 'Send Report',
              child: Icon(Icons.add_alert),
            ),
          ),
          Positioned(
            bottom: 85.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'Show My Location Map',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _showMyLocation,
              tooltip: 'Show My Location',
              child: Image.asset('assets/images/car.png',
                  width: 30, height: 30),
            ),
          ),
          Positioned(
            bottom: 175.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'Reload Data Map',
              mini: true,
              shape: const CircleBorder(),
              backgroundColor: Color(0xFFFFFFFF),
              onPressed: _reloadData,
              tooltip: 'Reload Data',
              child: Icon(Icons.refresh),
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
                      const SizedBox(width: 10),
                      Text(
                        'Damage',
                        style: GoogleFonts.beVietnamPro(
                          textStyle: const TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Image.asset('assets/images/damage.png', width: 40, height: 40),
                    ],
                  ),
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
                      const SizedBox(width: 10),
                      Image.asset('assets/images/fix_road.png', width: 40, height: 40),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 10),
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
                      Image.asset('assets/images/large_hole.png', width: 45, height: 45),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      Text(
                        'Crack',
                        style: GoogleFonts.beVietnamPro(
                          textStyle: const TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Image.asset('assets/images/large_crack.png', width: 40, height: 40),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      )
          : null,
    );
  }
}