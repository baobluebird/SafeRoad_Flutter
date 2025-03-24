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

class ResendCodeService {
  static Future<Map<String, dynamic>> resendCode(String email) async {
    print(email);
    final Map<String, dynamic> requestBody = {
      "email": email,
    };

    try {
      final response = await http.post(
        Uri.parse('$ip/code/resend-code'),
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
  static Future<Map<String, dynamic>> updateUser(String id, String name, File? image) async {

    final url = Uri.parse('$ip/user/update-user/$id');
    final request = http.MultipartRequest('POST', url);
    request.files.add(await http.MultipartFile.fromPath('image', image!.path));
    request.fields['name'] = name;

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final decodedResponse = json.decode(responseBody);
        return {'status':decodedResponse['status'], 'message': decodedResponse['message']};
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

