// lib/config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get authBaseUrl =>
      dotenv.env['AUTH_BASE_URL'] ?? 'http://192.168.1.10:8080';
  static String get postBaseUrl =>
      dotenv.env['POST_BASE_URL'] ?? 'http://192.168.1.10:8080';
  static String get userBaseUrl =>
      dotenv.env['USER_BASE_URL'] ?? 'http://192.168.1.10:8080';
  static String get searchBaseUrl =>
      dotenv.env['SEARCH_BASE_URL'] ?? 'http://192.168.1.10:8080';
  static String get xApiKey => dotenv.env['X_API_KEY'] ?? 'dev-api-key';
  static String get apiVersion =>
      dotenv.env['NEXT_PUBLIC_API_VERSION'] ?? '/api/v1';
}
