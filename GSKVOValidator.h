//
//  GSKVOValidator.h
//  GSKVOValidator
//
//  Created by Brook on 2017/5/12.
//  Copyright © 2017年 Brook. All rights reserved.
//  利用KVO监听相关属性的是否满足要求

#import <Foundation/Foundation.h>

@interface GSKVOAction<__covariant Observable> : NSObject

/**
 构造监听
 
 @param observee 监听对象
 @param keyPath 监听keyPath
 @param canRetain 是否可以retain该监听对象，如果其为 validator 的 持有者传NO，否则传YES
 @param block 回调
 @return 构造实例
 */
- (instancetype)initWithObservee:(Observable)observee
                         keyPath:(NSString *)keyPath
                       canRetain:(BOOL)canRetain
                           block:(BOOL(^)(Observable observee, NSString *keyPath))block;

/// 另外一种回调样式的构造方法
- (instancetype)initWithObservee:(Observable)observee
                      capturable:(BOOL)capturable
                         keyPath:(NSString *)keyPath
                       validator:(BOOL (^)(GSKVOAction<Observable> *action))validator;

@property (nonatomic, readonly) Observable observee;
@property (nonatomic, readonly) NSString *keyPath;

@end

@interface GSKVOValidator : NSObject

/**
 构造监听确认处理
 
 @param actions 需要监听的事件
 @param allValidate 需要进行整体判断的处理
 @param result 监听的结果
 @return 构造实例
 */
- (instancetype)initWithActions:(NSArray <GSKVOAction *> *)actions
                    allValidate:(BOOL(^)(NSArray <GSKVOAction *> *))allValidate
                         result:(void(^)(BOOL succeed, NSArray *actions, GSKVOAction *failed))result;

// 同上，不需要进行整体判断
- (instancetype)initWithActions:(NSArray <GSKVOAction *> *)actions
                         result:(void(^)(BOOL succeed, NSArray *actions, GSKVOAction *failed))result;

/// 最近是否有效
@property (nonatomic, assign, readonly) BOOL isRecentValid;

/// 调用此方法将手动调用回调
- (BOOL)validate;

/// 移除 KVO 监听
/// 此方法的调用 **不是** 必须的
- (BOOL)removeKVO;

@end
