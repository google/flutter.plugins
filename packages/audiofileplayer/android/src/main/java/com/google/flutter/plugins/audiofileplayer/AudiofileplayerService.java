package com.google.flutter.plugins.audiofileplayer;

import android.app.*;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.KeyEvent;

import java.util.List;

import static android.content.Context.AUDIO_SERVICE;
import static android.media.AudioManager.AUDIOFOCUS_GAIN;

public class AudiofileplayerService extends MediaBrowserServiceCompat
    implements AudioManager.OnAudioFocusChangeListener {
  private static final String TAG = AudiofileplayerService.class.getSimpleName();
  private static final String MEDIA_ROOT_ID = "root";
  private static final String CHANNEL_ID = AudiofileplayerService.class.getName();
  private static final int NOTIFICATION_ID = 54321;

  static AudiofileplayerService instance;

  private AudiofileplayerService.ServiceListener listener;

  private MediaSessionCompat mediaSession;
  private MediaSessionCallback mediaSessionCallback;
  private MediaMetadataCompat metadata;
  private List<NotificationCompat.Action> notificationActions;
  private int[] compactNotificationActionIndices;

  private long playbackStateActions = 0;
  private int playbackStateState = PlaybackStateCompat.STATE_NONE;
  private long playbackStatePosition = 0;
  private float playbackStateSpeed = 0;

  public interface ServiceListener {
    void onMediaButtonClick(int keyCode);

    void onCustomMediaButtonClick(String eventId);

    void onSeekTo(long positionMs);
  }

  @Override
  public void onCreate() {
    super.onCreate();
    Log.i(TAG, "onCreate");
    instance = this;

    mediaSession = new MediaSessionCompat(this, TAG);
    mediaSession.setFlags(
            MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS
                    | MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS);
    PlaybackStateCompat.Builder stateBuilder =
            new PlaybackStateCompat.Builder()
                    .setActions(PlaybackStateCompat.ACTION_PLAY | PlaybackStateCompat.ACTION_PLAY_PAUSE);
    mediaSession.setPlaybackState(stateBuilder.build());

    mediaSessionCallback = new MediaSessionCallback(); // Do i need this as ivar?
    mediaSession.setCallback(mediaSessionCallback);
    setSessionToken(mediaSession.getSessionToken());
    AudioManager am = (AudioManager) getSystemService(AUDIO_SERVICE);
    mediaSession.setActive(true);
    AudioFocusRequest mFocusRequest = null;
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
      AudioAttributes mPlaybackAttributes = new AudioAttributes.Builder()
              .setUsage(AudioAttributes.USAGE_MEDIA)
              .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
              .build();
      mFocusRequest = new AudioFocusRequest.Builder(AUDIOFOCUS_GAIN)
              .setAudioAttributes(mPlaybackAttributes)
              .build();
      am.requestAudioFocus(mFocusRequest);
    } else if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.FROYO) {
      AudioManager.OnAudioFocusChangeListener onAudioFocusChangeListener = focusChange -> {
        switch (focusChange) {
          case AUDIOFOCUS_GAIN:
            break;
          case AudioManager.AUDIOFOCUS_GAIN_TRANSIENT:
            break;
          case AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK:
            break;
          case AudioManager.AUDIOFOCUS_LOSS:
            break;
          case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT:
            break;
          case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK:
            break;
        }
      };
      am.requestAudioFocus(onAudioFocusChangeListener, AudioManager.STREAM_MUSIC, AUDIOFOCUS_GAIN);
    }
  }


  @Override
  public BrowserRoot onGetRoot(String clientPackageName, int clientUid, Bundle rootHints) {
    Log.i(TAG, "onGetRoot");
    return new BrowserRoot(MEDIA_ROOT_ID, null);
  }

  @Override
  public void onLoadChildren(
      final String parentMediaId, final Result<List<MediaBrowserCompat.MediaItem>> result) {
    Log.i(TAG, "onLoadChildren");
    result.sendResult(null);
  }

  @Override
  public int onStartCommand(final Intent intent, int flags, int startId) {
    Log.i(TAG, "onStartCommand");
    if (Intent.ACTION_MEDIA_BUTTON.equals(intent.getAction())
        && intent.hasExtra(AudiofileplayerPlugin.CUSTOM_MEDIA_BUTTON_EXTRA_KEY)) {
      // Check for custom button intent.
      handleCustomButtonIntent(intent);
    } else {
      // If there is a KeyEvent in the intent, send it to the MediaButtonReceiver to pass to
      // its callbacks.
      MediaButtonReceiver.handleIntent(mediaSession, intent);
    }
    return super.onStartCommand(intent, flags, startId);
  }

  @Override
  public void onDestroy() {
    Log.i(TAG, "onDestroy");
    instance = null;
    mediaSession.release();
    clearNotification();
    super.onDestroy();
  }

  @Override
  public void onTaskRemoved(Intent rootIntent) {
    Log.i(TAG, "onTaskRemoved");
    stopForeground(true);
    stopSelf();
    super.onTaskRemoved(rootIntent);
  }

  @Override
  public void onAudioFocusChange(int focusChange) {
    Log.i(TAG, "onAudioFocusChange");
  }

  //  public methods

  public void setPendingIntentActivity(Activity activity) {
    Context context = activity.getApplicationContext();
    Intent intent = new Intent(context, activity.getClass());
    PendingIntent pendingIntent =
        PendingIntent.getActivity(context, 99, intent, PendingIntent.FLAG_UPDATE_CURRENT);
    mediaSession.setSessionActivity(pendingIntent);
  }

  public void setListener(AudiofileplayerService.ServiceListener listener) {
    this.listener = listener;
  }

  private void handleCustomButtonIntent(Intent intent) {
    String eventId =
        (String) intent.getExtras().get(AudiofileplayerPlugin.CUSTOM_MEDIA_BUTTON_EXTRA_KEY);
    Log.d(TAG, "Got custom button intent with eventId:" + eventId);
    if (listener != null){
      listener.onCustomMediaButtonClick(eventId);
    }
  }

  public void stop() {
    metadata = null;
    if (notificationActions != null) notificationActions.clear();
    PlaybackStateCompat.Builder builder =
        new PlaybackStateCompat.Builder()
            .setActions(0)
            .setState(PlaybackStateCompat.STATE_STOPPED, playbackStatePosition, 0.0f);
    mediaSession.setPlaybackState(builder.build());
    mediaSession.setActive(false);
    clearNotification();
    stopForeground(true);
    stopSelf();
  }

  public void setPlaybackStateActions(long actions) {
    this.playbackStateActions = actions;
    updatePlaybackState();
  }

  public void setPlaybackStateState(int playbackState, long position, float speed) {
    this.playbackStateState = playbackState;
    this.playbackStatePosition = position;
    this.playbackStateSpeed = speed;
    updatePlaybackState();
    updateNotification();
  }

  public void setMetadata(MediaMetadataCompat metadata) {
    this.metadata = metadata;
    mediaSession.setMetadata(metadata);
    updateNotification();
  }

  public void setActions(
      List<NotificationCompat.Action> actions, List<Integer> compactIndicesList) {
    this.notificationActions = actions;

    // Convert List<Integer> to int[].
    int[] compactIndices = null;
    if (compactIndicesList != null) {
      compactIndices = new int[compactIndicesList.size()];
      for (int i = 0; i < compactIndices.length; i++) {
        compactIndices[i] = compactIndicesList.get(i);
      }
    }
    this.compactNotificationActionIndices = compactIndices;

    updateNotification();
  }

  // private methods.

  private int getSmallIconId() {
    Context context = getApplicationContext();
    String iconUri = "mipmap/ic_launcher";

    try {
      ApplicationInfo ai =
          context
              .getPackageManager()
              .getApplicationInfo(context.getPackageName(), PackageManager.GET_META_DATA);
      Bundle bundle = ai.metaData;

      if (bundle != null && bundle.containsKey("ic_audiofileplayer")) {
        iconUri = bundle.getString("ic_audiofileplayer");
      }
    } catch (Throwable t) {
      Log.d(
          TAG,
          "There is no 'ic_audiofileplayer' in the metadata to load. Using the App Icon instead.");
    }

    return context.getResources().getIdentifier(iconUri, null, context.getPackageName());
  }

  private void updatePlaybackState() {
    PlaybackStateCompat.Builder stateBuilder =
        new PlaybackStateCompat.Builder()
            .setActions(playbackStateActions)
            .setState(playbackStateState, playbackStatePosition, playbackStateSpeed);
    mediaSession.setPlaybackState(stateBuilder.build());
  }

  private Notification buildNotification() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) createChannel();

    //
    CharSequence title =
        (metadata != null && metadata.getDescription().getTitle() != null)
            ? metadata.getDescription().getTitle()
            : "";

    CharSequence subtitle =
        (metadata != null && metadata.getDescription().getSubtitle() != null)
            ? metadata.getDescription().getSubtitle()
            : "";

    CharSequence description =
        (metadata != null && metadata.getDescription().getDescription() != null)
            ? metadata.getDescription().getDescription()
            : "";

    Bitmap bitmap = (metadata != null) ? metadata.getDescription().getIconBitmap() : null;

    NotificationCompat.Builder builder =
        new NotificationCompat.Builder(AudiofileplayerService.this, CHANNEL_ID);
    builder
        // Add the metadata/icons for the currently playing audio
        .setContentTitle(title)
        .setContentText(subtitle)
        .setSubText(description)
        .setLargeIcon(bitmap)
        .setSmallIcon(getSmallIconId())
        // Enable launching the player by clicking the notification
        .setContentIntent(mediaSession.getController().getSessionActivity())
        // Stop the service when the notification is swiped away
        .setDeleteIntent(
            MediaButtonReceiver.buildMediaButtonPendingIntent(
                this, PlaybackStateCompat.ACTION_STOP))
        // Make the transport controls visible on the lockscreen
        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        // Set the media style to show icons for the Actions.
        .setStyle(
            new MediaStyle()
                .setMediaSession(mediaSession.getSessionToken())
                .setShowActionsInCompactView(compactNotificationActionIndices)
                .setShowCancelButton(true)
                .setCancelButtonIntent(
                    MediaButtonReceiver.buildMediaButtonPendingIntent(
                        this, PlaybackStateCompat.ACTION_STOP)));

    // Add the actions specified by the client.
    if (notificationActions != null) {
      for (NotificationCompat.Action action : notificationActions) {
        builder.addAction(action);
      }
    }

    return builder.build();
  }

  @RequiresApi(Build.VERSION_CODES.O)
  private void createChannel() {
    NotificationManager notificationManager =
        (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
    NotificationChannel channel = notificationManager.getNotificationChannel(CHANNEL_ID);
    if (channel == null) {
      channel =
          new NotificationChannel(
              CHANNEL_ID,
              getString(R.string.notificationChannelName),
              NotificationManager.IMPORTANCE_LOW);
      notificationManager.createNotificationChannel(channel);
    }
  }

  public class MediaSessionCallback extends MediaSessionCompat.Callback {
    @Override
    public void onPlay() {
      Log.i(TAG, "MediaSessionCallback.onPlay");
      startService(new Intent(AudiofileplayerService.this, AudiofileplayerService.class));
      if (!mediaSession.isActive()) mediaSession.setActive(true);
      Notification notif = buildNotification();
      // Display the notification and place the service in the foreground
      startForeground(NOTIFICATION_ID, notif);
    }

    @Override
    public void onPause() {
      Log.i(TAG, "MediaSessionCallback.onPause");
    }

    @Override
    public void onStop() {
      Log.i(TAG, "MediaSessionCallback.onStop");
      stopForeground(true);
      stopSelf();
    }

    @Override
    public void onPrepare() {
      Log.i(TAG, "MediaSessionCallback.onPrepare");
    }

    @Override
    public boolean onMediaButtonEvent(Intent mediaButtonEvent) {
      Log.i(TAG, "MediaSessionCallback.onMediaButtonEvent:" + mediaButtonEvent.toString());

      final KeyEvent event = (KeyEvent) mediaButtonEvent.getExtras().get(Intent.EXTRA_KEY_EVENT);
      if (event.getAction() == KeyEvent.ACTION_DOWN) {
        Log.i(TAG, "event key code:" + event.getKeyCode());
        if (listener != null) {
          listener.onMediaButtonClick(event.getKeyCode());
        }
      }

      return true;
    }

    @Override
    public void onSeekTo(long positionMs) {
      Log.i(TAG, "MediaSessionCallback.onSeekTo:" + positionMs);
      if (listener != null) {
        listener.onSeekTo(positionMs);
      }
    }
  }

  private void updateNotification() {
    NotificationManager notificationManager =
            (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
    notificationManager.notify(NOTIFICATION_ID, buildNotification());
  }

  private void clearNotification() {
    NotificationManager notificationManager =
            (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
    notificationManager.cancel(NOTIFICATION_ID);
  }
}
