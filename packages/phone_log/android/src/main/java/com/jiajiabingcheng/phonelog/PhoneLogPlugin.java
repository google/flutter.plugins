package com.jiajiabingcheng.phonelog;

import android.Manifest;
import android.annotation.TargetApi;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.os.Build;
import android.provider.CallLog;
import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;

/** PhoneLogPlugin */
@TargetApi(Build.VERSION_CODES.LOLLIPOP)
public class PhoneLogPlugin
    implements MethodCallHandler,
        PluginRegistry.RequestPermissionsResultListener,
        FlutterPlugin,
        ActivityAware {
  private Result pendingResult;
  private Registrar registrar;
  // Activity for v2 embedding.
  private Activity activity;
  private ActivityPluginBinding activityPluginBinding;
  private MethodChannel methodChannel;
  private Context context;

  public static void registerWith(Registrar registrar) {
    PhoneLogPlugin instance = new PhoneLogPlugin();
    instance.registrar = registrar;
    instance.initInstance(registrar.messenger(), registrar.context());
    registrar.addRequestPermissionsResultListener(instance);
  }

  private void initInstance(BinaryMessenger messenger, Context context) {
    methodChannel = new MethodChannel(messenger, "github.com/jiajiabingcheng/phone_log");
    methodChannel.setMethodCallHandler(this);
    this.context = context;
  }

  private Activity activity() {
    return activity != null ? activity : registrar.activity();
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    initInstance(binding.getBinaryMessenger(), binding.getApplicationContext());
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    methodChannel.setMethodCallHandler(null);
    methodChannel = null;
    context = null;
  }

  private void attachToActivity(ActivityPluginBinding activityPluginBinding) {
    this.activity = activityPluginBinding.getActivity();
    this.activityPluginBinding = activityPluginBinding;
    activityPluginBinding.addRequestPermissionsResultListener(this);
  }

  private void detachToActivity() {
    this.activity = null;
    activityPluginBinding.removeRequestPermissionsResultListener(this);
    this.activityPluginBinding = null;
  }

  @Override
  public void onAttachedToActivity(ActivityPluginBinding activityPluginBinding) {
    attachToActivity(activityPluginBinding);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    detachToActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(ActivityPluginBinding activityPluginBinding) {
    attachToActivity(activityPluginBinding);
  }

  @Override
  public void onDetachedFromActivity() {
    detachToActivity();
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    if (pendingResult != null) {
      pendingResult.error("multiple_requests", "Cancelled by a second request.", null);
      pendingResult = null;
    }
    pendingResult = result;
    switch (call.method) {
      case "checkPermission":
        pendingResult.success(checkPermission());
        pendingResult = null;
        break;
      case "requestPermission":
        requestPermission();
        break;
      case "getPhoneLogs":
        String startDate = call.argument("startDate");
        String duration = call.argument("duration");
        fetchCallRecords(startDate, duration);
        break;
      default:
        result.notImplemented();
    }
  }

  private void requestPermission() {
    Log.i("PhoneLogPlugin", "Requesting permission : " + Manifest.permission.READ_CALL_LOG);
    String[] perm = {Manifest.permission.READ_CALL_LOG};
    activity().requestPermissions(perm, 0);
  }

  private String checkPermission() {
    Log.i("PhoneLogPlugin", "Checking permission : " + Manifest.permission.READ_CALL_LOG);
    boolean isGranted =
        PackageManager.PERMISSION_GRANTED
            == activity().checkSelfPermission(Manifest.permission.READ_CALL_LOG);
    if (isGranted) {
      return "granted";
    } else if (activity().shouldShowRequestPermissionRationale(Manifest.permission.READ_CALL_LOG)) {
      return "denied";
    }
    return "deniedAndCannotRequest";
  }

  @Override
  public boolean onRequestPermissionsResult(int requestCode, String[] strings, int[] grantResults) {
    boolean res = false;
    if (requestCode == 0 && grantResults.length > 0) {
      res = grantResults[0] == PackageManager.PERMISSION_GRANTED;
      pendingResult.success(res);
      pendingResult = null;
    }
    return res;
  }

  private static final String[] PROJECTION = {
    CallLog.Calls.CACHED_FORMATTED_NUMBER,
    CallLog.Calls.CACHED_MATCHED_NUMBER,
    CallLog.Calls.TYPE,
    CallLog.Calls.DATE,
    CallLog.Calls.DURATION,
    CallLog.Calls.NUMBER,
  };

  @TargetApi(Build.VERSION_CODES.M)
  private void fetchCallRecords(String startDate, String duration) {
    if (activity().checkSelfPermission(Manifest.permission.READ_CALL_LOG)
        == PackageManager.PERMISSION_GRANTED) {
      String selectionCondition = null;
      if (startDate != null) {
        selectionCondition = CallLog.Calls.DATE + "> " + startDate;
      }
      if (duration != null) {
        String durationSelection = CallLog.Calls.DURATION + "> " + duration;
        if (selectionCondition != null) {
          selectionCondition = selectionCondition + " AND " + durationSelection;
        } else {
          selectionCondition = durationSelection;
        }
      }
      Cursor cursor =
          context
              .getContentResolver()
              .query(
                  CallLog.Calls.CONTENT_URI,
                  PROJECTION,
                  selectionCondition,
                  null,
                  CallLog.Calls.DATE + " DESC");

      try {
        ArrayList<HashMap<String, Object>> records = getCallRecordMaps(cursor);
        pendingResult.success(records);
        pendingResult = null;
      } catch (Exception e) {
        Log.e("PhoneLog", "Error on fetching call record" + e);
        pendingResult.error("PhoneLog", e.getMessage(), null);
        pendingResult = null;
      } finally {
        if (cursor != null) {
          cursor.close();
        }
      }

    } else {
      pendingResult.error("PhoneLog", "Permission is not granted", null);
      pendingResult = null;
    }
  }

  private String getUnformattedNumber(String cachedMatchedNum, String dialedNum) {
    return (cachedMatchedNum == null || cachedMatchedNum.isEmpty()) ? dialedNum : cachedMatchedNum;
  }

  /**
   * Builds the list of call record maps from the cursor
   *
   * @param cursor
   * @return the list of maps
   */
  private ArrayList<HashMap<String, Object>> getCallRecordMaps(Cursor cursor) {
    ArrayList<HashMap<String, Object>> records = new ArrayList<>();
    int formattedNumIndex = cursor.getColumnIndex(CallLog.Calls.CACHED_FORMATTED_NUMBER);
    int cachedMatchedNumIndex = cursor.getColumnIndex(CallLog.Calls.CACHED_MATCHED_NUMBER);
    int typeIndex = cursor.getColumnIndex(CallLog.Calls.TYPE);
    int dateIndex = cursor.getColumnIndex(CallLog.Calls.DATE);
    int durationIndex = cursor.getColumnIndex(CallLog.Calls.DURATION);
    int dialedNumberIndex = cursor.getColumnIndex(CallLog.Calls.NUMBER);

    while (cursor != null && cursor.moveToNext()) {
      CallRecord record = new CallRecord();
      // This field  holds the number formatted based on the country the user was in when the call
      // was made/received.
      record.formattedNumber = cursor.getString(formattedNumIndex);
      // number holds the unformatted version of the actual number.
      record.number =
          getUnformattedNumber(
              cursor.getString(cachedMatchedNumIndex), cursor.getString(dialedNumberIndex));
      record.callType = getCallType(cursor.getInt(typeIndex));

      Date date = new Date(cursor.getLong(dateIndex));
      Calendar cal = Calendar.getInstance();
      cal.setTime(date);
      record.dateYear = cal.get(Calendar.YEAR);
      record.dateMonth = cal.get(Calendar.MONTH);
      record.dateDay = cal.get(Calendar.DAY_OF_MONTH);
      record.dateHour = cal.get(Calendar.HOUR_OF_DAY);
      record.dateMinute = cal.get(Calendar.MINUTE);
      record.dateSecond = cal.get(Calendar.SECOND);
      record.duration = cursor.getLong(durationIndex);

      records.add(record.toMap());
    }
    return records;
  }

  private String getCallType(int anInt) {
    switch (anInt) {
      case CallLog.Calls.INCOMING_TYPE:
        return "INCOMING_TYPE";
      case CallLog.Calls.OUTGOING_TYPE:
        return "OUTGOING_TYPE";
      case CallLog.Calls.MISSED_TYPE:
        return "MISSED_TYPE";
      default:
        break;
    }
    return null;
  }
}
