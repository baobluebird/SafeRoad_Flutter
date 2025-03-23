import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../ipconfig/ip.dart';

class UploadService {
  static Future<Map<String, dynamic>> uploadImage(File image, String userId,
      String typeDetection, String location) async {
    try {
      print('anh 1: $image');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$ip/detection/create'),
      );

      request.files.add(await http.MultipartFile.fromPath('image', image!.path));
      request.fields['userId'] = userId;
      request.fields['typeDetection'] = typeDetection;
      request.fields['location'] = location;

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        var response = await streamedResponse.stream.bytesToString();
        var decodedResponse = json.decode(response);

        if (decodedResponse.containsKey('status') &&
            decodedResponse.containsKey('data') &&
            decodedResponse.containsKey('message') && decodedResponse.containsKey('image')) {
          return {
            'status': decodedResponse['status'],
            'data': decodedResponse['data'],
            'image': decodedResponse['image'],
            'message': decodedResponse['message']
          };
        } else {
          return {
            'status': decodedResponse['status'],
            'message': decodedResponse['message']
          };;
        }
      } else {
        return {'status': 'error', 'message': 'Non-200 status code'};
      }
    } catch (error) {
      print('Error: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}
