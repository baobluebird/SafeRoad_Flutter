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

class CrackScreen extends StatefulWidget {
  const CrackScreen({Key? key}) : super(key: key);

  @override
  State<CrackScreen> createState() => _CrackScreenState();
}

class _CrackScreenState extends State<CrackScreen> {
  List<dynamic>? _detections;
  late Detection? detection;
  int _total = 0;
  String _sortBy = 'newest'; // Mặc định sắp xếp theo newest

  Future<void> _fetchCracks({String? sortBy}) async {
    final Map<String, dynamic> response = sortBy != null
        ? await getSortService.getSorted('crack', sortBy)
        : await getListCracksService.getListCracks();
    if (response['status'] == 'OK') {
      setState(() {
        _detections = response['data'] is String && response['data'] == 'null' ? [] : response['data'];
        _total = response['total'] is int ? response['total'] : _detections?.length ?? 0;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${response['message'] ?? 'Failed to fetch data'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _getDetailCrack(String id) async {
    final Map<String, dynamic> response = await getDetailCrackService.getDetailCrack(id);
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
          content: Text('Error: ${response['message'] ?? 'Failed to fetch details'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCrack(String id) async {
    final response = await http.delete(
      Uri.parse('$ip/detection/delete-crack/$id'),
    );

    if (response.statusCode == 200) {
      setState(() {
        _detections!.removeWhere((crack) => crack['_id'] == id);
        _total = _detections!.length ?? 0; // Update total after deletion
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crack đã được deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete crack.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCracks(); // Lấy danh sách mặc định (newest)
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
                  _fetchCracks(sortBy: newValue);
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
        onRefresh: () => _fetchCracks(sortBy: _sortBy),
        child: _detections == null
            ? const Center(child: CircularProgressIndicator())
            : _detections!.isEmpty
            ? const Center(child: Text('No cracks available'))
            : ListView.builder(
          itemCount: _detections!.length,
          itemBuilder: (BuildContext context, int index) {
            final crack = _detections![index];
            return GestureDetector(
              onTap: () {
                _getDetailCrack(crack['_id']);
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
                      crack['image'] ?? '',
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
                          Text('Id Crack: ${crack['_id']}'),
                          Text('User Id post: ${crack['user']}'),
                          Text('Location: ${crack['location']}'),
                          Text('Address: ${crack['address']}'),
                          Text('Description: ${crack['description'] ?? 'N/A'}'),
                          Text(
                            'Time detect: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(crack['createdAt']).toLocal())}',
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
                                  item: crack,
                                  type: 'crack',
                                  onUpdate: () => _fetchCracks(sortBy: _sortBy),
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
                                content: const Text('Bạn có chắc chắn muốn xóa vết nứt này không?'),
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
                              _deleteCrack(crack['_id']);
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
                title: const Text('Total Cracks'),
                content: Text('Total number of cracks: $_total'),
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