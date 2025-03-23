import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'package:pothole/screens/send.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

class MapUserScreen extends StatefulWidget {
  const MapUserScreen({Key? key}) : super(key: key);

  @override
  State<MapUserScreen> createState() => MapUserScreenState();
}

class MapUserScreenState extends State<MapUserScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  Set<Marker> _markers = {};
  late BitmapDescriptor _userIcon;
  late BitmapDescriptor _smallHoleIcon;
  late BitmapDescriptor _largeHoleIcon;
  late BitmapDescriptor _smallCrackIcon;
  late BitmapDescriptor _largeCrackIcon;

  List<dynamic> smallHoles = [];
  List<dynamic> largeHoles = [];
  List<dynamic> smallCracks = [];
  List<dynamic> largeCracks = [];

  bool _iconsLoaded = false;
  Position? _currentPosition; // Change to nullable type

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
      _getCurrentLocation();
      _showMyLocation();
    });
  }

  Future<void> _loadCustomIcons() async {
    final Uint8List location = await getBytesFromAsset('assets/images/car.png', 160);
    final Uint8List smallHole = await getBytesFromAsset('assets/images/small_hole.png', 100);
    final Uint8List largeHole = await getBytesFromAsset('assets/images/large_hole.png', 120);
    final Uint8List smallCrack = await getBytesFromAsset('assets/images/small_crack.png', 100);
    final Uint8List largeCrack = await getBytesFromAsset('assets/images/large_crack.png', 120);

    setState(() {
      _userIcon = BitmapDescriptor.fromBytes(location);
      _smallHoleIcon = BitmapDescriptor.fromBytes(smallHole);
      _largeHoleIcon = BitmapDescriptor.fromBytes(largeHole);
      _smallCrackIcon = BitmapDescriptor.fromBytes(smallCrack);
      _largeCrackIcon = BitmapDescriptor.fromBytes(largeCrack);
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
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 17.0),
    ));
  }

  Future<void> fetchData() async {
    var url = Uri.parse('$ip/detection/get-detection');
    var response = await http.get(url);
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      setState(() {
        smallHoles = jsonResponse['latLongSmallHole'];
        largeHoles = jsonResponse['latLongLargeHole'];
        smallCracks = jsonResponse['latLongSmallCrack'];
        largeCracks = jsonResponse['latLongLargeCrack'];
      });
      if (_iconsLoaded) {
        _updateMarkers();
      }
    } else {
      throw Exception('Failed to load data');
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      int smallHoleIndex = 0;
      for (var item in smallHoles) {
        _markers.add(
          Marker(
            markerId: MarkerId('smallHole$smallHoleIndex'),
            position: LatLng(item[0], item[1]),
            infoWindow: InfoWindow(title: 'Hole', snippet: 'Small Hole'),
            icon: _smallHoleIcon,
          ),
        );
        smallHoleIndex++;
      }

      int largeHoleIndex = 0;
      for (var item in largeHoles) {
        _markers.add(
          Marker(
            markerId: MarkerId('largeHole$largeHoleIndex'),
            position: LatLng(item[0], item[1]),
            infoWindow: InfoWindow(title: 'Hole', snippet: 'Large Hole'),
            icon: _largeHoleIcon,
          ),
        );
        largeHoleIndex++;
      }

      int smallCrackIndex = 0;
      for (var item in smallCracks) {
        _markers.add(
          Marker(
            markerId: MarkerId('smallCrack$smallCrackIndex'),
            position: LatLng(item[0], item[1]),
            infoWindow: InfoWindow(title: 'Crack', snippet: 'Small Crack'),
            icon: _smallCrackIcon,
          ),
        );
        smallCrackIndex++;
      }

      int largeCrackIndex = 0;
      for (var item in largeCracks) {
        _markers.add(
          Marker(
            markerId: MarkerId('largeCrack$largeCrackIndex'),
            position: LatLng(item[0], item[1]),
            infoWindow: InfoWindow(title: 'Crack', snippet: 'Large Crack'),
            icon: _largeCrackIcon,
          ),
        );
        largeCrackIndex++;
      }

      if (_iconsLoaded && _currentPosition != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('myLocation'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: InfoWindow(title: 'Your Location', snippet: 'This is where you are.'),
            icon: _userIcon,
          ),
        );
      }
    });
  }

  void _getCurrentLocation() async {
    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    await Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      print(position);
      _currentPosition = position;
      _updateMarkerPosition(position);
    });
  }


  Future<void> _getUserLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _currentPosition = position;
    _kGooglePlex = CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 14.4746);
    _updateMarkerPosition(position);
  }

  void _updateMarkerPosition(Position position) {
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
          GoogleMap(
            mapType: MapType.terrain,
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              _reloadData();
            },
            markers: _markers,
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: <Widget>[
          Positioned(
            bottom: 130.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'uniqueTag1',
              backgroundColor: Color(0xC0E6F8FF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SendScreen()),
                );
              },
              tooltip: 'Button 1',
              child: Icon(Icons.add_alert),
            ),
          ),
          Positioned(
            bottom: 85.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'uniqueTag2',
              backgroundColor: Color(0xC0E6F8FF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _showMyLocation,
              tooltip: 'Show My Location',
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 175.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'uniqueTag3',
              mini: true,
              shape: const CircleBorder(),
              backgroundColor: Color(0xC0E6F8FF),
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
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Small Hole',
                          style: GoogleFonts.roboto(
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Image.asset('assets/images/small_hole.png', width: 40, height: 40)
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Large Hole',
                          style: GoogleFonts.roboto(
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Small Crack',
                          style: GoogleFonts.roboto(
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Image.asset('assets/images/small_crack.png', width: 40, height: 40)
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Large Crack',
                          style: GoogleFonts.roboto(
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
              )),
        ],
      ),
    );
  }
}
