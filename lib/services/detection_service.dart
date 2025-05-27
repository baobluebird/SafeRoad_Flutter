import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

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

class getListMaintainService {
  static Future<Map<String, dynamic>> getListMaintain() async {
    try {
      final response = await http.get(Uri.parse('$ip/detection/get-maintain-road'));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded.containsKey('data')) {
          return {
            'status': 'OK',
            'data': decoded['data'],
          };
        } else {
          return {'status': 'error', 'message': 'Invalid format'};
        }
      } else {
        return {'status': 'error', 'message': 'Non-200 status code'};
      }
    } catch (e) {
      print('Error fetching maintain data: $e');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class getListMaintainForMapService {
  static Future<Map<String, dynamic>> getListMaintainForMap() async {
    try {
      final response = await http.get(Uri.parse('$ip/detection/get-maintain-road-for-map'));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded.containsKey('data')) {
          return {
            'status': 'OK',
            'data': decoded['data'],
          };
        } else {
          return {'status': 'error', 'message': 'Invalid format'};
        }
      } else {
        return {'status': 'error', 'message': 'Non-200 status code'};
      }
    } catch (e) {
      print('Error fetching maintain data: $e');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class getListDamageForMapService {
  static Future<Map<String, dynamic>> getListDamageForMap() async {
    try {
      final response = await http.get(Uri.parse('$ip/detection/get-damage-road'));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded.containsKey('data')) {
          return {
            'status': 'OK',
            'data': decoded['data'],
          };
        } else {
          return {'status': 'error', 'message': 'Invalid format'};
        }
      } else {
        return {'status': 'error', 'message': 'Non-200 status code'};
      }
    } catch (e) {
      print('Error fetching maintain data: $e');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class deleteDetectionService {
  static Future<Map<String, dynamic>> deleteDetection(String detectionId, String nameList) async {
    try {
      String url;
      if (nameList == 'Hole') {
        url = '$ip/detection/delete-hole/$detectionId';
      } else if (nameList == 'Crack') {
        url = '$ip/detection/delete-crack/$detectionId';
      }else if (nameList == 'Damage') {
        url = '$ip/detection/delete-damage/$detectionId';
      } else {
        url = '$ip/detection/delete-maintain/$detectionId';
      }

      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        return {'status': 'OK', 'message': 'Deleted successfully'};
      } else {
        return {'status': 'error', 'message': 'Failed with status ${response.statusCode}'};
      }
    } catch (e) {
      print('Delete error: $e');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class DetectionCoordinateService {
  static Future<Map<String, dynamic>> getDetectionCoordinates() async {
    try {
      final response = await http.get(Uri.parse('$ip/detection/get-detection'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'status': 'OK',
          'latLongSmallHole': data['latLongSmallHole'],
          'latLongLargeHole': data['latLongLargeHole'],
          'latLongSmallCrack': data['latLongSmallCrack'],
          'latLongLargeCrack': data['latLongLargeCrack'],
        };
      } else {
        return {'status': 'error', 'message': 'Failed to load detection data'};
      }
    } catch (e) {
      print('Error fetching detection coordinates: $e');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}


class UpdateHoleService {
  static Future<Map<String, dynamic>> updateHole({
    required String id,
    required String location,
    required String address,
    required String description,
    File? image,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$ip/detection/update-hole/$id'),
      );

      // Add form fields
      request.fields['location'] = location;
      request.fields['address'] = address;
      request.fields['description'] = description;

      // Add image file if provided
      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          image.path,
        ));
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var decodedResponse = json.decode(responseBody);
      print(decodedResponse);

      if (response.statusCode == 200) {
        if (decodedResponse.containsKey('status') &&
            decodedResponse.containsKey('message')) {
          return {
            'status': decodedResponse['status'],
            'message': decodedResponse['message'],
          };
        } else {
          return {'status': 'error', 'message': 'Unexpected response format'};
        }
      } else {
        return {
          'status': 'error',
          'message': 'Failed with status ${response.statusCode}',
        };
      }
    } catch (error) {
      print('Error updating hole: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class UpdateCrackService {
  static Future<Map<String, dynamic>> updateCrack({
    required String id,
    required String location,
    required String address,
    required String description,
    File? image,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$ip/detection/update-crack/$id'),
      );

      // Add form fields
      request.fields['location'] = location;
      request.fields['address'] = address;
      request.fields['description'] = description;

      // Add image file if provided
      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          image.path,
        ));
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var decodedResponse = json.decode(responseBody);

      if (response.statusCode == 200) {
        if (decodedResponse.containsKey('status') &&
            decodedResponse.containsKey('message')) {
          return {
            'status': decodedResponse['status'],
            'message': decodedResponse['message'],
          };
        } else {
          return {'status': 'error', 'message': 'Unexpected response format'};
        }
      } else {
        return {
          'status': 'error',
          'message': 'Failed with status ${response.statusCode}',
        };
      }
    } catch (error) {
      print('Error updating crack: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class UpdateMaintainService {
  static Future<Map<String, dynamic>> updateMaintain({
    required String id,
    required String sourceName,
    required String destinationName,
    required String locationA,
    required String locationB,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$ip/detection/update-maintain/$id'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'sourceName': sourceName,
          'destinationName': destinationName,
          'locationA': locationA,
          'locationB': locationB,
          'startDate': startDate,
          'endDate': endDate,
        }),
      );

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        if (decodedResponse.containsKey('status') &&
            decodedResponse.containsKey('message')) {
          return {
            'status': decodedResponse['status'],
            'message': decodedResponse['message'],
          };
        } else {
          return {'status': 'error', 'message': 'Unexpected response format'};
        }
      } else {
        return {
          'status': 'error',
          'message': 'Failed with status ${response.statusCode}',
        };
      }
    } catch (error) {
      print('Error updating maintain road: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

class UpdateDamageService {
  static Future<Map<String, dynamic>> updateDamage({
    required String id,
    required String name,
    required String sourceName,
    required String destinationName,
    required String locationA,
    required String locationB,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$ip/detection/update-damage/$id'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'sourceName': sourceName,
          'destinationName': destinationName,
          'locationA': locationA,
          'locationB': locationB,
        }),
      );

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        if (decodedResponse.containsKey('status') &&
            decodedResponse.containsKey('message')) {
          return {
            'status': decodedResponse['status'],
            'message': decodedResponse['message'],
          };
        } else {
          return {'status': 'error', 'message': 'Unexpected response format'};
        }
      } else {
        return {
          'status': 'error',
          'message': 'Failed with status ${response.statusCode}',
        };
      }
    } catch (error) {
      print('Error updating maintain road: $error');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}

