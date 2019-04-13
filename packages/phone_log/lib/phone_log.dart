import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// [PermissionStatus.granted] means that the permission is already granted.
/// [PermissionStatus.denied] means that the permission is not granted yet.
/// [PermissionStatus.deniedAndCannotRequest] means that the permission
/// request is denied previously and user has checked 'never ask again' check
/// box. In this case calling [requestPermission] method, the request
/// permission dialog would not pop up.
enum PermissionStatus { granted, denied, deniedAndCannotRequest }

/// Provide methods to access and fetch the phone log.
class PhoneLog {
  final MethodChannel _channel;

  static final PhoneLog _instance = new PhoneLog.private(
      const MethodChannel('github.com/jiajiabingcheng/phone_log'));

  /// Provides an instance of this class.
  factory PhoneLog() => _instance;

  @visibleForTesting
  PhoneLog.private(MethodChannel platformChannel) : _channel = platformChannel;

  /// Check a [permission] and return a [Future] of the [PermissionStatus].
  Future<PermissionStatus> checkPermission() async {
    final String status = await _channel.invokeMethod("checkPermission", null);
    return permissionMap[status];
  }

  /// Request a [permission] and return a [Future] of bool.
  Future<bool> requestPermission() async {
    final bool isGranted =
        await _channel.invokeMethod("requestPermission", null);
    return isGranted;
  }

  ///Fetches phone logs
  ///
  ///The unit of [startDate] is the Milliseconds of date.
  ///The unit of [duration] is second.
  Future<Iterable<CallRecord>> getPhoneLogs(
      {Int64 startDate, Int64 duration}) async {
    final String _startDate = startDate?.toString();
    final String _duration = duration?.toString();
    final List<dynamic> records = await _channel.invokeMethod(
        'getPhoneLogs',
        <String, String>{"startDate": _startDate, "duration": _duration});
    return records?.map((dynamic m) => new CallRecord.fromMap(m));
  }
}

Map<String, PermissionStatus> permissionMap = <String, PermissionStatus>{
  'granted': PermissionStatus.granted,
  'denied': PermissionStatus.denied,
  'deniedAndCannotRequest': PermissionStatus.deniedAndCannotRequest
};

/// The class that carries all the data for one call history entry.
class CallRecord {
  CallRecord({
    this.formattedNumber,
    this.number,
    this.callType,
    this.dateYear,
    this.dateMonth,
    this.dateDay,
    this.dateHour,
    this.dateMinute,
    this.dateSecond,
    this.duration,
  });

  String formattedNumber, number, callType;
  int dateYear, dateMonth, dateDay, dateHour, dateMinute, dateSecond, duration;

  CallRecord.fromMap(Map<String, Object> m) {
    formattedNumber = m['formattedNumber'];
    number = m['number'];
    callType = m['callType'];
    dateYear = m['dateYear'];
    dateMonth = m['dateMonth'];
    dateDay = m['dateDay'];
    dateHour = m['dateHour'];
    dateMinute = m['dateMinute'];
    dateSecond = m['dateSecond'];
    duration = m['duration'];
  }
}
