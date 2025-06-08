import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../ipconfig/ip.dart';
import '../model/user.dart';

class SignInService {
  static Future<Map<String, dynamic>> signIn(String email, String password) async {
    final Map<String, dynamic> requestBody = {
      "email": email,
      "password": password,
    };
    try {
      final response = await http.post(
        //Uri.parse('$ip/api/user/sign-in'),
        Uri.parse('$ip/user/sign-in'),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody;
      } else {
        print('Error: ${response.body}');
        return {'status': 'error', 'message': 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
  static Future<Map<String, dynamic>> signInWithGoogle(Map<String, dynamic> data) async {
    final url = Uri.parse('$ip/user/signin-google'); // <-- đảm bảo đúng route
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }
}

class SignUpService {
  static Future<Map<String, dynamic>> signUp(User user) async {
    final Map<String, dynamic> requestBody = {
      "name": user.name,
      "date": user.date,
      "email": user.email,
      "password": user.password,
      "confirmPassword": user.confirmPassword,
      "phone": user.phone,
    };


    try {
      final response = await http.post(
        //Uri.parse('$ip/api/user/sign-up'),
        Uri.parse('$ip/user/sign-up'),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody;
      } else {
        print('Error: ${response.statusCode}');
        return {'status': 'error', 'message': 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> signUpWithGoogle(Map<String, dynamic> user) async {
    var url = Uri.parse('$ip/user/signup-google');
    var response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(user),
    );
    return jsonDecode(response.body);
  }
}


class ForgotPasswordService {
  static Future<Map<String, dynamic>> sendEmail(String email) async {
    final Map<String, dynamic> requestBody = {
      "email": email,
    };
    print(email);
    try {
      final response = await http.post(
        Uri.parse('$ip/code/create-code'),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody;
      } else {
        print('Error: ${response.statusCode}');
        return {'status': 'error', 'message': 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class VerifyEmailService {
  static Future<Map<String, dynamic>> sendEmailVerify(String email) async {
    final Map<String, dynamic> requestBody = {
      "email": email,
    };
    print(email);
    try {
      final response = await http.post(
        Uri.parse('$ip/code/create-code-verify-email'),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody;
      } else {
        print('Error: ${response.statusCode}');
        return {'status': 'error', 'message': 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class ResendCodeService {
  static Future<Map<String, dynamic>> resendCode(String email) async {
    print(email);
    final Map<String, dynamic> requestBody = {
      "email": email,
    };

    try {
      final response = await http.post(
        Uri.parse('$ip/code/create-code'),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody;
      } else {
        print('Error: ${response.statusCode}');
        return {'status': 'error', 'message': 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class VerifyCodeService {
  static Future<Map<String, dynamic>> verifyCode(String id, String code) async {
    final Map<String, dynamic> requestBody = {
      "code": code,
    };
    try {
      final response = await http.post(
        Uri.parse('$ip/code/verify-code/$id'),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody;
      } else {
        print('Error: ${response.statusCode}');
        return {'status': 'error', 'message': 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class VerifyCodeEmailService {
  static Future<Map<String, dynamic>> verifyCodeEmail(String id, String code) async {
    final Map<String, dynamic> requestBody = {
      "code": code,
    };
    try {
      final response = await http.post(
        Uri.parse('$ip/code/verify-code-email/$id'),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody;
      } else {
        print('Error: ${response.statusCode}');
        return {'status': 'error', 'message': 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class ResetPassService {
  static Future<Map<String, dynamic>> resetPass(String idUser, String password, String confirmPassword) async {
    print(idUser);
    print(password);
    final Map<String, dynamic> requestBody = {
      "password": password,
      "confirmPassword": confirmPassword,
    };
    var url = '$ip/code/reset-password/$idUser';
    print(url);
    try {
      final response = await http.post(
        Uri.parse(url),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody;
      } else {
        print('Error: ${response.statusCode}');
        return {'status': 'error', 'message': 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class DecodeTokenService {
  static Future<Map<String, dynamic>> decodeToken(String token) async {
    final Map<String, dynamic> requestBody = {
      "token": token,
    };
   // var url = '$ip/api/user/send-token';
    var url = '$ip/user/send-token';
    print(url);
    try {
      final response = await http.post(
        Uri.parse(url),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody;
      } else {
        print('Error: ${response.statusCode}');
        return {'status': 'error', 'message': 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class LogoutService {
  static Future<Map<String, dynamic>> logout(String token) async {
    final Map<String, dynamic> requestBody = {
      "token": token,
    };
   // var url = '$ip/api/user/log-out';
    var url = '$ip/user/log-out';
    print(url);
    try {
      final response = await http.post(
        Uri.parse(url),
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody;
      } else {
        print('Error: ${response.statusCode}');
        return {'status': 'error', 'message': 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class UpdateUserService {
  static Future<Map<String, dynamic>> updateUser(
      String userID, String token, String name, String phone, String date,
      {String? oldPassword, String? newPassword}) async {
    final url = Uri.parse('$ip/user/update-user/$userID');
    final body = {
      if (name.isNotEmpty) 'name': name,
      if (phone.isNotEmpty) 'phone': phone,
      if (date.isNotEmpty) 'date': date,
      if (oldPassword != null && oldPassword.isNotEmpty) 'oldPassword': oldPassword,
      if (newPassword != null && newPassword.isNotEmpty) 'newPassword': newPassword,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'token': 'Bearer $token',
        },
        body: json.encode(body),
      );

      final decodedResponse = json.decode(response.body);

      if (response.statusCode == 200 && decodedResponse['status'] == 'OK') {
        return {'status': 'success', 'message': decodedResponse['message']};
      } else {
        return {'status': 'error', 'message': decodedResponse['message'] ?? 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class GetUserDetailService {
  static Future<Map<String, dynamic>> getUserDetail(String id, String token) async {
    final url = Uri.parse('$ip/user/get-detail/$id');
    try {
      final response = await http.get(
        url,
        headers: {
          'token': 'Bearer $token', // Thêm header token
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['status'] == 'OK') {
          print('User details: ${responseBody['user']}');
          return {
            'status': 'success',
            'user': responseBody['user'], // Trả về thông tin người dùng
          };
        } else {
          return {
            'status': 'error',
            'message': responseBody['message'] ?? 'Failed to get user details',
          };
        }
      } else if (response.statusCode == 404) {
        final responseBody = jsonDecode(response.body);
        return {
          'status': 'error',
          'message': responseBody['message'] ?? 'Unauthorized',
        };
      } else {
        print('Error: ${response.statusCode}');
        return {'status': 'error', 'message': 'Server error'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}
