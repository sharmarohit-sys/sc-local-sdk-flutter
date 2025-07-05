import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:scgateway_flutter_plugin/scgateway_flutter_plugin.dart';
import 'app/global/SmartInvestingAppRepository.dart';
import 'app/global/SIConfigs.dart';

final _headers = <String, String>{
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT',
  'Accept': 'application/json',
  'content-type': 'application/json'
};

 SmartInvesting get smartInvesting {
  return SmartInvesting.fromEnvironment(repository.scGatewayConfig.value);
}

class SmartInvesting {
  final String baseUrl;

  const SmartInvesting.dev() : baseUrl = "https://api.dev.smartinvesting.io/";

  const SmartInvesting.staging()
      : baseUrl = "https://api-stag.smartinvesting.io/";

  const SmartInvesting.prod() : baseUrl = "https://api.smartinvesting.io/";

  factory SmartInvesting.fromEnvironment(ScGatewayConfig environment) {
    switch (environment.environment) {
      case GatewayEnvironment.DEVELOPMENT:
        return SmartInvesting.dev();
      case GatewayEnvironment.STAGING:
        return SmartInvesting.staging();
      default:
        return SmartInvesting.prod();
    }
  }
  
Future<Map<String, dynamic>> _requestData(String endpoint, String method, Map<String, dynamic> data) async {
  final Dio dio = Dio();
  dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));  // Log full request and response

  try {
    Response response;
    if (method == 'GET') {
      print("Sending GET request to: ${baseUrl + endpoint}");
      response = await dio.get(
        baseUrl + endpoint,
        options: Options(
          headers: _headers,
        ),
      );
    } else if (method == 'POST') {
      String bodyData = json.encode(data);
      print("Sending POST request to: ${baseUrl + endpoint} with body: $bodyData");
      response = await dio.post(
        baseUrl + endpoint,
        data: bodyData,
        options: Options(
          headers: _headers,
        ),
      );
    } else {
      throw Exception('Unsupported HTTP method: $method');
    }

    print("Response status code: ${response.statusCode}");
    if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
      return response.data;
    } else {
      print("Error response: ${response.statusCode} - ${response.data}");
      throw Exception('Error occurred: ${response.statusCode}');
    }
  } catch (e) {
    print("Error in _requestData: ${e.toString()}");
    throw Exception('Error occurred during network request');
  }
}

 
  Future<Map<String, dynamic>> _postData(String endpoint, Map<String, dynamic> data) async {
  return _requestData(endpoint, 'POST', data);
}

  Future<Map<String, dynamic>> _getData(String endpoint) async {
    return _requestData(endpoint, 'GET', {});
  }

  Future<Map<String, dynamic>> userLogin({String? userID}) async {
    Map<String, dynamic> data = {'id': userID};
    return _postData('user/login', data);
  }

  Future<String> getTransactionId(
    String userId,
    String? intent,
    Object? orderConfig, {
    Object? assetConfig,
    String? notes,
  }) async {
    Map<String, dynamic> data = {
      'id': userId,
      'intent': intent,
      'orderConfig': orderConfig,
      'assetConfig': assetConfig,
      'notes': notes,
    };
    var responseData = await _postData('transaction/new', data);
    return responseData["transactionId"] as String;
  }

Future<void> connectBroker(String userId, String authToken) async {
  Map<String, dynamic> data = {
    'id': userId,
    'smallcaseAuthToken': authToken,
  };

  try {
    var responseData = await _postData('user/connect', data);
    print("Connection successful: $responseData");
  } catch (error) {
    print("Error connecting broker: $error");
  }
}

    Future<List<String>> stockSearch(String query) async {
    var result = await _getData('search?text=$query');
    return (result['results'] as List)
      .map((result) => result['stock']['info']['ticker'] as String)
      .toList();
  }

  Future<String> getPostBackStatus(String transactionId) async {
    var responseData = await _getData('transaction/response?transactionId=$transactionId');
    return responseData.toString();
  }

 Future<String> getUserHoldings(String userId, int version, {bool mfEnabled = false}) async {
  try {
    var responseData = await _getData('holdings/fetch?id=$userId&version=v$version&mfHoldings=$mfEnabled');
    return responseData.toString();
  } catch (e) {
    print("Error in getUserHoldings: ${e.toString()}");
    throw Exception('Failed to get holdings');
  }
}

  @override
  String toString() {
    return "SmartInvesting(baseUrl: $baseUrl)";
  }
}
