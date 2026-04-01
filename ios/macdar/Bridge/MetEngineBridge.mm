#import "MetEngineBridge.h"

@implementation MetEngineBridge

+ (BOOL)isBundledRuntimeAvailable {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *frameworksPath = bundle.privateFrameworksPath;
    if (frameworksPath.length == 0) {
        return NO;
    }

    NSString *candidate = [frameworksPath stringByAppendingPathComponent:@"MetEngineFFI.framework"];
    return [[NSFileManager defaultManager] fileExistsAtPath:candidate];
}

+ (NSString *)expectedXCFrameworkName {
    return @"MetEngineFFI.xcframework";
}

@end
