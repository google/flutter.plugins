import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';

/// [PermissionStatus.granted] means that the permission is already granted.
/// [PermissionStatus.denied] means that the permission is not granted yet.
/// [PermissionStatus.deniedAndCannotRequest] means that the permission
/// request is denied previously and user has checked 'never ask again' check
/// box. In this case calling [requestPermission] method, the request
/// permission dialog would not pop up.
enum PermissionStatus { granted, denied, deniedAndCannotRequest }

const MethodChannel channel =
    MethodChannel('github.com/jiajiabingcheng/phone_log');

/// Provide methods to access and fetch the phone log.
class PhoneLog {
  /// Provides an instance of this class.
  const PhoneLog();

  /// Check a [permission] and return a [Future] of the [PermissionStatus].
  Future<PermissionStatus> checkPermission() async {
    final String status =
        await channel.invokeMethod<String>("checkPermission", null);
    return permissionMap[status];
  }

  /// Request a [permission] and return a [Future] of bool.
  Future<bool> requestPermission() async {
    final bool isGranted =
        await channel.invokeMethod<bool>("requestPermission", null);
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

    final Iterable<Map<dynamic, dynamic>> records = (
        await channel.invokeMethod<List<Map<String, dynamic>>>(
            'getPhoneLogs',
            <String, String>{"startDate": _startDate, "duration": _duration})
    )
        ?.cast<Map<dynamic, dynamic>>();
    return records?.map((Map<dynamic, dynamic> m) =>
        new CallRecord.fromMap(m.cast<String, Object>()));
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
    this.dialedNumber,
    this.callType,
    this.dateYear,
    this.dateMonth,
    this.dateDay,
    this.dateHour,
    this.dateMinute,
    this.dateSecond,
    this.duration,
    this.dialedNumber,
  });

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
    dialedNumber = m['dialedNumber'];
  }

  String formattedNumber, number, dialedNumber, callType;
  int dateYear, dateMonth, dateDay, dateHour, dateMinute, dateSecond, duration;
}
