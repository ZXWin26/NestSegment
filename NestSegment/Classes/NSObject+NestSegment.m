//
//  NSObject+NestSegment.m
//  NestSegment
//
//  Created by paul.yin on 2021/4/1.
//

#import "NSObject+NestSegment.h"
#import <objc/runtime.h>
#import "ZXSwizzleUtility.h"
#import <NestSegment/NestSegment-Swift.h>

@implementation NSObject (NestSegment)

+ (void)load {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self addDidScroll];
    });
    
}

+ (void)addDidScroll {
    
    NSString *methodName = NSStringFromSelector(@selector(scrollViewDidScroll:));
    
    unsigned int classCount;
    Class *classes = objc_copyClassList(&classCount);
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        Class superclass = cls;
        
        if (
            class_conformsToProtocol(superclass, @protocol(YFNestSegmentProtocol))) {
            [ZXSwizzleUtility swizzleMethod:superclass
                                     originMethod:NSSelectorFromString(methodName)
                                    replaceMethod:NSSelectorFromString([NSString stringWithFormat:@"basic_%@", methodName])
                                        addMethod:NSSelectorFromString([NSString stringWithFormat:@"basicAdd_%@", methodName])];
        }

    }
    
    free(classes);
    
}

- (void)basic_scrollViewDidScroll:(UIScrollView *)scrollView {
    [self basic_scrollViewDidScroll:scrollView];
    if (scrollView.yf_didScrollClosure) {
        scrollView.yf_didScrollClosure(scrollView);
    }
    
}

- (void)basicAdd_scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.yf_didScrollClosure) {
        scrollView.yf_didScrollClosure(scrollView);
    }
}

@end
