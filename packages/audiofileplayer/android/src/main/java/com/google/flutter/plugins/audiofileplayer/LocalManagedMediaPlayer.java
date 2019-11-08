package com.google.flutter.plugins.audiofileplayer;

import android.content.res.AssetFileDescriptor;
import android.media.MediaPlayer;
import java.io.IOException;

/**
 * Wraps a MediaPlayer for local asset use by AudiofileplayerPlugin.
 *
 * <p>Used for local audio data only; loading occurs synchronously. Loading remote audio should use
 * ManagedRemoteMediaPlayer.
 */
class LocalManagedMediaPlayer extends ManagedMediaPlayer {

  /**
   * Private shared constructor.
   *
   * <p>Callers must subsequently set a data source and call {@link MediaPlayer#prepare()}.
   */
  private LocalManagedMediaPlayer(
      String audioId, AudiofileplayerPlugin parentAudioPlugin, boolean looping)
      throws IllegalArgumentException, IOException {
    super(audioId, parentAudioPlugin);
    player.setLooping(looping);
    player.setOnErrorListener(this);
    player.setOnCompletionListener(this);
    player.setOnSeekCompleteListener(this);
  }

  /**
   * Create a LocalManagedMediaPlayer from an AssetFileDescriptor.
   *
   * @throws IOException if underlying MediaPlayer cannot load AssetFileDescriptor.
   */
  public LocalManagedMediaPlayer(
      String audioId,
      AssetFileDescriptor fd,
      AudiofileplayerPlugin parentAudioPlugin,
      boolean looping)
      throws IOException {
    this(audioId, parentAudioPlugin, looping);
    player.setDataSource(fd);
    player.prepare();
  }

  /**
   * Create a ManagedMediaPlayer from an BufferMediaDataSource.
   *
   * @throws IllegalArgumentException if BufferMediaDataSource is invalid.
   * @throws IOException if underlying MediaPlayer cannot load BufferMediaDataSource.
   */
  public LocalManagedMediaPlayer(
      String audioId,
      BufferMediaDataSource mediaDataSource,
      AudiofileplayerPlugin parentAudioPlugin,
      boolean looping)
      throws IOException, IllegalArgumentException, IllegalStateException {
    this(audioId, parentAudioPlugin, looping);
    player.setDataSource(mediaDataSource);
    player.prepare();
  }
}
