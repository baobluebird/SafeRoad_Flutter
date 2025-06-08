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
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Added for LatLng

class SearchScreen extends StatefulWidget {
  final bool isAdmin;
  const SearchScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'hole'; // Default type
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

  Future<void> _getDetailHole(String id) async {
    final response = await getDetailHoleService.getDetailHole(id);
    if (response['status'] == 'OK') {
      final detectionData = response['data'];
      final detection = Detection.fromJson(detectionData);
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
        SnackBar(content: Text('Lỗi: ${response['message']}')),
      );
    }
  }

  Future<void> _getDetailCrack(String id) async {
    final response = await getDetailCrackService.getDetailCrack(id);
    if (response['status'] == 'OK') {
      final detectionData = response['data'];
      final detection = Detection.fromJson(detectionData);
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
        SnackBar(content: Text('Lỗi: ${response['message']}')),
      );
    }
  }

  Widget _buildListItem(dynamic item) {
    if (_selectedType == 'hole' || _selectedType == 'crack') {
      return ListTile(
        title: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.blueAccent, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['address'] ?? 'Không có địa chỉ',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(fontSize: 13, color: Colors.black),
                ),
              ),
              Text(
                'Loại: ${item['name']}',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(
                    fontSize: 13,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Mô tả: ${item['description'] ?? 'Không có mô tả'}',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(fontSize: 13, color: Colors.black),
                ),
              ),
              Text(
                'Tạo: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(item['createdAt']))}',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(
                    fontSize: 13,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          if (_selectedType == 'hole') {
            _getDetailHole(item['_id']);
          } else {
            _getDetailCrack(item['_id']);
          }
        },
      );
    } else if (_selectedType == 'damage') {
      return ListTile(
        title: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.blueAccent, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'] ?? 'Không có tên',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(
                    fontSize: 13,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Nguồn: ${item['sourceName'] ?? 'Không có nguồn'}',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(fontSize: 13, color: Colors.black),
                ),
              ),
              Text(
                'Đích: ${item['destinationName'] ?? 'Không có đích'}',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(fontSize: 13, color: Colors.black),
                ),
              ),
              Text(
                'Tạo: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(item['createdAt']))}',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(
                    fontSize: 13,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        onTap: () {
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
        },
      );
    } else {
      // maintain
      return ListTile(
        title: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.blueAccent, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nguồn: ${item['sourceName'] ?? ''}',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(fontSize: 13, color: Colors.black),
                ),
              ),
              Text(
                'Đích: ${item['destinationName'] ?? ''}',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(fontSize: 13, color: Colors.black),
                ),
              ),
              Text(
                'Số ngày bảo trì: ${item['dateMaintain']}',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(
                    fontSize: 13,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Từ: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(item['startDate']))} - '
                    'Đến: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(item['endDate']))}',
                style: GoogleFonts.beVietnamPro(
                  textStyle: const TextStyle(fontSize: 13, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
        onTap: () {
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
        },
      );
    }
  }

  LatLng _parseLatLng(String latLngString) {
    if (latLngString.isEmpty) return const LatLng(0, 0);
    try {
      final parts = latLngString.replaceAll('LatLng(', '').replaceAll(')', '').split(',');
      return LatLng(double.parse(parts[0].trim()), double.parse(parts[1].trim()));
    } catch (e) {
      print('Error parsing LatLng: $e');
      return const LatLng(0, 0); // Fallback coordinates
    }
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<String>(
              value: _selectedType,
              isExpanded: true, // Make dropdown fill available width
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
              hint: Text('Chọn loại', style: GoogleFonts.beVietnamPro()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '(Exams: 44 Gò Nảy 8, 2025-03, Large)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_searchController.text),
                ),
              ),
              onSubmitted: (value) => _search(value),
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