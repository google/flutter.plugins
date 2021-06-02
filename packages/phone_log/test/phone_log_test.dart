import 'package:fixnum/fixnum.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter/services.dart';
import 'package:test/test.dart';

import 'package:phone_log/phone_log.dart';

typedef Future<dynamic> Handler(MethodCall call);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  String invokedMethod;
  dynamic arguments;
  Handler mockChannel;
  Handler mockChannelForGetLogs;
  Handler mockChannelForGranted;
  Handler mockChannelForDenied;
  Handler mockChannelForDeniedCannotRequest;
  PhoneLog phoneLog;

  setUp(() {
    mockChannel = (MethodCall call) {
      invokedMethod = call.method;
      arguments = call.arguments;
      return null;
    };

    mockChannelForGetLogs = (MethodCall call) async {
      if (call.method == 'getPhoneLogs') {
        return <Map<String, Object>>[
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
            'duration': 123,
          }
        ];
      } else {
        return null;
      }
    };

    mockChannelForGranted = (MethodCall call) async {
      return call.method == 'checkPermission' ? 'granted' : null;
    };

    mockChannelForDenied = (MethodCall call) async {
      return call.method == 'checkPermission' ? 'denied' : null;
    };

    mockChannelForDeniedCannotRequest = (MethodCall call) async {
      return call.method == 'checkPermission' ? 'deniedAndCannotRequest' : null;
    };

    phoneLog = const PhoneLog();
  });

  group('Phone log plugin', () {
    test('fetch phone log', () async {
      channel.setMockMethodCallHandler(mockChannelForGetLogs);

      final Iterable<CallRecord> records = await phoneLog.getPhoneLogs(
          startDate: new Int64(123456789), duration: new Int64(12));

      print(records);
      final CallRecord record = records.first;

      expect(record.formattedNumber, '123 123 1234');
      expect(record.callType, 'INCOMING_TYPE');
      expect(record.number, '1231231234');
      expect(record.dateYear, 2018);
      expect(record.duration, 123);

      channel.setMockMethodCallHandler(mockChannel);
      await phoneLog.getPhoneLogs(
          startDate: new Int64(123456789), duration: new Int64(12));
      expect(invokedMethod, 'getPhoneLogs');
      expect(arguments,
          <String, String>{'startDate': '123456789', 'duration': '12'});
    });

    test('check permission', () async {
      channel.setMockMethodCallHandler(mockChannel);

      await phoneLog.checkPermission();

      expect(invokedMethod, 'checkPermission');
      expect(arguments, null);

      channel.setMockMethodCallHandler(mockChannelForGranted);
      final PermissionStatus permissionGranted =
          await phoneLog.checkPermission();

      expect(permissionGranted, PermissionStatus.granted);

      channel.setMockMethodCallHandler(mockChannelForDenied);
      final PermissionStatus permissionDenied =
          await phoneLog.checkPermission();

      expect(permissionDenied, PermissionStatus.denied);

      channel.setMockMethodCallHandler(mockChannelForDeniedCannotRequest);
      final PermissionStatus permissionCannotRequest =
          await phoneLog.checkPermission();

      expect(permissionCannotRequest, PermissionStatus.deniedAndCannotRequest);
    });

    test('request permission', () async {
      channel.setMockMethodCallHandler(mockChannel);

      await phoneLog.requestPermission();

      expect(invokedMethod, 'requestPermission');
      expect(arguments, null);
    });
  });
}
