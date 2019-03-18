package com.google.flutter.plugins.audiofileplayer;

import android.media.MediaPlayer;
import android.os.Handler;
import android.util.Log;

/** Base class for wrapping a MediaPlayer for use by AudiofileplayerPlugin. */
abstract class ManagedMediaPlayer
    implements MediaPlayer.OnCompletionListener, MediaPlayer.OnErrorListener {
  private static final String TAG = "ManagedMediaPlayer";
  protected final AudiofileplayerPlugin parentAudioPlugin;
  protected final String audioId;
  protected MediaPlayer player;
  protected Handler handler;

  /** Runnable which repeatedly sends the player's position. */
  private final Runnable updatePositionData =
      new Runnable() {
        public void run() {
          try {
            if (player.isPlaying()) {
              double positionSeconds = (double) player.getCurrentPosition() / 1000.0;
              parentAudioPlugin.handlePosition(audioId, positionSeconds);
            }
            handler.postDelayed(this, 250);
          } catch (Exception e) {
            Log.e(TAG, "Could not schedule position update for player", e);
          }
        }
      };

  protected ManagedMediaPlayer(String audioId, AudiofileplayerPlugin parentAudioPlugin) {
    this.parentAudioPlugin = parentAudioPlugin;
    this.audioId = audioId;

    handler = new Handler();
    handler.post(updatePositionData);
  }

  public String getAudioId() {
    return audioId;
  }

  public double getDurationSeconds() {
    return (double) player.getDuration() / 1000.0; // Convert ms to seconds.
  }

  /** Plays the audio. */
  public void play(boolean playFromStart) {
    if (playFromStart) {
      player.seekTo(0);
    }
    player.start();
  }

  /** Releases the underlying MediaPlayer. */
  public void release() {
    player.stop();
    player.reset();
    player.release();
    player = null;
    handler.removeCallbacks(updatePositionData);
  }

  public void seek(double positionSeconds) {
    int positionMilliseconds = (int) (positionSeconds * 1000.0);
    player.seekTo(positionMilliseconds);
  }

  public void setVolume(double volume) {
    player.setVolume((float) volume, (float) volume);
  }

  public void pause() {
    player.pause();
  }

  @Override
  public void onCompletion(MediaPlayer mediaPlayer) {
    player.seekTo(0);
    parentAudioPlugin.handleCompletion(this.audioId);
  }

  /**
   * Callback to indicate an error condition.
   *
   * <p>NOTE: {@link #onError(MediaPlayer, int, int)} must be properly implemented and return {@code
   * true} otherwise errors will repeatedly call {@link #onCompletion(MediaPlayer)}.
   */
  @Override
  public boolean onError(MediaPlayer mp, int what, int extra) {
    Log.e(TAG, "onError: what:" + what + " extra: " + extra);
    return true;
  }
}
