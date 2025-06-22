import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pothole/screens/detection/damage_detail.dart';
import '../../services/detection_service.dart';
import 'edit_screen.dart';

class DamageRoadScreen extends StatefulWidget {
  const DamageRoadScreen({Key? key}) : super(key: key);

  @override
  State<DamageRoadScreen> createState() => _DamageRoadState();
}

class _DamageRoadState extends State<DamageRoadScreen> {
  List<dynamic>? _damageRoads;
  int _total = 0;
  String _sortBy = 'newest'; // Mặc định sắp xếp theo newest

  Future<void> _fetchDamageRoads({String? sortBy}) async {
    final Map<String, dynamic> response = sortBy != null
        ? await getSortService.getSorted('damage', sortBy)
        : await getListDamageRoadsService.getListDamageRoads();
    if (response['status'] == 'OK') {
      setState(() {
        _damageRoads = response['data'] is String && response['data'] == 'null' ? [] : response['data'];
        _total = response['total'] is int ? response['total'] : _damageRoads?.length ?? 0;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${response['message'] ?? 'Failed to fetch damage roads'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteDamageRoad(String id) async {
    final response = await http.delete(
      Uri.parse('$ip/detection/delete-damage/$id'),
    );

    if (response.statusCode == 200) {
      setState(() {
        _damageRoads!.removeWhere((damage) => damage['_id'] == id);
        _total = _damageRoads!.length; // Update total after deletion
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Damage road deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete damage road.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchDamageRoads(); // Lấy danh sách mặc định (newest)
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
                  _fetchDamageRoads(sortBy: newValue);
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
        onRefresh: () => _fetchDamageRoads(sortBy: _sortBy),
        child: _damageRoads == null
            ? const Center(child: CircularProgressIndicator())
            : _damageRoads!.isEmpty
            ? const Center(child: Text('No damage roads available'))
            : ListView.builder(
          itemCount: _damageRoads!.length,
          itemBuilder: (BuildContext context, int index) {
            final damage = _damageRoads![index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DamageRoadDetailScreen(
                      name: damage['name'],
                      sourceName: damage['sourceName'],
                      destinationName: damage['destinationName'],
                      locationA: _parseLatLng(damage['locationA']),
                      locationB: _parseLatLng(damage['locationB']),
                      dateDamage: damage['createdAt'],
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${damage['_id']}'),
                          Text('Name: ${damage['name']}'),
                          Text('Source: ${damage['sourceName']}'),
                          Text('Destination: ${damage['destinationName']}'),
                          Text('Location A: ${damage['locationA']}'),
                          Text('Location B: ${damage['locationB']}'),
                          Text(
                            'Date Damage: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(damage['createdAt']).toLocal())}',
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
                                  item: damage,
                                  type: 'damage',
                                  onUpdate: () => _fetchDamageRoads(sortBy: _sortBy),
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
                                content: const Text('Bạn có chắc muốn xóa đoạn ngập lụt này không?'),
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
                              _deleteDamageRoad(damage['_id']);
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
                title: const Text('Total Damage Roads'),
                content: Text('Total number of damage roads: $_total'),
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