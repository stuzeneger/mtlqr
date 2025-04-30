import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static String get endpointVerify => baseUrl + (dotenv.env['ENDPOINT_VERIFY'] ?? '');
  static String get endpointAuthorize => baseUrl + (dotenv.env['ENDPOINT_AUTHORIZE'] ?? '');
  static String get endpointDatabase => baseUrl + (dotenv.env['ENDPOINT_DATABASE'] ?? '');
  static String get endpointRequest => baseUrl + (dotenv.env['ENDPOINT_REQUEST'] ?? '');
  static String get baseRTHCode => (dotenv.env['BASE_RTH_CODE'] ?? '');
}