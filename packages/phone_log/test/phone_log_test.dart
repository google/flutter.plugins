import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:phone_log/phone_log.dart';

void main() {
  String invokedMethod;
  dynamic arguments;
  MockPlatformChannel mockChannel;
  MockPlatformChannel mockChannelForGetLogs;
  MockPlatformChannel mockChannelForGranted;
  MockPlatformChannel mockChannelForDenied;
  MockPlatformChannel mockChannelForDeniedCannotRequest;

  setUp(() {
    mockChannel = new MockPlatformChannel();
    mockChannelForGetLogs = new MockPlatformChannel();
    mockChannelForGranted = new MockPlatformChannel();
    mockChannelForDenied = new MockPlatformChannel();
    mockChannelForDeniedCannotRequest = new MockPlatformChannel();

    when(mockChannel.invokeMethod(any, any))
        .thenAnswer((Invocation invocation) {
      invokedMethod = invocation.positionalArguments[0];
      arguments = invocation.positionalArguments[1];
      return null;
    });

    when(mockChannelForGetLogs.invokeMethod('getPhoneLogs', any)).thenAnswer(
        (_) =>
            new Future<List<Map<String, Object>>>(() => <Map<String, Object>>[
                  <String, Object>{
                    'formattedNumber': '123 123 1234',
                    'number': '1231231234',
                    'callType': 'INCOMING_TYPE',
                    'dateYear': 2018,
                    'dateMonth': 6,
                    'dateDay': 15,
                    'dateHour': 3,
                    'dateMinute': 16,
                    'dateSecond': 23,
                    'duration': 123
                  }
                ]));

    when(mockChannelForGranted.invokeMethod('checkPermission', any))
        .thenAnswer((_) => new Future<String>(() => 'granted'));

    when(mockChannelForDenied.invokeMethod('checkPermission', any))
        .thenAnswer((_) => new Future<String>(() => 'denied'));

    when(mockChannelForDeniedCannotRequest.invokeMethod('checkPermission', any))
        .thenAnswer((_) => new Future<String>(() => 'deniedAndCannotRequest'));
  });

  group('Phone log plugin', () {
    test('fetch phone log', () async {
      final PhoneLog phoneLog = new PhoneLog.private(mockChannelForGetLogs);

      final Iterable<CallRecord> records = await phoneLog.getPhoneLogs(
          startDate: new Int64(123456789), duration: new Int64(12));

      print(records);
      final CallRecord record = records.first;

      expect(record.formattedNumber, '123 123 1234');
      expect(record.callType, 'INCOMING_TYPE');
      expect(record.number, '1231231234');
      expect(record.dateYear, 2018);
      expect(record.duration, 123);

      final PhoneLog phoneLogMethod = new PhoneLog.private(mockChannel);
      await phoneLogMethod.getPhoneLogs(
          startDate: new Int64(123456789), duration: new Int64(12));
      expect(invokedMethod, 'getPhoneLogs');
      expect(arguments,
          <String, String>{'startDate': '123456789', 'duration': '12'});
    });

    test('check permission', () async {
      final PhoneLog phoneLog = new PhoneLog.private(mockChannel);

      await phoneLog.checkPermission();

      expect(invokedMethod, 'checkPermission');
      expect(arguments, null);

      final PhoneLog phoneLogGranted =
          new PhoneLog.private(mockChannelForGranted);
      final PermissionStatus permissionGranted =
          await phoneLogGranted.checkPermission();

      expect(permissionGranted, PermissionStatus.granted);

      final PhoneLog phoneLogDenied =
          new PhoneLog.private(mockChannelForDenied);
      final PermissionStatus permissionDenied =
          await phoneLogDenied.checkPermission();

      expect(permissionDenied, PermissionStatus.denied);

      final PhoneLog phoneLogCannotRequest =
          new PhoneLog.private(mockChannelForDeniedCannotRequest);
      final PermissionStatus permissionCannotRequest =
          await phoneLogCannotRequest.checkPermission();

      expect(permissionCannotRequest, PermissionStatus.deniedAndCannotRequest);
    });

    test('request permission', () async {
      final PhoneLog phoneLog = new PhoneLog.private(mockChannel);

      await phoneLog.requestPermission();

      expect(invokedMethod, 'requestPermission');
      expect(arguments, null);
    });
  });
}

class MockPlatformChannel extends Mock implements MethodChannel {}
