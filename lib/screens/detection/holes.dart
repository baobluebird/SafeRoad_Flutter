import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'package:pothole/screens/detection/detection.dart';
import 'package:http/http.dart' as http;
import '../../model/detection.dart';
import '../../services/detection_service.dart';
import 'package:intl/intl.dart';
import 'detection_for_detail.dart';
import 'edit_screen.dart';

class HolesScreen extends StatefulWidget {
  const HolesScreen({Key? key}) : super(key: key);

  @override
  State<HolesScreen> createState() => _HolesScreenState();
}

class _HolesScreenState extends State<HolesScreen> {
  List<dynamic>? _detections;
  late Detection? detection;
  int _total = 0;
  String _sortBy = 'newest'; // Mặc định sắp xếp theo newest

  Future<void> _fetchHoles({String? sortBy}) async {
    final Map<String, dynamic> response = sortBy != null
        ? await getSortService.getSorted('hole',sortBy)
        : await getListHolesService.getListHoles();
    if (response['status'] == 'OK') {
      print('Response data: ${response['data']}');
      setState(() {
        _detections = response['data'] is String && response['data'] == 'null' ? [] : response['data'];
        _total = response['total'] is int ? response['total'] : _detections?.length ?? 0;      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${response['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _getDetailHole(String id) async {
    final Map<String, dynamic> response = await getDetailHoleService.getDetailHole(id);
    if (response['status'] == 'OK') {
      final Map<String, dynamic> detectionData = response['data'];
      detection = Detection.fromJson(detectionData);

      String? imageData = response['image'];
      if (imageData != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetectionForDetailScreen(
              detection: detection,
              imageData: imageData,
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${response['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteHole(String id) async {
    final response = await http.delete(
      Uri.parse('$ip/detection/delete-hole/$id'),
    );

    if (response.statusCode == 200) {
      setState(() {
        _detections!.removeWhere((hole) => hole['_id'] == id);
        _total--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hole deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete hole.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchHoles(); // Lấy danh sách mặc định (newest)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<String>(
              value: _sortBy,
              icon: const Icon(Icons.sort, color: Colors.blue),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
              underline: Container(height: 2, color: Colors.blue),
              onChanged: (String? newValue) {
                if (newValue != null && newValue != _sortBy) {
                  setState(() {
                    _sortBy = newValue;
                  });
                  _fetchHoles(sortBy: newValue);
                }
              },
              items: <String>['newest', 'oldest']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value == 'newest' ? 'Newest' : 'Oldest'),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchHoles(sortBy: _sortBy),
        child: _detections == null
            ? const Center(child: CircularProgressIndicator())
            : _detections!.isEmpty
            ? const Center(child: Text('No holes available'))
            : ListView.builder(
          itemCount: _detections!.length,
          itemBuilder: (BuildContext context, int index) {
            final hole = _detections![index];
            return GestureDetector(
              onTap: () {
                _getDetailHole(hole['_id']);
              },
              child: Container(
                margin: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Image.network(
                      hole['image'] ?? '',
                      width: 50,
                      height: 50,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error);
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Id Hole: ${hole['_id']}'),
                          Text('User Id post: ${hole['user']}'),
                          Text('Location: ${hole['location']}'),
                          Text('Address: ${hole['address']}'),
                          Text('Description: ${hole['description'] ?? 'N/A'}'),
                          Text(
                            'Time detect: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(hole['createdAt']).toLocal())}',
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditScreen(
                                  item: hole,
                                  type: 'hole',
                                  onUpdate: () => _fetchHoles(sortBy: _sortBy),
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirmDelete = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                title: const Text('Xác nhận xóa'),
                                content: const Text('Bạn có chắc chắn muốn xóa ổ gà này không?'),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('Huỷ'),
                                    onPressed: () => Navigator.of(context).pop(false),
                                  ),
                                  TextButton(
                                    child: const Text('Xoá'),
                                    onPressed: () => Navigator.of(context).pop(true),
                                  ),
                                ],
                              ),
                            );

                            if (confirmDelete == true) {
                              _deleteHole(hole['_id']);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Total Holes'),
                content: Text('Total number of holes: $_total'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
        child: Text(
          '$_total',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        backgroundColor: Colors.white,
      ),
    );
  }
}