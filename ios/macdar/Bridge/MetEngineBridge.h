#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MetEngineBridge : NSObject

+ (BOOL)isBundledRuntimeAvailable;
+ (NSString *)expectedXCFrameworkName;

@end

NS_ASSUME_NONNULL_END
