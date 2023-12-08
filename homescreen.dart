import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now();
  late MethodChannel _channel;

  @override
  void initState() {
    super.initState();
    _channel = MethodChannel('Silent Mode');
    setup();
  }

  Future<void> setup() async {
    var status = await Permission.notification.request();

    if (status != PermissionStatus.granted) {
      Permission.notification.request();
      SoundMode.setSoundMode(RingerModeStatus.silent);
      return;
    }

    tzdata.initializeTimeZones();
    var detroit = tz.getLocation('UTC');
    tz.setLocalLocation(detroit);
  }

  Future<void> backgroundTask(int id) async {
    try {
      await SoundMode.setSoundMode(RingerModeStatus.silent);
    } on PlatformException {
      print('Please enable permissions required');
    }
  }

  Future<void> _startBackgroundTask(int id) async {
    await backgroundTask(id);
  }

  Future<void> _endBackgroundTask(int id) async {
    try {
      await _invokeNativeMethod('General Mode');
    } catch (e) {
      print('Error invoking native method: $e');
    }
  }

  Future<void> _invokeNativeMethod(String generalMode,
      [Map<String, dynamic>? arguments]) async {
    try {
      if (arguments != null && arguments.containsKey('taskId')) {
        int taskId = arguments['taskId'] as int;
        await _channel.invokeMethod(generalMode, {'taskId': taskId});
      } else {
        await _channel.invokeMethod(generalMode, arguments);
      }
    } on PlatformException catch (e) {
      print('Error invoking native method: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blueAccent,
          title: Text(widget.title),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Select Silent Mode Schedule:'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final selectedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_startTime),
                      );

                      if (selectedTime != null) {
                        setState(() {
                          _startTime = DateTime(
                            _startTime.year,
                            _startTime.month,
                            _startTime.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );
                        });
                      }
                    },
                    child: Text('Start Time'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final selectedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_endTime),
                      );

                      if (selectedTime != null) {
                        setState(() {
                          _endTime = DateTime(
                            _endTime.year,
                            _endTime.month,
                            _endTime.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );
                        });
                      }
                    },
                    child: Text('End Time'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  AndroidAlarmManager.cancel(0);
                  AndroidAlarmManager.cancel(1);

                  await backgroundTask(0);

                  AndroidAlarmManager.oneShotAt(
                    tz.TZDateTime.now(tz.local).add(
                      Duration(
                        hours: _startTime.hour,
                        minutes: _startTime.minute,
                      ),
                    ),
                    0,
                    _startBackgroundTask,
                    exact: true,
                    wakeup: true,
                  );

                  AndroidAlarmManager.oneShotAt(
                    tz.TZDateTime.now(tz.local).add(
                      Duration(
                        hours: _endTime.hour,
                        minutes: _endTime.minute,
                      ),
                    ),
                    1,
                    _endBackgroundTask,
                    exact: true,
                    wakeup: true,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Silent mode schedule set.'),
                    ),
                  );
                  setup();
                },
                child: Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
