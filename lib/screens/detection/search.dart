import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pothole/ipconfig/ip.dart';
import 'package:pothole/model/detection.dart';
import 'package:pothole/screens/detection/damage_detail.dart';
import 'package:pothole/screens/detection/detection_for_detail.dart';
import 'package:pothole/screens/detection/road_detail.dart';
import 'package:pothole/services/detection_service.dart';
import 'package:pothole/screens/detection/edit_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SearchScreen extends StatefulWidget {
  final bool isAdmin;
  const SearchScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'hole';
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String searchTerm) async {
    if (searchTerm.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập từ khóa tìm kiếm';
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$ip/detection/search-list-detection?type=$_selectedType&term=$searchTerm'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _searchResults = data['data'];
            _errorMessage = _searchResults.isEmpty ? 'Không tìm thấy kết quả' : null;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Lỗi khi tìm kiếm';
            _searchResults = [];
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Lỗi server: ${response.statusCode}';
          _searchResults = [];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi: $e';
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(String id, String type) async {
    String endpoint = '';
    switch (type) {
      case 'hole':
        endpoint = 'delete-hole';
        break;
      case 'crack':
        endpoint = 'delete-crack';
        break;
      case 'maintain':
        endpoint = 'delete-maintain';
        break;
      case 'damage':
        endpoint = 'delete-damage';
        break;
    }

    final response = await http.delete(Uri.parse('$ip/detection/$endpoint/$id'));

    if (response.statusCode == 200) {
      setState(() {
        _searchResults.removeWhere((item) => item['_id'] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xóa thành công!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xóa thất bại!'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _getDetailHole(String id) async {
    final response = await getDetailHoleService.getDetailHole(id);
    if (response['status'] == 'OK') {
      final detection = Detection.fromJson(response['data']);
      String? imageData = response['image'];
      if (imageData != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetectionForDetailScreen(detection: detection, imageData: imageData),
          ),
        );
      }
    }
  }

  Future<void> _getDetailCrack(String id) async {
    final response = await getDetailCrackService.getDetailCrack(id);
    if (response['status'] == 'OK') {
      final detection = Detection.fromJson(response['data']);
      String? imageData = response['image'];
      if (imageData != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetectionForDetailScreen(detection: detection, imageData: imageData),
          ),
        );
      }
    }
  }

  LatLng _parseLatLng(String latLngString) {
    if (latLngString.isEmpty) return const LatLng(0, 0);
    try {
      final parts = latLngString.replaceAll('LatLng(', '').replaceAll(')', '').split(',');
      return LatLng(double.parse(parts[0].trim()), double.parse(parts[1].trim()));
    } catch (_) {
      return const LatLng(0, 0);
    }
  }

  Widget _buildListItem(dynamic item) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedType == 'hole') {
                  _getDetailHole(item['_id']);
                } else if (_selectedType == 'crack') {
                  _getDetailCrack(item['_id']);
                } else if (_selectedType == 'damage') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DamageRoadDetailScreen(
                        name: item['name'] ?? '',
                        sourceName: item['sourceName'] ?? '',
                        destinationName: item['destinationName'] ?? '',
                        locationA: _parseLatLng(item['locationA'] ?? ''),
                        locationB: _parseLatLng(item['locationB'] ?? ''),
                        dateDamage: item['createdAt'],
                      ),
                    ),
                  );
                } else if (_selectedType == 'maintain') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MaintainRoadDetailScreen(
                        sourceName: item['sourceName'] ?? '',
                        destinationName: item['destinationName'] ?? '',
                        locationA: _parseLatLng(item['locationA'] ?? ''),
                        locationB: _parseLatLng(item['locationB'] ?? ''),
                        dateMaintain: item['dateMaintain'],
                        startDate: item['startDate'],
                        endDate: item['endDate'],
                      ),
                    ),
                  );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedType == 'hole' || _selectedType == 'crack') ...[
                    Text('Địa chỉ: ${item['address'] ?? 'Không có'}'),
                    Text('Loại: ${item['name'] ?? ''}', style: const TextStyle(color: Colors.red)),
                    Text('Mô tả: ${item['description'] ?? 'Không có'}'),
                  ] else if (_selectedType == 'damage') ...[
                    Text('Tên: ${item['name'] ?? ''}', style: const TextStyle(color: Colors.red)),
                    Text('Nguồn: ${item['sourceName'] ?? ''}'),
                    Text('Đích: ${item['destinationName'] ?? ''}'),
                  ] else if (_selectedType == 'maintain') ...[
                    Text('Nguồn: ${item['sourceName'] ?? ''}'),
                    Text('Đích: ${item['destinationName'] ?? ''}'),
                    Text('Số ngày bảo trì: ${item['dateMaintain']}'),
                    Text('Từ: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(item['startDate']))} '
                        '- Đến: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(item['endDate']))}'),
                  ],
                  Text(
                    'Tạo: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(item['createdAt']))}',
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isAdmin)
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditScreen(
                          item: item,
                          type: _selectedType,
                          onUpdate: () => _search(_searchController.text),
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Xác nhận xóa'),
                        content: const Text('Bạn có chắc chắn muốn xóa mục này không?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
                        ],
                      ),
                    );
                    if (confirm == true) await _deleteItem(item['_id'], _selectedType);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isAdmin
          ? null
          : AppBar(
        title: Text('Tìm kiếm', style: GoogleFonts.beVietnamPro()),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'hole', child: Text('Ổ gà')),
                DropdownMenuItem(value: 'crack', child: Text('Vết nứt')),
                DropdownMenuItem(value: 'maintain', child: Text('Bảo trì')),
                DropdownMenuItem(value: 'damage', child: Text('Sự cố')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                  _searchResults = [];
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '(VD: 44 Gò Nảy 8, 2025-03, Large)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_searchController.text),
                ),
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(child: Text(_errorMessage!, style: GoogleFonts.beVietnamPro())),
            if (_searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) => _buildListItem(_searchResults[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
