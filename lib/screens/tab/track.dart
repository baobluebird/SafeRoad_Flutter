import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'dart:ui' as ui;
import 'package:vibration/vibration.dart';

class TrackingMapScreen extends StatefulWidget {
  @override
  _TrackingMapScreenState createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends State<TrackingMapScreen> {
  final Completer<GoogleMapController> _controller =
  Completer<GoogleMapController>();
  late Position _currentPosition;
  List<dynamic> largeHoles = [];
  List<dynamic> maintainRoad = [];
  List<dynamic> floodRoad = [];
  LatLng? _selectedPosition;
  int _currentHoleIndex = 0;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final TextEditingController _destinationController = TextEditingController();
  String _sessionToken = '';
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isMounted = false;
  late BitmapDescriptor _userIcon;
  late BitmapDescriptor _largeHoleIcon;
  late BitmapDescriptor _maintainRoadIcon;
  late BitmapDescriptor _floodRoadIcon;
  bool _isWarningDisplayed = false;
  Map<int, Set<String>> _holeWarnings = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  double? _currentDistance;
  final myBox = Hive.box('myBox');
  String _idUser = '';
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(16.0736, 108.1499),
    zoom: 14.4746,
  );

  void _clearSearch() {
    setState(() {
      _destinationController.clear();
      _selectedPosition = null;
      _polylines.clear();
      _markers.removeWhere((marker) => marker.markerId.value == 'selectedLocation');
      _sessionToken = '';
      _currentDistance = 0;
      largeHoles = [];
      maintainRoad = [];
      floodRoad = [];
      _holeWarnings.clear();
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _triggerAlert() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate();
    }
    await _audioPlayer.play(AssetSource('alert_10.mp3'));
  }

  Future<void> _triggerAlert2() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate();
    }
    await _audioPlayer.play(AssetSource('alert_50.mp3'));
  }

  Future<void> _triggerAlert3() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate();
    }
    await _audioPlayer.play(AssetSource('alert_100.mp3'));
  }

  Future<void> _triggerAlert4() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate();
    }
    await _audioPlayer.play(AssetSource('alert_near.mp3'));
  }

  Future<void> _stopAlert() async {
    await _audioPlayer.stop();
  }

  Future<void> _loadCustomIcons() async {
    final Uint8List location = await getBytesFromAsset(
      'assets/images/car.png',
      160,
    );
    final Uint8List maintain = await getBytesFromAsset(
      'assets/images/fix_road.png',
      160,
    );
    final Uint8List flood = await getBytesFromAsset(
      'assets/images/flood.png',
      160,
    );
    final Uint8List largeHole = await getBytesFromAsset(
      'assets/images/large_hole.png',
      130,
    );

    if (mounted) {
      setState(() {
        _userIcon = BitmapDescriptor.fromBytes(location);
        _largeHoleIcon = BitmapDescriptor.fromBytes(largeHole);
        _maintainRoadIcon = BitmapDescriptor.fromBytes(maintain);
        _floodRoadIcon = BitmapDescriptor.fromBytes(flood);
      });
    }
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

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _loadCustomIcons().then((_) {
      if (_isMounted) {
        _getCurrentLocation();
      }
    });
    _destinationController.addListener(() {
      if (_sessionToken.isEmpty && mounted) {
        setState(() {
          _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    _positionStreamSubscription?.cancel();
    _destinationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _updateMarkers() {
    if (_isMounted) {
      setState(() {
        _markers.removeWhere(
              (marker) =>
              marker.markerId.value.contains('largeHole') ||
              marker.markerId.value.contains('maintainRoad')||
          marker.markerId.value.contains('floodRoad'),
        );
        _markers.add(
          Marker(
            markerId: MarkerId('currentLocation'),
            position: LatLng(
              _currentPosition.latitude,
              _currentPosition.longitude,
            ),
            infoWindow: InfoWindow(title: 'Vị trí hiện tại'),
            icon: _userIcon,
          ),
        );

        int largeHoleIndex = 0;
        for (var item in largeHoles) {
          _markers.add(
            Marker(
              markerId: MarkerId('largeHole$largeHoleIndex'),
              position: LatLng(item[0], item[1]),
              infoWindow: InfoWindow(
                title: 'Ổ gà lớn',
                snippet: 'Hãy cẩn thận!',
              ),
              icon: _largeHoleIcon,
            ),
          );
          largeHoleIndex++;
        }
        int maintainRoadIndex = 0;
        for (var item in maintainRoad) {
          _markers.add(
            Marker(
              markerId: MarkerId('maintainRoad$maintainRoadIndex'),
              position: LatLng(item[0], item[1]),
              infoWindow: InfoWindow(
                title: 'Đường bảo trì',
                snippet: 'Hãy cẩn thận!',
              ),
              icon: _maintainRoadIcon,
            ),
          );
          maintainRoadIndex++;
        }
        int floodRoadIndex = 0;
        for (var item in floodRoad) {
          _markers.add(
            Marker(
              markerId: MarkerId('floodRoad$floodRoadIndex'),
              position: LatLng(item[0], item[1]),
              infoWindow: InfoWindow(
                title: 'Đường ngập lụt',
                snippet: 'Hãy cẩn thận!',
              ),
              icon: _floodRoadIcon,
            ),
          );
          floodRoadIndex++;
        }
        if (_selectedPosition != null) {
          _markers.add(
            Marker(
              markerId: MarkerId('selectedLocation'),
              position: _selectedPosition!,
              infoWindow: InfoWindow(title: 'Điểm đến đã chọn'),
            ),
          );
        }
      });
    }
  }

  void _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    if (!_isMounted) return;
    if (_isMounted) {
      setState(() {
        _currentPosition = position;
        _markers.add(
          Marker(
            markerId: MarkerId('currentLocation'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: InfoWindow(title: 'Vị trí hiện tại'),
            icon: _userIcon,
          ),
        );
      });
    }
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 16.0,
        ),
      ),
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (_isMounted) {
        setState(() {
          _currentPosition = position;
          _markers.removeWhere((m) => m.markerId.value == 'currentLocation');
          _markers.add(
            Marker(
              markerId: MarkerId('currentLocation'),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: InfoWindow(title: 'Vị trí hiện tại'),
              icon: _userIcon,
            ),
          );
        });
        _updateCameraPosition(position);
        _checkProximityToLargeHoles();
      }
    });
  }

  Future<void> _updateCameraPosition(Position position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 18.0,
        ),
      ),
    );
  }

  void _checkProximityToLargeHoles() async {
    if (_currentHoleIndex < largeHoles.length && !_isWarningDisplayed) {
      var hole = largeHoles[_currentHoleIndex];
      final double distance = Geolocator.distanceBetween(
        _currentPosition.latitude,
        _currentPosition.longitude,
        hole[0],
        hole[1],
      );
      if (_isMounted) {
        setState(() {
          _currentDistance = distance;
        });
      }
      print('Khoảng cách đến ổ gà lớn: $distance');
      print('Chỉ số ổ gà hiện tại: $_currentHoleIndex');

      if (distance < 10 && !_hasWarningBeenShown(_currentHoleIndex, '10m')) {
        _triggerAlert();
        _isWarningDisplayed = true;
        await _showWarningDialog(
          'Bạn đang ở trong vòng 10 mét của một ổ gà lớn!',
          3,
        );
        _markWarningAsShown(_currentHoleIndex, '10m');
        if (_currentHoleIndex < largeHoles.length - 1) {
          var nextHole = largeHoles[_currentHoleIndex + 1];
          final double nextDistance = Geolocator.distanceBetween(
            hole[0],
            hole[1],
            nextHole[0],
            nextHole[1],
          );
          print('Khoảng cách đến ổ gà tiếp theo: $nextDistance');
          if (nextDistance < 30) {
            _triggerAlert4();
            _isWarningDisplayed = true;
            await _showWarningDialog(
              'Có một ổ gà khác phía trước, hãy cẩn thận!',
              3,
            );
            _currentHoleIndex++;
            _isWarningDisplayed = false;
          }
        }
        _currentHoleIndex++;
        _isWarningDisplayed = false;
        _stopAlert();
      } else if (30 < distance &&
          distance < 50 &&
          !_hasWarningBeenShown(_currentHoleIndex, '50m')) {
        _isWarningDisplayed = true;
        _triggerAlert2();
        await _showWarningDialog(
          'Bạn đang ở trong vòng 50 mét của một ổ gà lớn!',
          3,
        );
        _markWarningAsShown(_currentHoleIndex, '50m');
        _isWarningDisplayed = false;
        _stopAlert();
      } else if (80 < distance &&
          distance < 100 &&
          !_hasWarningBeenShown(_currentHoleIndex, '100m')) {
        _triggerAlert3();
        _isWarningDisplayed = true;
        await _showWarningDialog(
          'Bạn đang ở trong vòng 100 mét của một ổ gà lớn!',
          3,
        );
        _markWarningAsShown(_currentHoleIndex, '100m');
        _isWarningDisplayed = false;
        _stopAlert();
      }
    } else {
      if (_isMounted) {
        setState(() {
          _currentDistance = 0;
        });
      }
    }
  }

  Future<void> _showWarningDialog(String message, int seconds) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        Future.delayed(Duration(seconds: seconds), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });

        return AlertDialog(title: Text('Cảnh báo'), content: Text(message));
      },
    );
  }

  bool _hasWarningBeenShown(int holeIndex, String distanceLabel) {
    return _holeWarnings[holeIndex]?.contains(distanceLabel) ?? false;
  }

  void _markWarningAsShown(int holeIndex, String distanceLabel) {
    if (_holeWarnings[holeIndex] == null) {
      _holeWarnings[holeIndex] = {};
    }
    _holeWarnings[holeIndex]!.add(distanceLabel);
  }

  Future<void> _drawRoute(LatLng destination) async {
    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition.latitude},${_currentPosition.longitude}&destination=${destination.latitude},${destination.longitude}&key=$api_key',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = PolylinePoints().decodePolyline(
        data['routes'][0]['overview_polyline']['points'],
      );
      if (!_isMounted) return;
      if (_isMounted) {
        setState(() {
          _polylines.clear(); // Xóa các polyline cũ trước khi thêm mới
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route'),
              points:
              points.map((point) => LatLng(point.latitude, point.longitude)).toList(),
              color: Colors.blue,
              width: 5,
            ),
          );
        });
        print('Đã vẽ tuyến đường chính với ${points.length} điểm');
      }
      List<Map<String, double>> coordinates = [];
      points.forEach((point) {
        coordinates.add({
          'latitude': point.latitude,
          'longitude': point.longitude,
        });
      });
      await _uploadCoordinates(coordinates);
    } else {
      print('Lỗi tải chỉ đường: ${response.statusCode}');
      throw Exception('Không thể tải dữ liệu chỉ đường');
    }
  }

  Future<void> _drawAlternativeRoute(String encodedPolyline) async {
    final points = PolylinePoints().decodePolyline(encodedPolyline);
    List<Map<String, double>> coordinates = [];
    points.forEach((point) {
      coordinates.add({
        'latitude': point.latitude,
        'longitude': point.longitude,
      });
    });

    print('Gửi ${coordinates.length} tọa độ tuyến đường thay thế lên server');

    try {
      final response = await http.post(
        Uri.parse('$ip/detection/post-location-tracking'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'coordinates': coordinates}),
      );

      if (response.statusCode == 200) {
        print('Phản hồi server: ${response.body}');
        final responseData = jsonDecode(response.body);
        List<dynamic> hole = responseData['matchingCoordinatesHole'] ?? [];
        List<dynamic> maintain = responseData['matchingCoordinatesMaintainRoad'] ?? [];
        List <dynamic> flood = responseData['matchingCoordinatesFloodRoad'] ?? [];

        if (_isMounted) {
          setState(() {
            largeHoles = hole;
            maintainRoad = maintain;
            floodRoad = flood;
            _currentHoleIndex = 0;
            _holeWarnings.clear();
          });
        } else {
          print('Widget không còn mounted, bỏ qua cập nhật trạng thái');
          return;
        }

        if (maintain.isEmpty && flood.isEmpty) {
          print('Không có bảo trì, xóa tuyến cũ và vẽ tuyến mới');
          if (_isMounted) {
            setState(() {
              _polylines.clear(); // Xóa toàn bộ tuyến đường cũ
              _polylines.add(
                Polyline(
                  polylineId: PolylineId('route_${DateTime.now().millisecondsSinceEpoch}'),
                  points: points
                      .map((point) => LatLng(point.latitude, point.longitude))
                      .toList(),
                  color: Colors.blue,
                  width: 5,
                ),
              );
              print('Đã thêm tuyến đường mới với ${points.length} điểm, polyline count: ${_polylines.length}');
            });
          }

          // Làm mới bản đồ để hiển thị tuyến đường mới
          try {
            final GoogleMapController controller = await _controller.future;
            final bounds = LatLngBounds(
              southwest: LatLng(
                points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
                points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
              ),
              northeast: LatLng(
                points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
                points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
              ),
            );
            await controller.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 50.0),
            );
            print('Đã làm mới bản đồ với bounds: $bounds');
          } catch (e) {
            print('Lỗi khi làm mới bản đồ: $e');
          }

          _updateMarkers();
          if (largeHoles.isEmpty) {
            if (_isMounted) {
              setState(() {
                _currentDistance = 0;
              });
            }
          } else {
            var hole = largeHoles[0];
            final double distance = Geolocator.distanceBetween(
              _currentPosition.latitude,
              _currentPosition.longitude,
              hole[0],
              hole[1],
            );
            if (_isMounted) {
              setState(() {
                _currentDistance = distance;
              });
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã chọn tuyến đường thay thế không có bảo trì hoặc ngập lụt!'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lộ trình thay thế vẫn có bảo trì hoặc ngập lụt, hãy chọn lộ trình khác!'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
          await _showMaintenanceWarningDialog();
        }
      } else {
        throw Exception('Không thể kiểm tra tọa độ tuyến đường thay thế: ${response.statusCode}');
      }
    } catch (e) {
      print('Lỗi khi xử lý tuyến đường thay thế: $e');
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi kiểm tra tuyến đường thay thế!'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchAndShowAlternativeRoutes(LatLng destination) async {
    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition.latitude},${_currentPosition.longitude}&destination=${destination.latitude},${destination.longitude}&alternatives=true&avoid=highways,tolls&key=$api_key',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final routes = data['routes'] as List<dynamic>;
      print('Số lộ trình thay thế: ${routes.length}');

      // Log tọa độ lộ trình hiện tại (nếu có)
      List<LatLng> currentPoints = [];
      if (_polylines.isNotEmpty) {
        currentPoints = _polylines.first.points;
        print('Tọa độ lộ trình hiện tại (${currentPoints.length} điểm):');
        currentPoints.asMap().forEach((index, point) {
          print('Điểm $index: [${point.latitude}, ${point.longitude}]');
        });
      } else {
        print('Không có lộ trình hiện tại để so sánh');
      }

      if (routes.length <= 1) {
        print('Không đủ lộ trình thay thế để hiển thị');
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Thông báo'),
              content: Text('Không tìm thấy lộ trình thay thế.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      // Kiểm tra từng lộ trình thay thế qua server
      List<Map<String, dynamic>> validRoutes = [];
      List<Map<String, dynamic>> allRoutes = [];
      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        final points = PolylinePoints().decodePolyline(route['overview_polyline']['points']);
        List<Map<String, double>> coordinates = [];
        points.forEach((point) {
          coordinates.add({
            'latitude': point.latitude,
            'longitude': point.longitude,
          });
        });

        // Log tọa độ lộ trình thay thế
        print('Tọa độ lộ trình thay thế ${i + 1} (${points.length} điểm):');
        points.asMap().forEach((index, point) {
          print('Điểm $index: [${point.latitude}, ${point.longitude}]');
        });

        // So sánh với lộ trình hiện tại để loại bỏ lộ trình trùng lặp
        bool isDuplicate = false;
        if (currentPoints.isNotEmpty && points.length == currentPoints.length) {
          isDuplicate = true;
          for (int j = 0; j < points.length; j++) {
            if ((points[j].latitude - currentPoints[j].latitude).abs() > 0.00001 ||
                (points[j].longitude - currentPoints[j].longitude).abs() > 0.00001) {
              isDuplicate = false;
              break;
            }
          }
        }
        if (isDuplicate) {
          print('Lộ trình ${i + 1} trùng với lộ trình hiện tại, bỏ qua');
          continue;
        }

        try {
          final serverResponse = await http.post(
            Uri.parse('$ip/detection/post-location-tracking'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'coordinates': coordinates}),
          );

          if (serverResponse.statusCode == 200) {
            final responseData = jsonDecode(serverResponse.body);
            List<dynamic> maintain = responseData['matchingCoordinatesMaintainRoad'] ?? [];
            List<dynamic> flood = responseData['matchingCoordinatesFloodRoad'] ?? [];
            allRoutes.add({
              'index': i + 1,
              'route': route,
              'polyline': route['overview_polyline']['points'],
              'maintain': maintain,
              'flood': flood,
            });
            if (maintain.isEmpty && flood.isEmpty) {
              validRoutes.add({
                'index': i + 1,
                'route': route,
                'polyline': route['overview_polyline']['points'],
              });
              print('Lộ trình ${i + 1}: maintainRoad = $maintain (Hợp lệ)');
            } else {
              print('Lộ trình ${i + 1}: maintainRoad = $maintain (Không hợp lệ do có bảo trì)');
            }
          } else {
            print('Lỗi kiểm tra lộ trình ${i + 1}: ${serverResponse.statusCode}');
          }
        } catch (e) {
          print('Lỗi khi kiểm tra lộ trình ${i + 1}: $e');
        }
      }

      // Nếu không có lộ trình nào không có bảo trì, hiển thị tất cả lộ trình với cảnh báo
      final displayRoutes = validRoutes.isNotEmpty ? validRoutes : allRoutes;
      if (displayRoutes.isEmpty) {
        print('Không có lộ trình thay thế khả dụng sau khi kiểm tra');
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Thông báo'),
              content: Text('Không tìm thấy lộ trình thay thế khả dụng.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Chọn lộ trình thay thế'),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: displayRoutes.length,
                itemBuilder: (context, index) {
                  final routeData = displayRoutes[index];
                  final route = routeData['route'];
                  final routeIndex = routeData['index'];
                  final maintain = routeData['maintain'] ?? [];
                  final flood = routeData['flood'] ?? [];
                  final distance = route['legs'][0]['distance']['text'];
                  final duration = route['legs'][0]['duration']['text'];
                  final subtitle = maintain.isEmpty
                      ? 'Khoảng cách: $distance, Thời gian: $duration'
                      : 'Khoảng cách: $distance, Thời gian: $duration (Có bảo trì hoặc ngập lụt)';
                  return ListTile(
                    title: Text('Lộ trình $routeIndex'),
                    subtitle: Text(subtitle),
                    onTap: () {
                      Navigator.of(context).pop();
                      _drawAlternativeRoute(routeData['polyline']);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Hủy'),
              ),
            ],
          );
        },
      );
    } else {
      print('Lỗi tải lộ trình thay thế: ${response.statusCode}');
      throw Exception('Không thể tải lộ trình thay thế');
    }
  }

  Future<void> _sendHelp() async {
    _idUser = myBox.get('userId', defaultValue: '');
    String location =
        '(${_currentPosition.latitude}, ${_currentPosition.longitude})';
    final Map<String, dynamic> requestBody = {"location": location};
    try {
      final response = await http.post(
        Uri.parse('$ip/user/send-help/$_idUser'),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );
      print(response.statusCode);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gửi yêu cầu trợ giúp thành công!'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi gửi yêu cầu!'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      print('Lỗi: $error');
    }
  }

  Future<void> _showMaintenanceWarningDialog() async {
    final action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cảnh báo'),
          content: Text(
            'Đoạn đường bạn đi đang được bảo trì hoặc ngập lụt, bạn có muốn tiếp tục không?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop('continue');
              },
              child: Text('Tiếp tục'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop('suggest');
              },
              child: Text('Đề xuất tuyến đường khác'),
            ),
            TextButton(
              onPressed: () {
                _clearTrack();
                Navigator.of(context).pop('cancel');
              },
              child: Text('Hủy bỏ'),
            ),
          ],
        );
      },
    );

    if (action == 'suggest' && _selectedPosition != null) {
      print('Bắt đầu tìm lộ trình thay thế cho đích đến: ${_selectedPosition!.latitude}, ${_selectedPosition!.longitude}');
      await _fetchAndShowAlternativeRoutes(_selectedPosition!);
    } else if (action == 'suggest' && _selectedPosition == null) {
      print('Không thể tìm lộ trình thay thế: _selectedPosition là null');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng chọn điểm đến trước!'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadCoordinates(List<Map<String, double>> coordinates) async {
    try {
      final response = await http.post(
        Uri.parse('$ip/detection/post-location-tracking'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'coordinates': coordinates}),
      );

      if (response.statusCode == 200) {
        print('Phản hồi server: ${response.body}');
        try {
          final responseData = jsonDecode(response.body);
          List<dynamic> Hole = responseData['matchingCoordinatesHole'] ?? [];
          List<dynamic> MaintainRoad = responseData['matchingCoordinatesMaintainRoad'] ?? [];
          List<dynamic> FloodRoad = responseData['matchingCoordinatesFloodRoad'] ?? [];

          if (_isMounted) {
            setState(() {
              largeHoles = Hole;
              maintainRoad = MaintainRoad;
              floodRoad = FloodRoad;
              _currentHoleIndex = 0;
              _holeWarnings.clear();
            });
          }
          _updateMarkers();
          if (maintainRoad.isNotEmpty || floodRoad.isNotEmpty) {
            await _showMaintenanceWarningDialog();
          } else if (largeHoles.isEmpty) {
            if (_isMounted) {
              setState(() {
                _currentDistance = 0;
              });
            }
          } else {
            var hole = largeHoles[0];
            final double distance = Geolocator.distanceBetween(
              _currentPosition.latitude,
              _currentPosition.longitude,
              hole[0],
              hole[1],
            );
            if (_isMounted) {
              setState(() {
                _currentDistance = distance;
              });
            }
            print('Phát hiện ổ gà tại: ${hole[0]}, ${hole[1]}');
          }

          print('Tải tọa độ lên thành công');
          print('Tọa độ khớp: $largeHoles');
        } catch (e) {
          print('Lỗi giải mã phản hồi server: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xử lý dữ liệu từ server!'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print('Lỗi server: ${response.statusCode}');
        throw Exception('Không thể tải tọa độ lên');
      }
    } catch (e) {
      print('Lỗi khi gửi tọa độ: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối server!'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _searchDestination(String address) async {
    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$api_key',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final location = data['results'][0]['geometry']['location'];
      final LatLng destination = LatLng(location['lat'], location['lng']);

      if (!_isMounted) return;
      if (_isMounted) {
        setState(() {
          _selectedPosition = destination;
          _markers.add(
            Marker(
              markerId: MarkerId('selectedLocation'),
              position: destination,
              infoWindow: InfoWindow(title: 'Điểm đến đã chọn'),
            ),
          );
        });
      }
      await _drawRoute(destination);
    } else {
      print('Lỗi tải dữ liệu mã hóa địa lý: ${response.statusCode}');
      throw Exception('Không thể tải dữ liệu mã hóa địa lý');
    }
  }

  Future<List<String>> _fetchSuggestions(String input) async {
    if (_sessionToken.isEmpty) {
      return [];
    }

    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$api_key&sessiontoken=$_sessionToken',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final predictions = data['predictions'];
      return List<String>.from(predictions.map((p) => p['description']));
    } else {
      print('Lỗi tải dự đoán địa điểm: ${response.statusCode}');
      throw Exception('Không thể tải dự đoán địa điểm');
    }
  }

  void _onMapTapped(LatLng position) {
    if (_isMounted) {
      setState(() {
        _selectedPosition = position;
        _markers.add(
          Marker(
            markerId: MarkerId('selectedLocation'),
            position: position,
            infoWindow: InfoWindow(title: 'Điểm đến đã chọn'),
          ),
        );
      });
    }
    _drawRoute(position);
  }

  void _clearTrack() {
    if (_isMounted) {
      setState(() {
        _markers.removeWhere(
              (marker) =>
          marker.markerId.value.contains('largeHole') ||
              marker.markerId.value.contains('maintainRoad') ||
          marker.markerId.value.contains('floodRoad') ||
              marker.markerId.value == 'selectedLocation',
        );
        _polylines.clear();
        _selectedPosition = null;
        _currentHoleIndex = 0;
        _currentDistance = 0;
        largeHoles = [];
        maintainRoad = [];
        floodRoad = [];
        _holeWarnings.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.terrain,
            initialCameraPosition: _initialPosition,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onTap: _onMapTapped,
            onCameraMove: (CameraPosition position) {
              _selectedPosition = position.target;
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
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
                          return ListTile(
                            title: Text(suggestion),
                          );
                        },
                        onSelected: (suggestion) {
                          _destinationController.text = suggestion;
                          _searchDestination(suggestion);
                          FocusScope.of(context).unfocus();
                        },
                        controller: _destinationController,
                        builder: (context, controller, focusNode) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Nhập điểm đến',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          );
                        },
                        emptyBuilder: (context) => Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Không tìm thấy kết quả!',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _destinationController,
                      builder: (context, value, child) {
                        return value.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.cancel),
                          onPressed: _clearSearch,
                          tooltip: 'Hủy tìm kiếm',
                        )
                            : IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () {
                            _searchDestination(_destinationController.text);
                          },
                        );
                      },
                    ),
                  ],
                ),
                if (_currentDistance != null)
                  Container(
                    padding: EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 5.0,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Khoảng cách đến ổ gà gần nhất: ${_currentDistance!.toStringAsFixed(2)} mét',
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 85.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'tracking-location',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _getCurrentLocation,
              tooltip: 'Hiển thị vị trí của tôi',
              child: Image.asset('assets/images/car.png', width: 30, height: 30),
            ),
          ),
          Positioned(
            bottom: 130.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'tracking-clear',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _clearTrack,
              tooltip: 'Xóa lộ trình',
              child: const Icon(Icons.clear),
            ),
          ),
          Positioned(
            bottom: 175.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'tracking-help',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: () => _sendHelp(),
              tooltip: 'Gửi trợ giúp',
              child: const Icon(Icons.health_and_safety),
            ),
          ),
        ],
      ),
    );
  }
}