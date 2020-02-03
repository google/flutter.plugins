package com.jiajiabingcheng.phonelog;

import java.util.HashMap;

class CallRecord {

  CallRecord() {}

  // Note about the different number fields:
  // Depending on how the number is dialed by the user
  // i.e. manually entered through the device's dialpad,
  // clicking on a contact or half-dialing the number
  // and then clicking on the contact from the auto-
  // complete suggestion, the number can be present in
  // either the number or formattedNumber field.
  String formattedNumber;
  String number;
  String callType;
  int dateYear;
  int dateMonth;
  int dateDay;
  int dateHour;
  int dateMinute;
  int dateSecond;
  long duration;

  HashMap<String, Object> toMap() {
    HashMap<String, Object> recordMap = new HashMap<>();
    recordMap.put("formattedNumber", formattedNumber);
    recordMap.put("number", number);
    recordMap.put("callType", callType);
    recordMap.put("dateYear", dateYear);
    recordMap.put("dateMonth", dateMonth);
    recordMap.put("dateDay", dateDay);
    recordMap.put("dateHour", dateHour);
    recordMap.put("dateMinute", dateMinute);
    recordMap.put("dateSecond", dateSecond);
    recordMap.put("duration", duration);

    return recordMap;
  }
}
