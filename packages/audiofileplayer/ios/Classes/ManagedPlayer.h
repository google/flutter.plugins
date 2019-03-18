#import <Foundation/Foundation.h>

@class FLTManagedPlayer;

@protocol FLTManagedPlayerDelegate

/**
 * Called by FLTManagedPlayer when a non-looping sound has finished playback,
 * or on calling stop().
 */
- (void)managedPlayerDidFinishPlaying:(NSString *)audioId;

/** Called by FLTManagedPlayer repeatedly while audio is playing. */
- (void)managedPlayerDidUpdatePosition:(NSTimeInterval)position forAudioId:(NSString *)audioId;

/** Called by FLTManagedPlayer when media is loaded and duration is known. */
- (void)managedPlayerDidLoadWithDuration:(NSTimeInterval)duration forAudioId:(NSString *)audioId;

@end

/** Wraps an AVAudioPlayer or AVPlayer for use by AudiofileplayerPlugin. */
@interface FLTManagedPlayer : NSObject

@property(nonatomic, readonly) NSString *audioId;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithAudioId:(NSString *)audioId
                           path:(NSString *)path
                       delegate:(id<FLTManagedPlayerDelegate>)delegate
                      isLooping:(bool)isLooping;

- (instancetype)initWithAudioId:(NSString *)audioId
                           data:(NSData *)data
                       delegate:(id<FLTManagedPlayerDelegate>)delegate
                      isLooping:(bool)isLooping;

- (instancetype)initWithAudioId:(NSString *)audioId
                      remoteUrl:(NSString *)urlString
                       delegate:(id<FLTManagedPlayerDelegate>)delegate
                      isLooping:(bool)isLooping
              remoteLoadHandler:(void (^)(BOOL))remoteLoadHandler;

- (void)play:(bool)playFromStart;
- (void)releasePlayer;
- (void)seek:(NSTimeInterval)position;
- (void)setVolume:(double)volume;
- (void)pause;

@end
