import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/nursery_model.dart';
import '../models/observation_payload.dart';
import '../models/review_item_model.dart';

class ApiService {
  final ApiClient _apiClient;

  ApiService(this._apiClient);

  Uri _buildUri(String endpoint) {
    return Uri.parse('${AppConfig.baseUrl}$endpoint');
  }

  Future<Map<String, dynamic>> fetchStatsTelemetry() async {
    try {
      final response = await _apiClient.get(_buildUri(ApiEndpoints.telemetry));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch telemetry: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during fetchStatsTelemetry: $e');
    }
  }

  Future<List<NurseryModel>> fetchNurseries() async {
    try {
      final response = await _apiClient.get(_buildUri(ApiEndpoints.listNurseries));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => NurseryModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch nurseries: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during fetchNurseries: $e');
    }
  }

  Future<NurseryModel> submitNurserySignboard(String filePath) async {
    try {
      final uri = _buildUri(ApiEndpoints.uploadSignboard);
      var request = _apiClient.createMultipartRequest('POST', uri);
      
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return NurseryModel.fromJson(data);
      } else {
        throw Exception('Failed to submit signboard: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during submitNurserySignboard: $e');
    }
  }

  Future<NurseryModel> submitGeoTaggedNursery(
      String name, String? farmerName, double lat, double lng, String? phone1, String? phone2) async {
    try {
      final uri = _buildUri(ApiEndpoints.createManualNursery);
      final body = jsonEncode({
        'name': name,
        'farmer_name': farmerName,
        'latitude': lat,
        'longitude': lng,
        'phone1': phone1,
        'phone2': phone2,
      });

      final response = await _apiClient.post(uri, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return NurseryModel.fromJson(data);
      } else {
        throw Exception('Failed to submit geo-tagged nursery: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during submitGeoTaggedNursery: $e');
    }
  }

  Future<ReviewItemModel> sendObservationStream(ObservationPayload payload, String imagePath, bool autoApprove) async {
    try {
      final uri = _buildUri(ApiEndpoints.uploadObservation);
      var request = _apiClient.createMultipartRequest('POST', uri);

      request.fields['payload'] = jsonEncode(payload.toJson());
      request.fields['autoApprove'] = autoApprove.toString();
      
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ReviewItemModel.fromJson(data);
      } else {
        throw Exception('Failed to send observation stream: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during sendObservationStream: $e');
    }
  }

  Future<void> confirmStagedData(String reviewId, String plantName, String size, String bagSize) async {
    try {
      final uri = _buildUri(ApiEndpoints.confirmReview);
      final body = jsonEncode({
        'reviewId': reviewId,
        'plantName': plantName,
        'size': size,
        'bagSize': bagSize,
      });

      final response = await _apiClient.post(uri, body: body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to confirm data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during confirmStagedData: $e');
    }
  }
}
