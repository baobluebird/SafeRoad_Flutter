import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/user_service.dart';

class ProfileUserScreen extends StatefulWidget {
  const ProfileUserScreen({super.key});

  @override
  State<ProfileUserScreen> createState() => _ProfileUserScreenState();
}

class _ProfileUserScreenState extends State<ProfileUserScreen> {
  late Future<Map<String, dynamic>> _userDetailsFuture;
  String? userId;
  String? token;
  final Box<dynamic> myBox = Hive.box('myBox');
  bool _isEditing = false;

  // Controllers để chỉnh sửa thông tin
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  File? _selectedImage;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    userId = myBox.get('userId');
    token = myBox.get('token');

    if (userId != null && token != null) {
      setState(() {
        _userDetailsFuture = GetUserDetailService.getUserDetail(
          userId!,
          token!,
        );
      });
    } else {
      setState(() {
        _userDetailsFuture = Future.value({
          'status': 'error',
          'message': 'User not logged in or missing data',
        });
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = picked.toIso8601String();
      });
    }
  }

  Future<void> _updateUser() async {
    // Chỉ gửi các trường đã chỉnh sửa, các trường không chỉnh sửa để là null
    final String? updatedName =
    _nameController.text.isNotEmpty ? _nameController.text : null;
    final String? updatedPhone =
    _phoneController.text.isNotEmpty ? _phoneController.text : null;
    final String? updatedDate =
    _dateController.text.isNotEmpty ? _dateController.text : null;

    // Kiểm tra ít nhất một trường được chỉnh sửa
    if (updatedName == null && updatedPhone == null && updatedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please edit at least one field to update'),
        ),
      );
      return;
    }

    final result = await UpdateUserService.updateUser(
      userId!,
      token!,
      updatedName ?? '',
      updatedPhone ?? '',
      updatedDate ?? '',
    );

    if (result['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
        ),
      );
      // Làm mới dữ liệu
      setState(() {
        _isEditing = false;
        _selectedImage = null;
        _selectedDate = null;
        _nameController.clear();
        _phoneController.clear();
        _dateController.clear();
        _userDetailsFuture = GetUserDetailService.getUserDetail(
          userId!,
          token!,
        );
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'])));
    }
  }

  Future<void> _changePassword() async {
    if (_oldPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Old password and new password are required'),
        ),
      );
      return;
    }

    final result = await UpdateUserService.updateUser(
      userId!,
      token!,
      '', // Không chỉnh sửa name
      '', // Không chỉnh sửa phone
      '', // Không chỉnh sửa date
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (result['status'] == 'success') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'])));
      setState(() {
        _oldPasswordController.clear();
        _newPasswordController.clear();
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'])));
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _selectedImage = null;
      _selectedDate = null;
      _nameController.clear();
      _phoneController.clear();
      _dateController.clear();
      _loadUserData().then((_) {
        if (_userDetailsFuture != null) {
          (_userDetailsFuture as Future<Map<String, dynamic>>).then((data) {
            final user = data['user'] as Map<String, dynamic>;
            _nameController.text = user['name'] ?? '';
            _phoneController.text = user['phone'] ?? '';
            _dateController.text = user['date'] ?? '';
            if (user['date'] != null) {
              _selectedDate = DateTime.tryParse(user['date']);
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dateController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _cancelEdit, // Nút hủy
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _updateUser();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!['status'] == 'error') {
            return Center(
              child: Text(
                snapshot.data?['message'] ?? 'Error loading profile',
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
            );
          } else {
            final user = snapshot.data!['user'] as Map<String, dynamic>;

            // Khởi tạo giá trị ban đầu cho các controller
            if (!_isEditing) {
              _nameController.text = user['name'] ?? '';
              _phoneController.text = user['phone'] ?? '';
              _dateController.text = user['date'] ?? '';
              if (user['date'] != null) {
                _selectedDate = DateTime.tryParse(user['date']);
              }
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ảnh đại diện
                    Center(
                      child: GestureDetector(
                        onTap: _isEditing ? _pickImage : null,
                        child: ClipOval(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              image: _selectedImage != null
                                  ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                                  : (user['avatarUrl'] != null
                                  ? DecorationImage(
                                image: NetworkImage(user['avatarUrl']),
                                fit: BoxFit.cover,
                              )
                                  : null),
                            ),
                            child: user['avatarUrl'] == null && _selectedImage == null
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Tên người dùng
                    _isEditing
                        ? TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    )
                        : Text(
                      'Name: ${user['name'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Email (không cho chỉnh sửa)
                    Text(
                      'Email: ${user['email'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    // Số điện thoại
                    _isEditing
                        ? TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    )
                        : Text(
                      'Phone: ${user['phone'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    // Ngày sinh
                    _isEditing
                        ? GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _dateController,
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    )
                        : Text(
                      'Date: ${user['date'] != null ? user['date'] : 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    // Phần đổi mật khẩu
                    if (_isEditing)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _oldPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'Old Password',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _newPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'New Password',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _changePassword,
                            child: const Text('Change Password'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    // Admin
                    Text(
                      'Admin: ${user['isAdmin'] ?? false ? 'Yes' : 'No'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
