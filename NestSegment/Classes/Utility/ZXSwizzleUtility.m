//
//  ZXSwizzleUtility.m
//  NestSegment
//
//  Created by paul.yin on 2021/4/24.
//

#import "ZXSwizzleUtility.h"
#import <objc/runtime.h>

@implementation ZXSwizzleUtility

+ (void)swizzleMethod:(Class)anClass originMethod:(SEL)originMethod replaceMethod:(SEL)replaceMethod addMethod:(SEL)addMethod {
    
    Method originalMethod = class_getInstanceMethod(anClass, originMethod);
    Method swizzledMethod = class_getInstanceMethod(anClass, replaceMethod);
    Method addedMethod = class_getInstanceMethod(anClass, addMethod);
    
    if (!originalMethod) {
        if (addedMethod) {
            class_addMethod(anClass,
                                originMethod,
                                method_getImplementation(addedMethod),
                                method_getTypeEncoding(addedMethod));
        } else {
            NSLog(@"%@ - %@ originalMethod and addMethod  not exist, add method fail", anClass, NSStringFromSelector(originMethod));
        }
    }
    
    else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
    
}

@end
