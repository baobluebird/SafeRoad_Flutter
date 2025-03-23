import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../model/detection.dart';
import '../page/home_admin.dart';
import '../page/home_user.dart';

class DetectionScreen extends StatefulWidget {
  final Detection? detection;
  final String imageData;

  const DetectionScreen(
      {Key? key, required this.detection, required this.imageData})
      : super(key: key);

  @override
  _DetectionScreenState createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  final myBox = Hive.box('myBox');

  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = myBox.get('isAdmin');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_isAdmin == false) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => UserHome(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AdminHome(),
              ),
            );
          }
        },
        child: Icon(Icons.arrow_back),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 16),
              Text(
                'Detection Information',
                textAlign: TextAlign.center,
                style: GoogleFonts.rubik(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Thanks for your report!'),
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
              Text(
                  'Created At: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(widget.detection!.createdAt))}'),
            ],
          ),
        ),
      ),
    );
  }
}
