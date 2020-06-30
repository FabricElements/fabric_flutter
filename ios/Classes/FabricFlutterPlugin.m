#import "FabricFlutterPlugin.h"
#if __has_include(<fabric_flutter/fabric_flutter-Swift.h>)
#import <fabric_flutter/fabric_flutter-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "fabric_flutter-Swift.h"
#endif

@implementation FabricFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFabricFlutterPlugin registerWithRegistrar:registrar];
}
@end
