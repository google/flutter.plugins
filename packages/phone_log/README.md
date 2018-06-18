# phone_log

A flutter plugin project to access the device phone log (Android only).

Currently only fetching the following 5 fields:
    CallLog.Calls.CACHED_FORMATTED_NUMBER
    CallLog.Calls.CACHED_MATCHED_NUMBER
    CallLog.Calls.TYPE
    CallLog.Calls.DATE
    CallLog.Calls.DURATION

For iOS it is not possible to extract the call log programmatically. Apple officially does not expose any public API to access the call log. So all the method will return null on iOS.

## Getting Started

Make sure you add the permission below to your Android Manifest Permission:

```xml
<uses-permission android:name="android.permission.READ_CALL_LOG"/>
```
## Usage in Dart

Import the relevant file:

```
import 'package:phone_log/phone_log.dart';
```

### Methords
```dart
/// Check phone log permission and return a [Future] with the result
static Future<bool> checkPermission(Permission permission);

/// Request phone log permission and return a [Future] with the result
static Future<bool> requestPermission(Permission permission);

/// Fetch the call log from Android device with a [startDate] and a 
/// minimum [duration]. If startDate == null, all the data will be
/// fetched out. If duration == null, there will be no duration limit.
static Future<Iterable<CallRecord>> getPhoneLogs();
```

