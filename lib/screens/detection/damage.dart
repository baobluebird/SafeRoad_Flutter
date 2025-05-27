import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pothole/screens/detection/damage_detail.dart';

import 'edit_screen.dart';

class DamageRoadScreen extends StatefulWidget {
  const DamageRoadScreen({Key? key}) : super(key: key);

  @override
  State<DamageRoadScreen> createState() => _DamageRoadState();
}

class _DamageRoadState extends State<DamageRoadScreen> {
  List<dynamic>? _damageRoads;
  int _total = 0;

  Future<void> _getListDamageRoad() async {
    var url = Uri.parse('$ip/detection/get-damage-road');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      setState(() {
        _damageRoads = data;
        _total = data.length;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch routes from server')));
    }
  }

  Future<void> _deleteDamageRoad(String id) async {
    final response = await http.delete(
      Uri.parse('$ip/detection/delete-damage/$id'),
    );

    if (response.statusCode == 200) {
      setState(() {
        _damageRoads!.removeWhere((damage) => damage['_id'] == id);
        _total--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Damage road deleted successfully!'),
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
    _getListDamageRoad();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _damageRoads == null
          ? const Center(child: CircularProgressIndicator())
          : _damageRoads!.isEmpty
          ? const Center(child: Text('No damage roads available'))
          : RefreshIndicator(
        onRefresh: _getListDamageRoad,
        child: ListView.builder(
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
                  color:  Colors.white,
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
                            'Date Damage: ${DateFormat('yyyy-MM-dd HH:mm:ss ').format(DateTime.parse(damage['createdAt']))} ',
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
                                  onUpdate: _getListDamageRoad,
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
                                content: const Text('Bạn có chắc chắn muốn xóa đoạn ngập lụt này không?'),
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
                content: Text('Total number of maintain damages: $_total'),
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
