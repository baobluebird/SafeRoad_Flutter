import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pothole/screens/detection/road_detail.dart';

import 'edit_screen.dart';

class MaintainRoadScreen extends StatefulWidget {
  const MaintainRoadScreen({Key? key}) : super(key: key);

  @override
  State<MaintainRoadScreen> createState() => _MaintainRoadState();
}

class _MaintainRoadState extends State<MaintainRoadScreen> {
  List<dynamic>? _maintainRoads;
  int _total = 0;

  Future<void> _getListMaintainRoad() async {
    var url = Uri.parse('$ip/detection/get-maintain-road');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      setState(() {
        _maintainRoads = data;
        _total = data.length;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch routes from server')));
    }
  }

  Future<void> _deleteMaintainRoad(String id) async {
    final response = await http.delete(
      Uri.parse('$ip/detection/delete-maintain/$id'),
    );

    if (response.statusCode == 200) {
      setState(() {
        _maintainRoads!.removeWhere((road) => road['_id'] == id);
        _total--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maintain road deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete maintain road.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _getListMaintainRoad();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _maintainRoads == null
          ? const Center(child: CircularProgressIndicator())
          : _maintainRoads!.isEmpty
          ? const Center(child: Text('No maintain roads available'))
          : RefreshIndicator(
        onRefresh: _getListMaintainRoad,
        child: ListView.builder(
          itemCount: _maintainRoads!.length,
          itemBuilder: (BuildContext context, int index) {
            final road = _maintainRoads![index];
            final endDate = DateTime.parse(road['endDate']);
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
                            'Date Maintain: ${road['dateMaintain']} days (${DateFormat('yyyy/MM/dd ').format(DateTime.parse(road['startDate']))} - ${DateFormat('yyyy/MM/dd').format(DateTime.parse(road['endDate']))})',
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
                                  onUpdate: _getListMaintainRoad,
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
                                content: const Text('Bạn có chắc chắn muốn xóa bảo trì này không?'),
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
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }
}
