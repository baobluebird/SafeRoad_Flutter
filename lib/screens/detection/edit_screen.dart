import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pothole/services/detection_service.dart';

class EditScreen extends StatefulWidget {
  final dynamic item; // Đối tượng hole, crack hoặc maintain
  final String type; // 'hole', 'crack' hoặc 'maintain'
  final VoidCallback onUpdate;

  const EditScreen({
    Key? key,
    required this.item,
    required this.type,
    required this.onUpdate,
  }) : super(key: key);

  @override
  _EditScreenState createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _locationController;
  late TextEditingController _addressController;
  late TextEditingController _descriptionController;
  // Controller cho maintain
  late TextEditingController _sourceNameController;
  late TextEditingController _destinationNameController;
  late TextEditingController _locationAController;
  late TextEditingController _locationBController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  File? _imageFile;
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
    // Khởi tạo controller dựa trên type
    if (widget.type == 'maintain') {
      _sourceNameController = TextEditingController(text: widget.item['sourceName']);
      _destinationNameController = TextEditingController(text: widget.item['destinationName']);
      _locationAController = TextEditingController(text: widget.item['locationA']);
      _locationBController = TextEditingController(text: widget.item['locationB']);
      _startDateController = TextEditingController(text: widget.item['startDate']);
      _endDateController = TextEditingController(text: widget.item['endDate']);
      // Không sử dụng controller của hole/crack
      _locationController = TextEditingController();
      _addressController = TextEditingController();
      _descriptionController = TextEditingController();
    } else {
      _locationController = TextEditingController(text: widget.item['location']);
      _addressController = TextEditingController(text: widget.item['address']);
      _descriptionController = TextEditingController(text: widget.item['description']);
      // Không sử dụng controller của maintain
      _sourceNameController = TextEditingController();
      _destinationNameController = TextEditingController();
      _locationAController = TextEditingController();
      _locationBController = TextEditingController();
      _startDateController = TextEditingController();
      _endDateController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _sourceNameController.dispose();
    _destinationNameController.dispose();
    _locationAController.dispose();
    _locationBController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDateTime(TextEditingController controller, String initialDateTime, {bool isEndDate = false}) async {
    // Parse the initial date from the controller or item
    DateTime initial = DateTime.tryParse(initialDateTime) ?? DateTime.now();

    // For endDate, use startDate as the minimum allowed date
    DateTime firstDate = isEndDate
        ? (DateTime.tryParse(_startDateController.text) ?? DateTime.now())
        : DateTime(2000);

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );

      if (pickedTime != null) {
        final dateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        controller.text = dateTime.toIso8601String();
      }
    }
  }


  Future<void> _updateItem() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      Map<String, dynamic> response;
      if (widget.type == 'hole') {
        response = await UpdateHoleService.updateHole(
          id: widget.item['_id'],
          location: _locationController.text,
          address: _addressController.text,
          description: _descriptionController.text,
          image: _imageFile,
        );
      } else if (widget.type == 'crack') {
        response = await UpdateCrackService.updateCrack(
          id: widget.item['_id'],
          location: _locationController.text,
          address: _addressController.text,
          description: _descriptionController.text,
          image: _imageFile,
        );
      } else {
        response = await UpdateMaintainService.updateMaintain(
          id: widget.item['_id'],
          sourceName: _sourceNameController.text,
          destinationName: _destinationNameController.text,
          locationA: _locationAController.text,
          locationB: _locationBController.text,
          startDate: _startDateController.text,
          endDate: _endDateController.text,
        );
      }

      setState(() {
        _isLoading = false;
      });

      if (response['status'] == 'OK') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cập nhật ${widget.type == 'hole' ? 'ổ gà' : widget.type == 'crack' ? 'vết nứt' : 'đường bảo trì'} thành công!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUpdate();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${response['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chỉnh sửa ${widget.type == 'hole' ? 'ổ gà' : widget.type == 'crack' ? 'vết nứt' : 'đường bảo trì'}',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: widget.type == 'maintain'
                ? Column(
              children: [
                TextFormField(
                  controller: _sourceNameController,
                  decoration: const InputDecoration(labelText: 'Tên điểm xuất phát'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập tên điểm xuất phát';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _destinationNameController,
                  decoration: const InputDecoration(labelText: 'Tên điểm đích'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập tên điểm đích';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _locationAController,
                  decoration: const InputDecoration(labelText: 'Vị trí A (Tọa độ)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập vị trí A';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _locationBController,
                  decoration: const InputDecoration(labelText: 'Vị trí B (Tọa độ)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập vị trí B';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _startDateController,
                  decoration: const InputDecoration(
                    labelText: 'Ngày bắt đầu',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () => _selectDateTime(_startDateController, widget.item['startDate']),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng chọn ngày bắt đầu';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _endDateController,
                  decoration: const InputDecoration(
                    labelText: 'Ngày kết thúc',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () => _selectDateTime(_endDateController, widget.item['endDate'], isEndDate: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng chọn ngày kết thúc';
                    }
                    final startDate = DateTime.tryParse(_startDateController.text);
                    final endDate = DateTime.tryParse(value);
                    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
                      return 'Ngày kết thúc phải sau ngày bắt đầu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _updateItem,
                  child: const Text('Cập nhật'),
                ),
              ],
            )
                : Column(
              children: [
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Tọa độ (LatLng)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập tọa độ';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Địa chỉ'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập địa chỉ';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mô tả';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _imageFile != null
                    ? Image.file(
                  _imageFile!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                )
                    : widget.item['image'] != null
                    ? Image.network(
                  widget.item['image'],
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error),
                )
                    : const Text('Không có ảnh'),
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Chọn hình ảnh mới'),
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _updateItem,
                  child: const Text('Cập nhật'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}