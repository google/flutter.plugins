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

    when(mockChannel.invokeMethod(typed(any), any))
        .thenAnswer((Invocation invocation) {
      invokedMethod = invocation.positionalArguments[0];
      arguments = invocation.positionalArguments[1];
    });

    when(mockChannelForGetLogs.invokeMethod('getPhoneLogs', any))
        .thenAnswer((_) => new Future(() => [
              {
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
        .thenAnswer((_) => new Future(() => 'granted'));

    when(mockChannelForDenied.invokeMethod('checkPermission', any))
        .thenAnswer((_) => new Future(() => 'denied'));

    when(mockChannelForDeniedCannotRequest.invokeMethod('checkPermission', any))
        .thenAnswer((_) => new Future(() => 'deniedAndCannotRequest'));
  });

  group('Phone log plugin', () {
    test('fetch phone log', () async {
      var phoneLog = new PhoneLog.private(mockChannelForGetLogs);

      var records = await phoneLog.getPhoneLogs(
          startDate: new Int64(123456789), duration: new Int64(12));

      print(records);
      var record = records.first;

      expect(record.formattedNumber, '123 123 1234');
      expect(record.callType, 'INCOMING_TYPE');
      expect(record.number, '1231231234');
      expect(record.dateYear, 2018);
      expect(record.duration, 123);

      var phoneLogMethod = new PhoneLog.private(mockChannel);
      await phoneLogMethod.getPhoneLogs(
          startDate: new Int64(123456789), duration: new Int64(12));
      expect(invokedMethod, 'getPhoneLogs');
      expect(arguments, {'startDate': '123456789', 'duration': '12'});
    });

    test('check permission', () async {
      var phoneLog = new PhoneLog.private(mockChannel);

      await phoneLog.checkPermission();

      expect(invokedMethod, 'checkPermission');
      expect(arguments, null);

      var phoneLogGranted = new PhoneLog.private(mockChannelForGranted);
      var permissionGranted = await phoneLogGranted.checkPermission();

      expect(permissionGranted, PermissionStatus.granted);

      var phoneLogDenied = new PhoneLog.private(mockChannelForDenied);
      var permissionDenied = await phoneLogDenied.checkPermission();

      expect(permissionDenied, PermissionStatus.denied);

      var phoneLogCannotRequest = new PhoneLog.private(mockChannelForDeniedCannotRequest);
      var permissionCannotRequest = await phoneLogCannotRequest.checkPermission();

      expect(permissionCannotRequest, PermissionStatus.deniedAndCannotRequest);
    });

    test('request permission', () async {
      var phoneLog = new PhoneLog.private(mockChannel);

      await phoneLog.requestPermission();

      expect(invokedMethod, 'requestPermission');
      expect(arguments, null);
    });
  });
}

class MockPlatformChannel extends Mock implements MethodChannel {}
