import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../model/detection.dart';


class DetectionForDetailScreen extends StatefulWidget {
  final Detection? detection;
  final String imageData;
  const DetectionForDetailScreen({Key? key, required this.detection, required this.imageData}) : super(key: key);

  @override
  _DetectionForDetailScreenState createState() => _DetectionForDetailScreenState();
}

class _DetectionForDetailScreenState extends State<DetectionForDetailScreen> {
  late GoogleMapController _mapController;
  late LatLng _initialPosition;

  @override
  void initState() {
    super.initState();
    _initialPosition = _parseLatLng(widget.detection?.location);
  }

  LatLng _parseLatLng(String? location) {
    final regex = RegExp(r'LatLng\(latitude:(.*), longitude:(.*)\)');
    final match = regex.firstMatch(location!);
    if (match != null) {
      final latitude = double.parse(match.group(1)!);
      final longitude = double.parse(match.group(2)!);
      return LatLng(latitude, longitude);
    }
    throw Exception('Invalid location format');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection Detail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Name: ${widget.detection?.name}'),
              Text('Id User Send: ${widget.detection?.user}'),
              Text('Location: ${widget.detection?.location}'),
              Text('Address Detection: ${widget.detection?.address}'),
              Text('Description: ${widget.detection?.description}'),
              const SizedBox(height: 16),
              const Text('Image:'),
              const SizedBox(height: 8),
              Image.network(widget.imageData),
              const SizedBox(height: 16),
              Text('Created At: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(widget.detection!.createdAt))}'),
              const SizedBox(height: 16),
              const Text('Location on Map:'),
              const SizedBox(height: 8),
              Container(
                height: 300,
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition,
                    zoom: 18.0,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId('detectionLocation'),
                      position: _initialPosition,
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
