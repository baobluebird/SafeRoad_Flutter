import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../ipconfig/ip.dart';

class getListHolesService {
  static Future<Map<String, dynamic>> getListHoles() async {
    try {
      var response = await http.get(
        Uri.parse('$ip/detection/get-list-holes'),
      );

      if (response.statusCode == 200) {
        var decodedResponse = json.decode(response.body);

        if (decodedResponse.containsKey('status') &&
            decodedResponse.containsKey('total') &&
            decodedResponse.containsKey('data') &&
            decodedResponse.containsKey('message') ) {
          return {
            'status': decodedResponse['status'],
            'total': decodedResponse['total'],
            'data': decodedResponse['data'],
            'message': decodedResponse['message']
          };
        } else {
            print('data null');
          return {'status': 'OK', 'data': 'null'};
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

class getListCracksService {
  static Future<Map<String, dynamic>> getListCracks() async {
    try {
      var response = await http.get(
        Uri.parse('$ip/detection/get-list-crack'),
      );

      if (response.statusCode == 200) {
        var decodedResponse = json.decode(response.body);

        if (decodedResponse.containsKey('status') &&
            decodedResponse.containsKey('total') &&
            decodedResponse.containsKey('data') &&
            decodedResponse.containsKey('message') ) {
          return {
            'status': decodedResponse['status'],
            'total': decodedResponse['total'],
            'data': decodedResponse['data'],
            'message': decodedResponse['message']
          };
        } else {
          print('data null');
          return {'status': 'OK', 'data': 'null'};
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
class getDetailHoleService {
  static Future<Map<String, dynamic>> getDetailHole(String id) async {
    try {
      var response = await http.get(
        Uri.parse('$ip/detection/get-detail-hole/$id'),
      );

      if (response.statusCode == 200) {
        var decodedResponse = json.decode(response.body);

        if (decodedResponse.containsKey('status') &&
            decodedResponse.containsKey('data') && decodedResponse.containsKey('image') &&
            decodedResponse.containsKey('message') ) {
          return {
            'status': decodedResponse['status'],
            'data': decodedResponse['data'],
            'image': decodedResponse['image'],
            'message': decodedResponse['message']
          };
        } else {
          return {'status': 'error', 'message': 'Unexpected response format'};
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

class getDetailCrackService {
  static Future<Map<String, dynamic>> getDetailCrack(String id) async {
    try {
      var response = await http.get(
        Uri.parse('$ip/detection/get-detail-crack/$id'),
      );

      if (response.statusCode == 200) {
        var decodedResponse = json.decode(response.body);

        if (decodedResponse.containsKey('status') &&
            decodedResponse.containsKey('data') && decodedResponse.containsKey('image') &&
            decodedResponse.containsKey('message') ) {
          return {
            'status': decodedResponse['status'],
            'data': decodedResponse['data'],
            'image': decodedResponse['image'],
            'message': decodedResponse['message']
          };
        } else {
          return {'status': 'error', 'message': 'Unexpected response format'};
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



