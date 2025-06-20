import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../ipconfig/ip.dart';

class DamageRoadDetailScreen extends StatefulWidget {
  final String name;
  final String sourceName;
  final String destinationName;
  final LatLng locationA;
  final LatLng locationB;
  final String dateDamage;


  DamageRoadDetailScreen({
    required this.name,
    required this.sourceName,
    required this.destinationName,
    required this.locationA,
    required this.locationB,
    required this.dateDamage
  });

  @override
  _DamageRoadDetailScreenState createState() => _DamageRoadDetailScreenState();
}

class _DamageRoadDetailScreenState extends State<DamageRoadDetailScreen> {
  Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();
  List<LatLng> polylineCoordinates = [];

  @override
  void initState() {
    super.initState();
    _setMarkers();
    _drawRoute(widget.locationA, widget.locationB);
  }

  void _setMarkers() {
    setState(() {
      _markers.add(Marker(
        markerId: MarkerId('sourceLocation'),
        position: widget.locationA,
        infoWindow: InfoWindow(title: 'Source Location', snippet: widget.sourceName),
      ));

      _markers.add(Marker(
        markerId: MarkerId('destinationLocation'),
        position: widget.locationB,
        infoWindow: InfoWindow(title: 'Destination Location', snippet: widget.destinationName),
      ));
    });
  }

  void _drawRoute(LatLng source, LatLng destination) async {
    final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&key=$api_key'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = polylinePoints.decodePolyline(data['routes'][0]['overview_polyline']['points']);
      if (points.isNotEmpty) {
        points.forEach((point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });

        setState(() {
          _polylines.add(Polyline(
            polylineId: PolylineId('route'),
            points: polylineCoordinates,
            color: Colors.blueAccent,
            width: 5,
          ));
        });
      }
    } else {
      throw Exception('Failed to load directions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Damage Road Detail'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.locationA,
                zoom: 18,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${widget.name}'),
                Text('Source: ${widget.sourceName}'),
                Text('Destination: ${widget.destinationName}'),
                Text('Date Damage: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(widget.dateDamage))}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
