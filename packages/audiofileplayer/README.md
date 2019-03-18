# audiofileplayer

A Flutter plugin for audio playback. 
Supports 
  * Reading audio data from Flutter project assets, byte arrays, and remote URLs. 
  * Seek to position.
  * Continue playback while app is backgrounded.
  * Callbacks for loaded audio duration, current position, and playback completion.
  * Volume
  * Looping
  * Pause/Resume.
  * Multiple audio players, with automatic memory management.

## Getting Started

To use this plugin, add `audiofileplayer` as a [dependency in your pubspec.yaml file](https://flutter.io/platform-plugins/).

### Example

``` dart
// Play a sound as a one-shot, releasing its resources when it finishes playing.
Audio.load('assets/foo.wav')..play()..dispose();
```

Please see the header comment of audiofileplayer.dart for more information, and see the example app of this plugin for an example showing multiple use cases.
