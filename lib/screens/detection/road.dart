import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pothole/screens/detection/road_detail.dart';
import '../../services/detection_service.dart';
import 'edit_screen.dart';

class MaintainRoadScreen extends StatefulWidget {
  const MaintainRoadScreen({Key? key}) : super(key: key);

  @override
  State<MaintainRoadScreen> createState() => _MaintainRoadState();
}

class _MaintainRoadState extends State<MaintainRoadScreen> {
  List<dynamic>? _maintainRoads;
  int _total = 0;
  String _sortBy = 'newest'; // Mặc định sắp xếp theo newest

  Future<void> _fetchMaintainRoads({String? sortBy}) async {
    final Map<String, dynamic> response = sortBy != null
        ? await getSortService.getSorted('road', sortBy)
        : await getListMaintainRoadsService.getListMaintainRoads();
    if (response['status'] == 'OK') {
      setState(() {
        _maintainRoads = response['data'] is String && response['data'] == 'null' ? [] : response['data'];
        _total = response['total'] is int ? response['total'] : _maintainRoads?.length ?? 0;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${response['message'] ?? 'Failed to fetch maintain roads'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteMaintainRoad(String id) async {
    final response = await http.delete(
      Uri.parse('$ip/detection/delete-maintain/$id'),
    );

    if (response.statusCode == 200) {
      setState(() {
        _maintainRoads!.removeWhere((road) => road['_id'] == id);
        _total = _maintainRoads!.length; // Update total after deletion
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maintain road deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete maintain road.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchMaintainRoads(); // Lấy danh sách mặc định (newest)
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
                  _fetchMaintainRoads(sortBy: newValue);
                }
              },
              items: <String>[
                'newest',
                'oldest',
                'maintain_asc',
                'maintain_desc',
                'distance_asc',
                'distance_desc',
              ].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value == 'newest'
                        ? 'Newest'
                        : value == 'oldest'
                        ? 'Oldest'
                        : value == 'maintain_asc'
                        ? 'Maintain Asc'
                        : value == 'maintain_desc'
                        ? 'Maintain Desc'
                        : value == 'distance_asc'
                        ? 'Distance Asc'
                        : 'Distance Desc',
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchMaintainRoads(sortBy: _sortBy),
        child: _maintainRoads == null
            ? const Center(child: CircularProgressIndicator())
            : _maintainRoads!.isEmpty
            ? const Center(child: Text('No maintain roads available'))
            : ListView.builder(
          itemCount: _maintainRoads!.length,
          itemBuilder: (BuildContext context, int index) {
            final road = _maintainRoads![index];
            final endDate = DateTime.parse(road['endDate']).toLocal();
            final isExpired = endDate.isBefore(DateTime.now());

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MaintainRoadDetailScreen(
                      sourceName: road['sourceName'],
                      destinationName: road['destinationName'],
                      locationA: _parseLatLng(road['locationA']),
                      locationB: _parseLatLng(road['locationB']),
                      dateMaintain: road['dateMaintain'],
                      startDate: road['startDate'],
                      endDate: road['endDate'],
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.red.shade100 : Colors.white,
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Source: ${road['sourceName']}'),
                          Text('Destination: ${road['destinationName']}'),
                          Text('Location A: ${road['locationA']}'),
                          Text('Location B: ${road['locationB']}'),
                          Text(
                            'Date Maintain: ${road['dateMaintain']} days (${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(road['startDate']).toLocal())} - ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(road['endDate']).toLocal())})',
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
                                  item: road,
                                  type: 'maintain',
                                  onUpdate: () => _fetchMaintainRoads(sortBy: _sortBy),
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
                                content: const Text('Bạn có chắc muốn xóa bảo trì này không?'),
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
                              _deleteMaintainRoad(road['_id']);
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
                title: const Text('Total Maintain Roads'),
                content: Text('Total number of maintain roads: $_total'),
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

  LatLng _parseLatLng(String latLngString) {
    final parts = latLngString.replaceAll('LatLng(', '').replaceAll(')', '').split(',');
    return LatLng(double.parse(parts[0].trim()), double.parse(parts[1].trim()));
  }
}