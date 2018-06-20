import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:phone_log/phone_log.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Iterable<CallRecord> _callRecords;

  Future<Null> fetchCallLogs() async {
    var callLogs = await PhoneLog.getPhoneLogs(
        // startDate: 20180605, duration: 15 seconds
        startDate: new Int64(1525590000000),
        duration: new Int64(13));
    setState(() {
      _callRecords = callLogs;
    });
  }

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[
      new Padding(
        padding: const EdgeInsets.all(8.0),
        child: new RaisedButton(
            onPressed: checkPermission, child: new Text("Check permission")),
      ),
      new Padding(
        padding: const EdgeInsets.all(8.0),
        child: new RaisedButton(
            onPressed: requestPermission,
            child: new Text("Request permission")),
      ),
      new Padding(
          padding: const EdgeInsets.all(8.0),
          child: new RaisedButton(
              onPressed: fetchCallLogs, child: new Text("Fetch phone log"))),
    ];

    for (CallRecord call in _callRecords ?? []) {
      children.addAll([
        new Container(
          height: 16.0,
        ),
        new Row(
          children: <Widget>[
            new Text(call.formattedNumber ?? call.number ?? 'unknow'),
            new Padding(
              child: new Text(call.callType),
              padding: const EdgeInsets.only(left: 8.0),
            ),
          ],
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
        new Row(
          children: <Widget>[
            new Padding(
              child: new Text(call.dateYear.toString() +
                  '-' +
                  call.dateMonth.toString() +
                  '-' +
                  call.dateDay.toString() +
                  '  ' +
                  call.dateHour.toString() +
                  ': ' +
                  call.dateMinute.toString() +
                  ': ' +
                  call.dateSecond.toString()),
              padding: const EdgeInsets.only(left: 8.0),
            ),
            new Padding(
                child: new Text(call.duration.toString() + 'seconds'),
                padding: const EdgeInsets.only(left: 8.0))
          ],
          crossAxisAlignment: CrossAxisAlignment.center,
        )
      ]);
    }

    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(title: new Text('PhoneLog plugin example')),
        body: new Center(
          child: new Column(children: children),
        ),
      ),
    );
  }
}

requestPermission() async {
  bool res = await PhoneLog.requestPermission();
  print("permission request result is " + res.toString());
}

checkPermission() async {
  bool res = await PhoneLog.checkPermission();
  print("permission is " + res.toString());
}
