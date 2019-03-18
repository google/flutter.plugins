import 'dart:ui' show AppLifecycleState;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_test/flutter_test.dart';
import 'package:audiofileplayer/audiofileplayer.dart';

const _defaultPositionSeconds = 5.0;
const _defaultDurationSeconds = 10.0;
const _exceptionMessage = "Test exception";

void main() {
  group('$Audio', () {
    final methodCalls = <MethodCall>[];
    bool _throwExceptionOnNextMethodCall = false;

    setUp(() async {
      // Ensures that Audio objects are able to call WidgetBinder.instance.
      WidgetsFlutterBinding.ensureInitialized();
      Audio.shouldPlayWhileAppPaused = false;
      Audio.channel.setMockMethodCallHandler((MethodCall methodCall) async {
        methodCalls.add(methodCall);
        if (_throwExceptionOnNextMethodCall) {
          _throwExceptionOnNextMethodCall = false;
          throw PlatformException(
            code: errorCode,
            message: _exceptionMessage,
          );
        }
      });
      methodCalls.clear();
    });

    _mockOnCompleteCall(String audioId) => Audio.handleMethodCall(
        MethodCall(onCompleteCallback, {audioIdKey: audioId}));

    _mockOnDurationCall(String audioId) => Audio.handleMethodCall(MethodCall(
        onDurationCallback,
        {audioIdKey: audioId, durationSecondsKey: _defaultDurationSeconds}));

    _mockOnPositionCall(String audioId) => Audio.handleMethodCall(MethodCall(
        onPositionCallback,
        {audioIdKey: audioId, positionSecondsKey: _defaultPositionSeconds}));

    test('one-shot playback, with dispose() before playback completion', () {
      Audio.load('foo.wav')
        ..play()
        ..dispose();
      // Check that the Audio instance is no longer retained by the Audio class.
      expect(Audio.undisposedAudiosCount, 0);
      // Check sequence of native calls.
      expect(methodCalls.length, 2);
      expect(methodCalls[0].method, loadMethod);
      expect(methodCalls[1].method, playMethod);
      // Mock an on-complete call from native layer.
      final audioId = (methodCalls[0].arguments as Map)[audioIdKey];
      _mockOnCompleteCall(audioId);
      // Check that playback completion after dispose() triggers native resource release.
      expect(methodCalls.length, 3);
      expect(methodCalls[2].method, releaseMethod);
    });

    test('one-shot playback, with dispose() after playback completion', () {
      final audio = Audio.load('foo.wav')..play();
      // Check that the Audio instance is being retained by the Audio class.
      expect(Audio.undisposedAudiosCount, 1);
      // Check sequence of native calls.
      expect(methodCalls.length, 2);
      expect(methodCalls[0].method, loadMethod);
      expect(methodCalls[1].method, playMethod);
      // Mock an onComplete call from native layer.
      final audioId = (methodCalls[0].arguments as Map)[audioIdKey];
      _mockOnCompleteCall(audioId);
      // Call dispose; audio is finished playing, so should native layer should
      // be released immediately.
      audio.dispose();
      expect(Audio.undisposedAudiosCount, 0);
      expect(methodCalls.length, 3);
      expect(methodCalls[2].method, releaseMethod);
    });

    test('playback, pause, dispose', () {
      Audio.load('foo.wav')
        ..play()
        ..pause()
        ..dispose();
      // Check that the Audio instance is no longer retained by the Audio class.
      expect(Audio.undisposedAudiosCount, 0);
      // Check sequence of native calls.
      expect(methodCalls.length, 4);
      expect(methodCalls[0].method, loadMethod);
      expect(methodCalls[1].method, playMethod);
      expect(methodCalls[2].method, pauseMethod);
      expect(methodCalls[3].method, releaseMethod);
    });

    test('seek, and dispose without playback', () {
      Audio.load('foo.wav')
        ..seek(_defaultPositionSeconds)
        ..dispose();
      // Check that the Audio instance is no longer retained by the Audio class.
      expect(Audio.undisposedAudiosCount, 0);
      // Check sequence of native calls.
      expect(methodCalls.length, 3);
      expect(methodCalls[0].method, loadMethod);
      expect(methodCalls[1].method, seekMethod);
      expect((methodCalls[1].arguments as Map)[positionSecondsKey],
          _defaultPositionSeconds);
      expect(methodCalls[2].method, releaseMethod);
    });

    test('onComplete, onPosition, onDuration called, even after dispose()', () {
      bool onCompleteCalled = false;
      double duration;
      double position;
      Audio.load('foo.wav',
          onComplete: () => onCompleteCalled = true,
          onDuration: (d) => duration = d,
          onPosition: (p) => position = p)
        ..play()
        ..dispose();
      // Check that the Audio instance is retained by the Audio class while
      // awaiting duration/position.
      expect(Audio.undisposedAudiosCount, 0);
      expect(Audio.awaitingOnCompleteAudiosCount, 1);
      expect(Audio.awaitingOnDurationAudiosCount, 1);
      expect(Audio.usingOnPositionAudiosCount, 1);

      // Check sequence of native calls.
      expect(methodCalls.length, 2);
      expect(methodCalls[0].method, loadMethod);
      expect(methodCalls[1].method, playMethod);

      // Mock duration, position, and completion calls from native layer,
      // check that callbacks are called.
      final audioId = (methodCalls[0].arguments as Map)[audioIdKey];
      _mockOnDurationCall(audioId);
      expect(duration, _defaultDurationSeconds);

      _mockOnPositionCall(audioId);
      expect(position, _defaultPositionSeconds);

      _mockOnCompleteCall(audioId);
      expect(onCompleteCalled, true);

      // Check that the Audio instance is no longer being retained by the Audio
      // class.
      expect(Audio.undisposedAudiosCount, 0);
      expect(Audio.awaitingOnCompleteAudiosCount, 0);
      expect(Audio.awaitingOnDurationAudiosCount, 0);
      expect(Audio.usingOnPositionAudiosCount, 0);

      // After dispose() and audio completion, check native layer released.
      expect(methodCalls.length, 3);
      expect(methodCalls[2].method, releaseMethod);
    });

    test('remove callbacks', () {
      bool onCompleteCalled = false;
      double duration;
      double position;
      Audio.load('foo.wav',
          onComplete: () => onCompleteCalled = true,
          onDuration: (d) => duration = d,
          onPosition: (p) => position = p)
        ..play()
        ..removeCallbacks()
        ..dispose();

      // Check that the Audio instance is no longer being retained by the Audio
      // class.
      expect(Audio.undisposedAudiosCount, 0);
      expect(Audio.awaitingOnCompleteAudiosCount, 0);
      expect(Audio.awaitingOnDurationAudiosCount, 0);
      expect(Audio.usingOnPositionAudiosCount, 0);

      // Check sequence of native calls.
      expect(methodCalls.length, 2);
      expect(methodCalls[0].method, loadMethod);
      expect(methodCalls[1].method, playMethod);

      // Mock duration, position, and completion calls from native layer,
      // check that callbacks are _not_ called.
      final audioId = (methodCalls[0].arguments as Map)[audioIdKey];
      _mockOnDurationCall(audioId);
      expect(duration, null);

      _mockOnPositionCall(audioId);
      expect(position, null);

      _mockOnCompleteCall(audioId);
      expect(onCompleteCalled, false);

      // After dispose() and audio completion, check native layer released.
      expect(methodCalls.length, 3);
      expect(methodCalls[2].method, releaseMethod);
    });

    test('should pause audio when app is paused and resume when app is resumed',
        () {
      final audio = Audio.load('foo.wav')
        ..play()
        ..dispose();
      // Mock app change from active to paused (i.e. user backgrounds app).
      audio.didChangeAppLifecycleState(AppLifecycleState.paused);
      // Check sequence of native calls, the last of which is a call to pause.
      expect(methodCalls.length, 3);
      expect(methodCalls[0].method, loadMethod);
      expect(methodCalls[1].method, playMethod);
      expect(methodCalls[2].method, pauseMethod);
      // Mock app change from paused to active (i.e. user foregrounds app).
      audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // Check sequence of native calls, the last of which is a call to resume
      // playback.
      expect(methodCalls.length, 4);
      expect(methodCalls[3].method, playMethod);
      expect((methodCalls[3].arguments as Map)[playFromStartKey], false);
    });

    test('should continue to play audio while app is paused', () {
      Audio.shouldPlayWhileAppPaused = true;
      final audio = Audio.load('foo.wav')
        ..play()
        ..dispose();
      // Mock app change from active to paused (i.e. user backgrounds app).
      audio.didChangeAppLifecycleState(AppLifecycleState.paused);
      // Check sequence of native calls. There should not be an additional call
      // to pause playback.
      expect(methodCalls.length, 2);
      expect(methodCalls[0].method, loadMethod);
      expect(methodCalls[1].method, playMethod);
      // Mock app change from paused to active (i.e. user foregrounds app).
      audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // Check sequence of native calls. There should not be any additional
      // calls.
      expect(methodCalls.length, 2);
    });

    test('PlatformException is caught and calls onError()', () {
      _throwExceptionOnNextMethodCall = true;
      var errorHandler = expectAsync1((m) => expect(m, _exceptionMessage));
      Audio.load('foo.wav', onError: errorHandler);
    });

    test('PlatformException is thrown when no onError() set', () {
      final audio = Audio.load('foo.wav');
      _throwExceptionOnNextMethodCall = true;
      expect(audio.play(), throwsException);
    });
  });
}
