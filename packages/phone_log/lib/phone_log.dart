import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Provide methods to access and fetch the phone log.
class PhoneLog {
  final MethodChannel _channel;

  static final PhoneLog _instance = new PhoneLog.private(
      const MethodChannel('github.com/jiajiabingcheng/phone_log'));

  /// Provides an instance of this class.
  factory PhoneLog() => _instance;

  @visibleForTesting
  PhoneLog.private(MethodChannel platformChannel):_channel = platformChannel;

  /// Check a [permission] and return a [Future] with the result
  Future<bool> checkPermission() async {
    final bool isGranted = await _channel.invokeMethod("checkPermission", null);
    return isGranted;
  }

  /// Request a [permission] and return a [Future] with the result
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
    var _startDate = startDate?.toString();
    var _duration = duration?.toString();
    Iterable records = await _channel.invokeMethod(
        'getPhoneLogs', {"startDate": _startDate, "duration": _duration});
    return records?.map((m) => new CallRecord.fromMap(m));
  }
}

/// The class that carries all the data for one call history entry.
class CallRecord {
  CallRecord({
    this.formattedNumber,
    this.number,
    this.callType,
    this.dateYear,
    this.dateMonth,
    this.dateHour,
    this.dateMinute,
    this.dateSecond,
    this.duration,
  });

  String formattedNumber, number, callType;
  int dateYear, dateMonth, dateDay, dateHour, dateMinute, dateSecond, duration;

  CallRecord.fromMap(Map m) {
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
