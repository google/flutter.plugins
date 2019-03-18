import 'package:flutter/material.dart';

import 'package:audiofileplayer/audiofileplayer.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Preloaded audio data for the first card.
  Audio _audio;
  bool _audioPlaying = false;
  double _audioDurationSeconds;
  double _audioPositionSeconds;
  double _audioVolume = 1.0;
  double _seekSliderValue = 0.0; // Normalized 0.0 - 1.0.

  // On-the-fly audio data for the second card.
  int _spawnedAudioCount = 0;

  // Remote url audio data for the third card.
  Audio _remoteAudio;
  bool _remoteAudioPlaying = false;
  bool _remoteAudioLoading = false;
  String _remoteErrorMessage;

  @override
  void initState() {
    super.initState();
    _audio = Audio.load('assets/audio/printermanual.m4a',
        onComplete: () => setState(() => _audioPlaying = false),
        onDuration: (double durationSeconds) =>
            setState(() => _audioDurationSeconds = durationSeconds),
        onPosition: (double positionSeconds) => setState(() {
              _audioPositionSeconds = positionSeconds;
              _seekSliderValue = _audioPositionSeconds / _audioDurationSeconds;
            }));
    _loadRemoteAudio();
  }

  @override
  void dispose() {
    _audio.dispose();
    if (_remoteAudio != null) {
      _remoteAudio.dispose();
    }
    super.dispose();
  }

  static Widget _transportButtonWithTitle(
          String title, bool isPlaying, VoidCallback onTap) =>
      Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: <Widget>[
              RaisedButton(
                  onPressed: onTap,
                  child: isPlaying
                      ? Image.asset("assets/icons/ic_pause_black_48dp.png")
                      : Image.asset(
                          "assets/icons/ic_play_arrow_black_48dp.png")),
              Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(title)),
            ],
          ));

  // convert double seconds to minutes:seconds
  static String _stringForSeconds(double seconds) {
    if (seconds == null) return null;
    return '${(seconds ~/ 60)}:${(seconds.truncate() % 60).toString().padLeft(2, '0')}';
  }

  void _loadRemoteAudio() {
    _remoteErrorMessage = null;
    _remoteAudioLoading = true;
    _remoteAudio = Audio.loadFromRemoteUrl('https://streams.kqed.org/kqedradio',
        onDuration: (_) => setState(() => _remoteAudioLoading = false),
        onError: (String message) => setState(() {
              _remoteErrorMessage = message;
              _remoteAudio.dispose();
              _remoteAudio = null;
              _remoteAudioPlaying = false;
              _remoteAudioLoading = false;
            }));
  }

  // Creates a card, out of column child widgets. Injects vertical padding
  // around the column children.
  Widget _cardWrapper(List<Widget> columnChildren) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: columnChildren
                  .map((child) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: child,
                      ))
                  .toList())));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      backgroundColor: const Color(0xFFCCCCCC),
      appBar: AppBar(
        title: const Text('Audio file player example'),
      ),
      body: ListView(children: <Widget>[
        // A card controlling a pre-loaded (on app start) audio object.
        _cardWrapper([
          const Text('Preloaded audio, with transport controls.'),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _transportButtonWithTitle('play from start', false, () {
              _audio.play();
              setState(() => _audioPlaying = true);
            }),
            _transportButtonWithTitle(
                _audioPlaying ? 'pause' : 'resume', _audioPlaying, () {
              _audioPlaying ? _audio.pause() : _audio.resume();
              setState(() => _audioPlaying = !_audioPlaying);
            }),
          ]),
          Row(
            children: <Widget>[
              Text(_stringForSeconds(_audioPositionSeconds) ?? ''),
              Expanded(child: Container()),
              Text(_stringForSeconds(_audioDurationSeconds) ?? ''),
            ],
          ),
          Slider(
              value: _seekSliderValue,
              onChanged: (double val) {
                setState(() => _seekSliderValue = val);
                final positionSeconds = val * _audioDurationSeconds;
                _audio.seek(positionSeconds);
              }),
          const Text('seek'),
          Slider(
              value: _audioVolume,
              onChanged: (double val) {
                setState(() => _audioVolume = val);
                _audio.setVolume(_audioVolume);
              }),
          const Text('volume (linear amplitude)'),
        ]),
        _cardWrapper([
          const Text('Spawn overlapping one-shot audio playback'),
          _transportButtonWithTitle('(hit multiple times)', false, () {
            Audio.load('assets/audio/sinesweep.mp3',
                onComplete: () => setState(() => --_spawnedAudioCount))
              ..play()
              ..dispose();
            setState(() => ++_spawnedAudioCount);
          }),
          Text('Spawned audio count: $_spawnedAudioCount'),
        ]),
        _cardWrapper([
          const Text('Play remote stream'),
          _transportButtonWithTitle(
              'resume/pause NPR (KQED) live stream',
              _remoteAudioPlaying,
              _remoteAudioLoading
                  ? null
                  : () {
                      if (!_remoteAudioPlaying) {
                        // If remote audio loading previously failed with an
                        // error, attempt to reload.
                        if (_remoteAudio == null) _loadRemoteAudio();
                        // Note call to resume(), not play(). play() attempts to
                        // seek to the start of a file, which, for streams, will
                        // fail with an error on Android platforms, so streams
                        // should use resume() to begin playback.
                        _remoteAudio.resume();
                        setState(() => _remoteAudioPlaying = true);
                      } else {
                        _remoteAudio.pause();
                        setState(() => _remoteAudioPlaying = false);
                      }
                    }),
          _remoteErrorMessage != null
              ? Text(_remoteErrorMessage,
                  style: TextStyle(color: const Color(0xFFFF0000)))
              : Text(_remoteAudioLoading ? 'loading...' : 'loaded')
        ]),
      ]),
    ));
  }
}
