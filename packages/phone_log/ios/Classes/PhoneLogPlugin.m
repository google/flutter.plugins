#import "PhoneLogPlugin.h"

@implementation PhoneLogPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"github.com/jiajiabingcheng/phone_log"
            binaryMessenger:[registrar messenger]];
  PhoneLogPlugin* instance = [[PhoneLogPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"checkPermission" isEqualToString:call.method] ||
        [@"requestPermission" isEqualToString:call.method] ||
        [@"getPhoneLogs" isEqualToString:call.method]) {
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
