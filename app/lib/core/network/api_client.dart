import 'package:dio/dio.dart';
import 'package:parkspot/core/config/app_config.dart';
import 'package:parkspot/core/constants/app_constants.dart';

/// Base options shared by the API client and the bare refresh client.
Dio createDio(AppConfig config) => Dio(
  BaseOptions(
    baseUrl: config.apiBaseUrl.toString(),
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
    contentType: Headers.jsonContentType,
  ),
);
