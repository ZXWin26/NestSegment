//
//  ZXSwizzleUtility.h
//  NestSegment
//
//  Created by paul.yin on 2021/4/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZXSwizzleUtility : NSObject

/// 若originMethod已实现，使用replaceMethod进行swizzle
/// 若originMethod未实现，添加originMethod使用addMethod的IMP
+ (void)swizzleMethod:(Class)anClass originMethod:(SEL)originMethod replaceMethod:(SEL)replaceMethod addMethod:(SEL)addMethod;

@end

NS_ASSUME_NONNULL_END
