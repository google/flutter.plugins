#import "AudiofileplayerPlugin.h"
#import "ManagedPlayer.h"

static NSString *const kChannel = @"audiofileplayer";
static NSString *const kLoadMethod = @"load";
static NSString *const kFlutterPath = @"flutterPath";
static NSString *const kAudioBytes = @"audioBytes";
static NSString *const kRemoteUrl = @"remoteUrl";
static NSString *const kAudioId = @"audioId";
static NSString *const kLooping = @"looping";
static NSString *const kReleaseMethod = @"release";
static NSString *const kPlayMethod = @"play";
static NSString *const kPlayFromStart = @"playFromStart";
static NSString *const kSeekMethod = @"seek";
static NSString *const kSetVolumeMethod = @"setVolume";
static NSString *const kVolume = @"volume";
static NSString *const kPauseMethod = @"pause";
static NSString *const kOnCompleteCallback = @"onComplete";
static NSString *const kOnDurationCallback = @"onDuration";
static NSString *const kDurationSeconds = @"duration_seconds";
static NSString *const kOnPositionCallback = @"onPosition";
static NSString *const kPositionSeconds = @"position_seconds";
static NSString *const kErrorCode = @"AudioPluginError";

@interface AudiofileplayerPlugin () <FLTManagedPlayerDelegate>
@end

@implementation AudiofileplayerPlugin {
  NSObject<FlutterPluginRegistrar> *_registrar;
  FlutterMethodChannel *_channel;
  NSMutableDictionary<NSString *, FLTManagedPlayer *> *_playersDict;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:kChannel binaryMessenger:[registrar messenger]];
  AudiofileplayerPlugin *instance = [[AudiofileplayerPlugin alloc] initWithRegistrar:registrar
                                                                             channel:channel];
  [registrar addMethodCallDelegate:instance channel:channel];
  [registrar addApplicationDelegate:instance];
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar
                          channel:(FlutterMethodChannel *)channel {
  self = [super init];
  if (self) {
    _registrar = registrar;
    _channel = channel;
    _playersDict = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSLog(@"handleMethodCall: method = %@", call.method);
  if ([call.method isEqualToString:@"load"]) {
    [self handleLoadWithCall:call result:result];
    return;
  }

  // All subsequent calls need a valid player.
  NSString *audioId = call.arguments[@"audioId"];
  if (!audioId) {
    result([FlutterError
        errorWithCode:kErrorCode
              message:[NSString
                          stringWithFormat:@"Received %@ call without an audioId", call.method]
              details:nil]);
    return;
  }
  FLTManagedPlayer *player = _playersDict[audioId];
  if (!player) {
    result([FlutterError
        errorWithCode:kErrorCode
              message:[NSString stringWithFormat:@"Called %@ on an unloaded player: %@",
                                                 call.method, audioId]
              details:nil]);
    return;
  }

  if ([call.method isEqualToString:kPlayMethod]) {
    bool playFromStart = [call.arguments[kPlayFromStart] boolValue];
    [player play:playFromStart];
    result(nil);
  } else if ([call.method isEqualToString:kReleaseMethod]) {
    [player releasePlayer];
    [_playersDict removeObjectForKey:audioId];
    result(nil);
  } else if ([call.method isEqualToString:kSeekMethod]) {
    NSTimeInterval position = [call.arguments[kPositionSeconds] doubleValue];
    [player seek:position];
    result(nil);
  } else if ([call.method isEqualToString:kSetVolumeMethod]) {
    double volume = [call.arguments[kVolume] doubleValue];
    [player setVolume:volume];
    result(nil);
  } else if ([call.method isEqualToString:kPauseMethod]) {
    [player pause];
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)handleLoadWithCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSString *audioId = call.arguments[kAudioId];
  if (!audioId) {
    result([FlutterError errorWithCode:kErrorCode
                               message:@"Received load call without an audioId"
                               details:nil]);
    return;
  }
  if (_playersDict[audioId]) {
    result([FlutterError
        errorWithCode:kErrorCode
              message:[NSString
                          stringWithFormat:@"Tried to load an already-loaded player: %@", audioId]
              details:nil]);
    return;
  }

  bool isLooping = [call.arguments[kLooping] boolValue];

  FLTManagedPlayer *player = nil;
  if (call.arguments[kFlutterPath] != [NSNull null]) {
    NSString *flutterPath = call.arguments[kFlutterPath];
    NSString *key = [_registrar lookupKeyForAsset:flutterPath];
    NSString *path = [[NSBundle mainBundle] pathForResource:key ofType:nil];
    if (!path) {
      result([FlutterError
          errorWithCode:kErrorCode
                message:[NSString stringWithFormat:
                                      @"Could not get path for flutter asset %@ for audio %@ ",
                                      flutterPath, audioId]
                details:nil]);
      return;
    }
    player = [[FLTManagedPlayer alloc] initWithAudioId:audioId
                                                  path:path
                                              delegate:self
                                             isLooping:isLooping];
    _playersDict[audioId] = player;
    result(nil);
  } else if (call.arguments[kAudioBytes] != [NSNull null]) {
    FlutterStandardTypedData *flutterData = call.arguments[kAudioBytes];
    player = [[FLTManagedPlayer alloc] initWithAudioId:audioId
                                                  data:[flutterData data]
                                              delegate:self
                                             isLooping:isLooping];
    _playersDict[audioId] = player;
    result(nil);
  } else if (call.arguments[kRemoteUrl] != [NSNull null]) {
    NSString *urlString = call.arguments[kRemoteUrl];
    // Load player, but wait for remote loading to succeed/fail before returning the methodCall.
    __weak AudiofileplayerPlugin *weakSelf = self;
    player = [[FLTManagedPlayer alloc]
          initWithAudioId:audioId
                remoteUrl:urlString
                 delegate:self
                isLooping:isLooping
        remoteLoadHandler:^(BOOL success) {
          if (success) {
            result(nil);
          } else {
            AudiofileplayerPlugin *strongSelf = weakSelf;
            if (strongSelf) {
              [strongSelf->_playersDict removeObjectForKey:audioId];
            }
            result([FlutterError
                errorWithCode:kErrorCode
                      message:[NSString
                                  stringWithFormat:@"Could not load remote URL %@ for player %@",
                                                   urlString, audioId]
                      details:nil]);
          }
        }];
    // Put AVPlayer into dictionary syncl'y on creation. Will be removed in the remoteLoadHandler
    // if remote loading fails.
    _playersDict[audioId] = player;
  } else {
    result([FlutterError errorWithCode:kErrorCode
                               message:@"Could not create ManagedMediaPlayer with neither "
                                       @"flutterPath nor audioBytes nor remoteUrl"
                               details:nil]);
  }
}

#pragma mark - FLTManagedPlayerDelegate

- (void)managedPlayerDidFinishPlaying:(NSString *)audioId {
  [_channel invokeMethod:kOnCompleteCallback arguments:@{kAudioId : audioId}];
}

- (void)managedPlayerDidUpdatePosition:(NSTimeInterval)position forAudioId:(NSString *)audioId {
  [_channel invokeMethod:kOnPositionCallback
               arguments:@{
                 kAudioId : audioId,
                 kPositionSeconds : @(position),
               }];
}

- (void)managedPlayerDidLoadWithDuration:(NSTimeInterval)duration forAudioId:(NSString *)audioId {
  [_channel invokeMethod:kOnDurationCallback
               arguments:@{
                 kAudioId : audioId,
                 kDurationSeconds : @(duration),
               }];
}

@end
