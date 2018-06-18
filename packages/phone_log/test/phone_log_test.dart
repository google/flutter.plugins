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

  setUp(() {
    mockChannel = new MockPlatformChannel();
    mockChannelForGetLogs = new MockPlatformChannel();

    when(mockChannel.invokeMethod(typed(any), any))
        .thenAnswer((Invocation invocation) {
      invokedMethod = invocation.positionalArguments[0];
      arguments = invocation.positionalArguments[1];
    });

    when(mockChannelForGetLogs.invokeMethod('getPhoneLogs', any))
        .thenReturn(new Future(() => [
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
  });

  group('Phone log plugin', () {
    test('fetch phone log', () async {
      PhoneLog.setChannel(mockChannelForGetLogs);

      var records = await PhoneLog.getPhoneLogs(
          startDate: new Int64(123456789), duration: new Int64(12));

      print(records);
      var record = records.first;

      expect(record.formattedNumber, '123 123 1234');
      expect(record.callType, 'INCOMING_TYPE');
      expect(record.number, '1231231234');
      expect(record.dateYear, 2018);
      expect(record.duration, 123);

      PhoneLog.setChannel(mockChannel);
      await PhoneLog.getPhoneLogs(
          startDate: new Int64(123456789), duration: new Int64(12));
      expect(invokedMethod, 'getPhoneLogs');
      expect(arguments, {'startDate': '123456789', 'duration': '12'});
    });

    test('check permission', () async {
      PhoneLog.setChannel(mockChannel);

      await PhoneLog.checkPermission();

      expect(invokedMethod, 'checkPermission');
      expect(arguments, null);
    });

    test('request permission', () async {
      PhoneLog.setChannel(mockChannel);

      await PhoneLog.requestPermission();

      expect(invokedMethod, 'requestPermission');
      expect(arguments, null);
    });
  });
}

class MockPlatformChannel extends Mock implements MethodChannel {}
