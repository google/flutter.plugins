package com.google.flutter.plugins.audiofileplayer;

import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.util.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/**
 * Flutter audio file player plugin.
 *
 * <p>Receives messages which create, trigger, and destroy instances of {@link ManagedMediaPlayer}.
 */
public class AudiofileplayerPlugin implements MethodCallHandler {
  private static final String TAG = AudiofileplayerPlugin.class.getSimpleName();

  // Method channel constants, matching those in the Dart and iOS plugin code.
  private static final String CHANNEL = "audiofileplayer";
  private static final String LOAD_METHOD = "load";
  private static final String FLUTTER_PATH = "flutterPath";
  private static final String AUDIO_BYTES = "audioBytes";
  private static final String REMOTE_URL = "remoteUrl";
  private static final String AUDIO_ID = "audioId";
  private static final String LOOPING = "looping";
  private static final String RELEASE_METHOD = "release";
  private static final String PLAY_METHOD = "play";
  private static final String PLAY_FROM_START = "playFromStart";
  private static final String SEEK_METHOD = "seek";
  private static final String SET_VOLUME_METHOD = "setVolume";
  private static final String VOLUME = "volume";
  private static final String PAUSE_METHOD = "pause";
  private static final String ON_COMPLETE_CALLBACK = "onComplete";
  private static final String ON_DURATION_CALLBACK = "onDuration";
  private static final String DURATION_SECONDS = "duration_seconds";
  private static final String ON_POSITION_CALLBACK = "onPosition";
  private static final String POSITION_SECONDS = "position_seconds";
  private static final String ERROR_CODE = "AudioPluginError";

  private final Registrar registrar;
  private final Map<String, ManagedMediaPlayer> mediaPlayers;
  private final MethodChannel methodChannel;

  public static void registerWith(Registrar registrar) {
    final MethodChannel methodChannel =
        new MethodChannel(registrar.messenger(), CHANNEL);
    final AudiofileplayerPlugin instance =
        new AudiofileplayerPlugin(registrar, methodChannel);
    methodChannel.setMethodCallHandler(instance);
  }

  private AudiofileplayerPlugin(Registrar registrar, MethodChannel methodChannel) {
    this.registrar = registrar;
    this.methodChannel = methodChannel;
    this.mediaPlayers = new HashMap<>();
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    Log.i(TAG, "onMethodCall: method = " + call.method);
    if (call.method.equals(LOAD_METHOD)) {
      onLoad(call, result);
      return;
    }
    // All subsequent calls need a valid player.
    ManagedMediaPlayer player = getAndVerifyPlayer(call, result);
    if (call.method.equals(PLAY_METHOD)) {
      Boolean playFromStartBoolean = call.argument(PLAY_FROM_START);
      boolean playFromStart = playFromStartBoolean.booleanValue();
      player.play(playFromStart);
      result.success(null);
    } else if (call.method.equals(RELEASE_METHOD)) {
      player.release();
      mediaPlayers.remove(player.getAudioId());
      result.success(null);
    } else if (call.method.equals(SEEK_METHOD)) {
      Double positionSecondsDouble = call.argument(POSITION_SECONDS);
      double positionSeconds = positionSecondsDouble.doubleValue();
      player.seek(positionSeconds);
      result.success(null);
    } else if (call.method.equals(SET_VOLUME_METHOD)) {
      Double volumeDouble = call.argument(VOLUME);
      double volume = volumeDouble.doubleValue();
      player.setVolume(volume);
      result.success(null);
    } else if (call.method.equals(PAUSE_METHOD)) {
      player.pause();
      result.success(null);
    } else {
      result.notImplemented();
    }
  }

  private void onLoad(MethodCall call, Result result) {
    String audioId = call.argument(AUDIO_ID);
    if (audioId == null) {
      result.error(ERROR_CODE, "Received load() call without an audioId", null);
      return;
    }
    if (mediaPlayers.get(audioId) != null) {
      result.error(
          ERROR_CODE, "Tried to load an already-loaded player: " + audioId, null);
      return;
    }

    Boolean loopingBoolean = call.argument(LOOPING);
    boolean looping = false;
    if (loopingBoolean != null) {
      looping = loopingBoolean.booleanValue();
    }

    try {
      if (call.argument(FLUTTER_PATH) != null) {
        String flutterPath = call.argument(FLUTTER_PATH).toString();
        AssetManager assetManager = registrar.context().getAssets();
        String key = registrar.lookupKeyForAsset(flutterPath);
        AssetFileDescriptor fd = assetManager.openFd(key);
        ManagedMediaPlayer newPlayer = new LocalManagedMediaPlayer(audioId, fd, this, looping);
        mediaPlayers.put(audioId, newPlayer);
        handleDurationForPlayer(newPlayer, audioId);
        result.success(null);
      } else if (call.argument(AUDIO_BYTES) != null) {
        byte[] audioBytes = call.argument(AUDIO_BYTES);
        ManagedMediaPlayer newPlayer =
            new LocalManagedMediaPlayer(
                audioId, new BufferMediaDataSource(audioBytes), this, looping);
        mediaPlayers.put(audioId, newPlayer);
        handleDurationForPlayer(newPlayer, audioId);
        result.success(null);
      } else if (call.argument(REMOTE_URL) != null) {
        String remoteUrl = call.argument(REMOTE_URL);
        // Note that this will throw an exception on invalid URL or lack of network connectivity.
        RemoteManagedMediaPlayer newPlayer =
            new RemoteManagedMediaPlayer(audioId, remoteUrl, this, looping);
        newPlayer.setOnRemoteLoadListener(
            (success) -> {
              if (success) {
                handleDurationForPlayer(newPlayer, audioId);
                result.success(null);
              } else {
                mediaPlayers.remove(audioId);
                result.error(
                    ERROR_CODE,
                    "Remote URL loading failed for URL: " + remoteUrl,
                    null);
              }
            });
        // Add player to data structure immediately; will be removed if async loading fails.
        mediaPlayers.put(audioId, newPlayer);
      } else {
        result.error(
            ERROR_CODE,
            "Could not create ManagedMediaPlayer with no flutterPath, audioBytes, nor remoteUrl.",
            null);
        return;
      }
    } catch (Exception e) {
      result.error(
          ERROR_CODE, "Could not create ManagedMediaPlayer:" + e.getMessage(), null);
    }
  }

  private ManagedMediaPlayer getAndVerifyPlayer(MethodCall call, Result result) {
    String audioId = call.argument(AUDIO_ID);
    if (audioId == null) {
      result.error(
          ERROR_CODE,
          String.format("Received %s call without an audioId", call.method),
          null);
      return null;
    }
    ManagedMediaPlayer player = mediaPlayers.get(audioId);
    if (player == null) {
      result.error(
          ERROR_CODE,
          String.format("Called %s on an unloaded player: %s", call.method, audioId),
          null);
    }
    return player;
  }

  /** Called by {@link ManagedMediaPlayer} when (non-looping) file has finished playback. */
  public void handleCompletion(String audioId) {
    this.methodChannel.invokeMethod(
        ON_COMPLETE_CALLBACK,
        Collections.singletonMap(AUDIO_ID, audioId));
  }

  // Called on successful load.
  public void handleDurationForPlayer(ManagedMediaPlayer player, String audioId) {
    Map<String, Object> arguments = new HashMap<String, Object>();
    arguments.put(AUDIO_ID, audioId);
    // Note that player will report a negative value if duration is unavailable (for example,
    // streaming certain types of remote audio).
    double durationSeconds = player.getDurationSeconds();
    arguments.put(DURATION_SECONDS, Double.valueOf(durationSeconds));
    this.methodChannel.invokeMethod(ON_DURATION_CALLBACK, arguments);
  }

  /** Called repeatedly by {@link ManagedMediaPlayer} during playback. */
  public void handlePosition(String audioId, double positionSeconds) {
    Map<String, Object> arguments = new HashMap<String, Object>();
    arguments.put(AUDIO_ID, audioId);
    arguments.put(POSITION_SECONDS, Double.valueOf(positionSeconds));
    this.methodChannel.invokeMethod(ON_POSITION_CALLBACK, arguments);
  }
}
