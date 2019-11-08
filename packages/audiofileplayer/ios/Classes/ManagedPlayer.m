#import "ManagedPlayer.h"

#import <AVFoundation/AVFoundation.h>

static NSString *const kKeyPathStatus = @"status";
static float const kTimerUpdateIntervalSeconds = 0.25;

@interface FLTManagedPlayer () <AVAudioPlayerDelegate>
@end

@implementation FLTManagedPlayer {
  __weak id<FLTManagedPlayerDelegate> _delegate;
  AVAudioPlayer *_audioPlayer;
  NSTimer *_positionTimer;

  AVPlayer *_avPlayer;
  id _completionObserver;            // Registered on NSNotificationCenter.
  id _timeObserver;                  // Registered on the AVPlayer.
  void (^_remoteLoadHandler)(BOOL);  // Called on AVPlayer loading status change observed.
}

// Private common initializer. [audioPlayer] or [avPlayer], but not both, must be set.
- (instancetype)initWithAudioId:(NSString *)audioId
                    audioPlayer:(AVAudioPlayer *)audioPlayer
                       avPlayer:(AVPlayer *)avPlayer
                       delegate:(id<FLTManagedPlayerDelegate>)delegate
                      isLooping:(bool)isLooping
              remoteLoadHandler:(void (^)(BOOL))remoteLoadHandler {
  // Assert init with either AVAudioPlayer or AVPlayer.
  if ((audioPlayer == nil) == (avPlayer == nil)) {
    NSLog(@"Must initialize with either audioPlayer or avPlayer");
    return nil;
  }
  self = [super init];
  if (self) {
    _audioId = [audioId copy];
    _delegate = delegate;
    if (audioPlayer) {
      _audioPlayer = audioPlayer;
      _audioPlayer.delegate = self;
      _audioPlayer.numberOfLoops = isLooping ? -1 : 0;
      [_audioPlayer prepareToPlay];
      [_delegate managedPlayerDidLoadWithDuration:_audioPlayer.duration forAudioId:_audioId];
      _positionTimer = [NSTimer
          scheduledTimerWithTimeInterval:kTimerUpdateIntervalSeconds
                                 repeats:YES
                                   block:^(NSTimer *timer) {
                                     if (_audioPlayer.playing) {
                                       [_delegate
                                           managedPlayerDidUpdatePosition:_audioPlayer.currentTime
                                                               forAudioId:_audioId];
                                     }
                                   }];
    } else {
      _avPlayer = avPlayer;
      _remoteLoadHandler = remoteLoadHandler;
      CMTime interval = CMTimeMakeWithSeconds(kTimerUpdateIntervalSeconds, NSEC_PER_SEC);
      FLTManagedPlayer *__weak weakSelf = self;
      _timeObserver = [_avPlayer
          addPeriodicTimeObserverForInterval:interval
                                       queue:nil
                                  usingBlock:^(CMTime time) {
                                    FLTManagedPlayer *strongSelf = weakSelf;
                                    if (strongSelf) {
                                      NSTimeInterval position =
                                          (NSTimeInterval)CMTimeGetSeconds(time);
                                      [strongSelf->_delegate
                                          managedPlayerDidUpdatePosition:position
                                                              forAudioId:strongSelf->_audioId];
                                    }
                                  }];
      _completionObserver = [[NSNotificationCenter defaultCenter]
          addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                      object:_avPlayer.currentItem
                       queue:nil
                  usingBlock:^(NSNotification *notif) {
                    [_avPlayer seekToTime:kCMTimeZero];
                    [_delegate managedPlayerDidFinishPlaying:_audioId];
                  }];
      [_avPlayer.currentItem addObserver:self
                              forKeyPath:kKeyPathStatus
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];
    }
  }
  return self;
}

- (instancetype)initWithAudioId:(NSString *)audioId
                           path:(NSString *)path
                       delegate:(id<FLTManagedPlayerDelegate>)delegate
                      isLooping:(bool)isLooping {
  AVAudioPlayer *audioPlayer =
      [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
  return [self initWithAudioId:audioId
                   audioPlayer:audioPlayer
                      avPlayer:nil
                      delegate:delegate
                     isLooping:isLooping
             remoteLoadHandler:nil];
}

- (instancetype)initWithAudioId:(NSString *)audioId
                           data:(NSData *)data
                       delegate:(id<FLTManagedPlayerDelegate>)delegate
                      isLooping:(bool)isLooping {
  AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithData:data error:nil];
  return [self initWithAudioId:audioId
                   audioPlayer:audioPlayer
                      avPlayer:nil
                      delegate:delegate
                     isLooping:isLooping
             remoteLoadHandler:nil];
}

- (instancetype)initWithAudioId:(NSString *)audioId
                      remoteUrl:(NSString *)urlString
                       delegate:(id<FLTManagedPlayerDelegate>)delegate
                      isLooping:(bool)isLooping
              remoteLoadHandler:(void (^)(BOOL))remoteLoadHandler {
  AVPlayerItem *avPlayerItem = [[AVPlayerItem alloc] initWithURL:[NSURL URLWithString:urlString]];
  AVPlayer *avPlayer = [[AVPlayer alloc] initWithPlayerItem:avPlayerItem];
  return [self initWithAudioId:audioId
                   audioPlayer:nil
                      avPlayer:avPlayer
                      delegate:delegate
                     isLooping:isLooping
             remoteLoadHandler:remoteLoadHandler];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:_completionObserver];
  [_avPlayer.currentItem removeObserver:self forKeyPath:kKeyPathStatus];
  [_avPlayer removeTimeObserver:_timeObserver];
}

- (void)play:(bool)playFromStart {
  if (_audioPlayer) {
    if (playFromStart) {
      _audioPlayer.currentTime = 0;
    }
    [_audioPlayer play];
  } else {
    if (playFromStart) {
      [_avPlayer seekToTime:kCMTimeZero];
    }
    [_avPlayer play];
  }
}

- (void)releasePlayer {
  if (_audioPlayer) {
    [_audioPlayer stop];  // Undoes the resource aquisition in [prepareToPlay].
    [_positionTimer invalidate];
    _positionTimer = nil;
  } else {
    [_avPlayer pause];
    [_avPlayer.currentItem removeObserver:self forKeyPath:kKeyPathStatus];
    [_avPlayer removeTimeObserver:_timeObserver];
    _avPlayer = nil;
  }
}

- (void)seek:(NSTimeInterval)position {
  if (_audioPlayer) {
    _audioPlayer.currentTime = position;
  } else {
    [_avPlayer seekToTime:CMTimeMakeWithSeconds(position, NSEC_PER_SEC)];
  }
}

- (void)setVolume:(double)volume {
  if (_audioPlayer) {
    _audioPlayer.volume = volume;
  } else {
    _avPlayer.volume = volume;
  }
}

- (void)pause {
  if (_audioPlayer) {
    [_audioPlayer pause];
  } else {
    [_avPlayer pause];
  }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if ([keyPath isEqualToString:kKeyPathStatus] && [object isKindOfClass:[AVPlayerItem class]]) {
    AVPlayerItem *item = (AVPlayerItem *)object;
    AVPlayerItemStatus status = [change[NSKeyValueChangeNewKey] integerValue];
    switch (status) {
      case AVPlayerItemStatusReadyToPlay: {
        NSTimeInterval duration = (NSTimeInterval)CMTimeGetSeconds(item.duration);
        _remoteLoadHandler(YES);
        [_delegate managedPlayerDidLoadWithDuration:duration forAudioId:_audioId];
        break;
      }
      case AVPlayerItemStatusFailed: {
        if (item.error.code == -11800) {
          NSLog(@"It looks like you are failing to load a remote asset. You probably requested a "
                @"non-http url, and didn't specify arbitrary url loading in your app transport "
                @"securty settings. Add an NSAppTransportSecurity entry to your Info.plist.");
        }
        _remoteLoadHandler(NO);
        break;
      }
      case AVPlayerItemStatusUnknown:
        _remoteLoadHandler(NO);
        break;
    }
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)audioPlayer successfully:(BOOL)flag {
  _audioPlayer.currentTime = 0;
  [_delegate managedPlayerDidFinishPlaying:_audioId];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)audioPlayer error:(NSError *)error {
}

@end
