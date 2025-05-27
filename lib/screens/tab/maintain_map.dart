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
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  Set<Marker> _markers = {};
  Map<PolylineId, Polyline> polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  Position? _currentPosition;
  LatLng? _sourcePosition;
  LatLng? _destinationPosition;
  BitmapDescriptor? _maintainIcon;
  BitmapDescriptor? _damageIcon;
  BitmapDescriptor? _userIcon;
  StreamSubscription<Position>? _positionStreamSubscription;

  bool _isSelectingSource = true;
  bool _isSelectingByHand = false;
  String _sourceText = ''; // Lưu trữ văn bản vị trí nguồn
  String _destinationText = ''; // Lưu trữ văn bản vị trí đích

  static CameraPosition _kGooglePlex = const CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _loadCustomIcons().then((_) {
      _checkAndRequestLocationPermission();
      _getUserLocation();
      _fetchAndDrawRoutes();
      _showMyLocation();
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void reload() {
    if (_currentPosition != null) {
      _controller.future.then((controller) {
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 17.0,
            ),
          ),
        );
      });
    } else {
      _getUserLocation();
    }
  }

  void _startLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    Timer? debounceTimer;
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
        if (!mounted) return;
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() {
            _currentPosition = position;
            _updateMarkerPosition(position);
          });

          _controller.future.then((controller) {
            controller.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(position.latitude, position.longitude),
                  zoom: 17.0,
                ),
              ),
            );
          });
        });
      },
      onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi stream vị trí: $e')),
          );
        }
      },
    );
  }

  Future<bool> _checkAndRequestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng bật dịch vụ vị trí')),
      );
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quyền vị trí bị từ chối')),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quyền vị trí bị từ chối vĩnh viễn. Vui lòng cấp quyền trong cài đặt.')),
      );
      return false;
    }

    await _getUserLocation();
    _startLocationStream();
    return true;
  }

  Future<void> _loadCustomIcons() async {
    try {
      final Uint8List location = await getBytesFromAsset('assets/images/car.png', 100);
      final Uint8List maintain = await getBytesFromAsset('assets/images/fix_road.png', 130);
      final Uint8List damage = await getBytesFromAsset('assets/images/damage.png', 130);
      setState(() {
        _userIcon = BitmapDescriptor.fromBytes(location);
        _maintainIcon = BitmapDescriptor.fromBytes(maintain);
        _damageIcon = BitmapDescriptor.fromBytes(damage);
      });
    } catch (e) {
      print('Lỗi tải biểu tượng: $e');
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  void _showMyLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 17.0,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi hiển thị vị trí: $e')),
      );
    }
  }

  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
        _kGooglePlex = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 17.0,
        );
      });

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(_kGooglePlex));

      _addMarker(position);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lấy vị trí: $e')),
      );
    }
  }

  void _addMarker(Position position) {
    setState(() {
      _markers.add(
        Marker(
          icon: _userIcon ?? BitmapDescriptor.defaultMarker,
          markerId: MarkerId('myLocation'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: InfoWindow(
            title: 'Vị trí của bạn',
            snippet: 'Đây là nơi bạn đang ở.',
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
          icon: _userIcon ?? BitmapDescriptor.defaultMarker,
          markerId: MarkerId('myLocation'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: InfoWindow(
            title: 'Vị trí của bạn',
            snippet: 'Đây là nơi bạn đang ở.',
          ),
        ),
      );
    });
  }

  Future<List<String>> _fetchSuggestions(String query) async {
    try {
      final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$api_key'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'];
        return List<String>.from(predictions.map((p) => p['description']));
      } else {
        throw Exception('Không thể tải gợi ý');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải gợi ý: $e')),
      );
      return [];
    }
  }

  Future<void> _searchLocation(String address, bool isSource) async {
    try {
      final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$api_key'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'].isEmpty) {
          throw Exception('Không tìm thấy vị trí');
        }
        final location = data['results'][0]['geometry']['location'];
        final LatLng position = LatLng(location['lat'], location['lng']);

        setState(() {
          if (isSource) {
            _sourcePosition = position;
            _markers.add(
              Marker(
                markerId: MarkerId('sourceLocation'),
                position: position,
                infoWindow: InfoWindow(title: 'Vị trí nguồn'),
              ),
            );
          } else {
            _destinationPosition = position;
            _markers.add(
              Marker(
                markerId: MarkerId('destinationLocation'),
                position: position,
                infoWindow: InfoWindow(title: 'Vị trí đích'),
              ),
            );
          }
        });

        if (_sourcePosition != null && _destinationPosition != null) {
          await _drawRoute(_sourcePosition!, _destinationPosition!);
        }
      } else {
        throw Exception('Không thể tải vị trí');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tìm kiếm vị trí: $e')),
      );
    }
  }

  Future<void> _drawRoute(LatLng source, LatLng destination) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&key=$api_key'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final points = polylinePoints.decodePolyline(data['routes'][0]['overview_polyline']['points']);
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
        throw Exception('Không thể tải hướng đi');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải hướng đi: $e')),
      );
    }
  }

  Future<void> _drawMaintainRouteForMap(LatLng source, LatLng destination, int date, String createdAt, String updatedAt) async {
    try {
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
                icon: _maintainIcon ?? BitmapDescriptor.defaultMarker,
                infoWindow: InfoWindow(
                  title: 'Ngày bảo trì: ${date} ngày',
                  snippet: '${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(createdAt))} - ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(updatedAt))}',
                ),
              ),
            );
          }
        });
      } else {
        throw Exception('Không thể tải hướng đi');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải hướng đi: $e')),
      );
    }
  }

  Future<void> _drawDamageRouteForMap(String name, LatLng source, LatLng destination, String createdAt, String updatedAt) async {
    try {
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
                icon: _damageIcon ?? BitmapDescriptor.defaultMarker,
                infoWindow: InfoWindow(
                  title: name,
                  snippet: 'Cảnh báo',
                ),
              ),
            );
          }
        });
      } else {
        throw Exception('Không thể tải hướng đi');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải hướng đi: $e')),
      );
    }
  }

  int _calculateTotalDays() {
    if (_startDate != null && _endDate != null) {
      return _endDate!.difference(_startDate!).inDays;
    }
    return 0;
  }

  Future<void> _sendDamageIssueRequest(String issueName) async {
    if (!mounted) return;

    if (_sourcePosition != null && _destinationPosition != null) {
      try {
        final response = await http.post(
          Uri.parse('$ip/detection/create-damage-road'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, dynamic>{
            'name': issueName,
            'locationA': _sourcePosition.toString(),
            'locationB': _destinationPosition.toString(),
          }),
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Báo cáo ngập nước thành công'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
          if (mounted) {
            setState(() {
              _markers.removeWhere((marker) => marker.markerId.value != 'myLocation');
            });
            await _debouncedFetchAndDrawRoutes();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi gửi báo cáo: ${response.statusCode}'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn đầy đủ vị trí nguồn và đích'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDamageIssueDialog() async {
    String? issueName;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Nhập tên sự cố'),
          content: TextField(
            decoration: const InputDecoration(
              hintText: 'Nhập tên sự cố (ví dụ: Ngập nước, ổ gà...)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              issueName = value;
            },
          ),
          actions: [
            TextButton(
              child: const Text('Hủy'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Gửi'),
              onPressed: () {
                if (issueName == null || issueName!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập tên sự cố'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop();
                _sendDamageIssueRequest(issueName!);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Chọn loại báo cáo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Bảo trì đường'),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showMaintainDialog();
                },
              ),
              ListTile(
                title: const Text('Báo cáo sự cố'),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showDamageIssueDialog(); // Thay bằng dialog nhập tên
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Hủy'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMaintainDialog() async {
    DateTime? startDate = _startDate;
    DateTime? endDate = _endDate;
    TimeOfDay? startTime = _startTime;
    TimeOfDay? endTime = _endTime;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => true,
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Chọn thời gian bảo trì'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(
                          startDate == null
                              ? "Chọn ngày bắt đầu"
                              : "Ngày bắt đầu: ${DateFormat('yyyy/MM/dd').format(startDate!)}",
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              startDate = pickedDate;
                              if (endDate != null && endDate!.isBefore(pickedDate)) {
                                endDate = null;
                                endTime = null;
                              }
                            });
                          }
                        },
                      ),
                      ListTile(
                        title: Text(
                          startTime == null
                              ? "Chọn giờ bắt đầu"
                              : "Giờ bắt đầu: ${startTime!.format(context)}",
                        ),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: startTime ?? TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              startTime = pickedTime;
                            });
                          }
                        },
                      ),
                      ListTile(
                        title: Text(
                          endDate == null
                              ? "Chọn ngày kết thúc"
                              : "Ngày kết thúc: ${DateFormat('yyyy/MM/dd').format(endDate!)}",
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? (startDate ?? DateTime.now()),
                            firstDate: startDate ?? DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              endDate = pickedDate;
                            });
                          }
                        },
                      ),
                      ListTile(
                        title: Text(
                          endTime == null
                              ? "Chọn giờ kết thúc"
                              : "Giờ kết thúc: ${endTime!.format(context)}",
                        ),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: endTime ?? TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              endTime = pickedTime;
                            });
                          }
                        },
                      ),
                      if (startDate != null && endDate != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Tổng số ngày bảo trì: ${endDate!.difference(startDate!).inDays} ngày",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('Hủy'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                  TextButton(
                    child: const Text('Gửi'),
                    onPressed: () {
                      if (startDate == null || endDate == null || startTime == null || endTime == null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng chọn đầy đủ ngày và giờ bắt đầu, kết thúc'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      final startDateTime = DateTime(
                        startDate!.year,
                        startDate!.month,
                        startDate!.day,
                        startTime!.hour,
                        startTime!.minute,
                      );
                      final endDateTime = DateTime(
                        endDate!.year,
                        endDate!.month,
                        endDate!.day,
                        endTime!.hour,
                        endTime!.minute,
                      );
                      if (endDateTime.isBefore(startDateTime)) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Ngày kết thúc phải sau ngày bắt đầu'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      if (mounted) {
                        setState(() {
                          _startDate = startDate;
                          _endDate = endDate;
                          _startTime = startTime;
                          _endTime = endTime;
                        });
                        _sendMaintainRequest();
                      }
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _sendMaintainRequest() async {
    if (_sourcePosition != null && _destinationPosition != null && _startDate != null && _endDate != null && _startTime != null && _endTime != null) {
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

      try {
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

        if (!mounted) return;

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gửi báo cáo bảo trì thành công'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
          if (mounted) {
            setState(() {
              _markers.removeWhere((marker) => marker.markerId.value != 'myLocation');
            });
            await _debouncedFetchAndDrawRoutes();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi gửi báo cáo bảo trì: ${response.statusCode}'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi gửi báo cáo bảo trì: $e'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vui lòng nhập đầy đủ thông tin bảo trì'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _debouncedFetchAndDrawRoutes() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      await _fetchAndDrawRoutes();
    }
  }

  Future<void> _fetchAndDrawRoutes() async {
    try {
      final responseMaintain = await getListMaintainForMapService.getListMaintainForMap();
      if (!mounted) return;

      if (responseMaintain['status'] == 'OK') {
        print('responseMaintain: $responseMaintain');
        final data = responseMaintain['data'];
        for (var route in data) {
          final locationA = _parseLatLng(route['locationA']);
          final locationB = _parseLatLng(route['locationB']);
          final date = route['dateMaintain'];
          final createdAt = route['createdAt'];
          final updatedAt = route['updatedAt'];
          await _drawMaintainRouteForMap(locationA, locationB, date, createdAt, updatedAt);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseMaintain['message'] ?? 'Không thể lấy tuyến đường bảo trì')),
          );
        }
      }

      final responseDamage = await getListDamageForMapService.getListDamageForMap();
      if (!mounted) return;

      if (responseDamage['status'] == 'OK') {
        final data = responseDamage['data'];
        for (var route in data) {
          final name = route['name'];
          final locationA = _parseLatLng(route['locationA']);
          final locationB = _parseLatLng(route['locationB']);
          final createdAt = route['createdAt'];
          final updatedAt = route['updatedAt'];
          await _drawDamageRouteForMap(name, locationA, locationB, createdAt, updatedAt);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseDamage['message'] ?? 'Không thể lấy tuyến đường hư hỏng')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lấy tuyến đường: $e')),
        );
      }
    }
  }

  LatLng _parseLatLng(String latLngString) {
    final parts = latLngString.replaceAll('LatLng(', '').replaceAll(')', '').split(',');
    return LatLng(double.parse(parts[0].trim()), double.parse(parts[1].trim()));
  }

  void _clearMarkersAndPolylines() {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value != 'myLocation');
      polylines.clear();
      _fetchAndDrawRoutes();
      _sourcePosition = null;
      _destinationPosition = null;
      _sourceText = '';
      _destinationText = '';
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectingByHand = !_isSelectingByHand;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSelectingByHand ? 'Chế độ chọn bằng tay: Bật' : 'Chế độ chọn bằng tay: Tắt',
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
              infoWindow: InfoWindow(title: 'Vị trí nguồn'),
            ),
          );
          _isSelectingSource = false;
        } else {
          _destinationPosition = tappedPoint;
          _markers.add(
            Marker(
              markerId: MarkerId('destinationLocation'),
              position: tappedPoint,
              infoWindow: InfoWindow(title: 'Vị trí đích'),
            ),
          );
          _isSelectingSource = true;

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
      appBar: AppBar(title: const Text('Báo Cáo Đường')),
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
                          setState(() {
                            _sourceText = suggestion;
                          });
                          _searchLocation(suggestion, true);
                        },
                        builder: (context, controller, focusNode) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Nhập vị trí nguồn',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _sourceText = value;
                              });
                            },
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                _searchLocation(value, true);
                              }
                            },
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        if (_sourceText.isNotEmpty) {
                          _searchLocation(_sourceText, true);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                          setState(() {
                            _destinationText = suggestion;
                          });
                          _searchLocation(suggestion, false);
                        },
                        builder: (context, controller, focusNode) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Nhập vị trí đích',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _destinationText = value;
                              });
                            },
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                _searchLocation(value, false);
                              }
                            },
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        if (_destinationText.isNotEmpty) {
                          _searchLocation(_destinationText, false);
                        }
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
              heroTag: 'ShowMyLocation',
              backgroundColor: const Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: reload,
              tooltip: 'Hiển thị vị trí của tôi',
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
              heroTag: 'UploadMaintainRoad',
              backgroundColor: const Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _showDialog,
              tooltip: 'Báo cáo bảo trì đường',
              child: const Icon(Icons.upload),
            ),
          ),
          Positioned(
            bottom: 170.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'ToggleSelectMode',
              backgroundColor: const Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _toggleSelectMode,
              tooltip: 'Chuyển chế độ chọn',
              child: Icon(_isSelectingByHand ? Icons.touch_app : Icons.pan_tool),
            ),
          ),
          Positioned(
            bottom: 210.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'ClearAll',
              backgroundColor: const Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _clearMarkersAndPolylines,
              tooltip: 'Xóa tất cả',
              child: const Icon(Icons.clear),
            ),
          ),
        ],
      ),
    );
  }
}