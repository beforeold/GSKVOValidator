//
//  GSKVOValidator.m
//  GSKVOValidator
//
//  Created by Brook on 2017/5/12.
//  Copyright © 2017年 Brook. All rights reserved.
//

#import "GSKVOValidator.h"

@protocol GSKVOActionDelegate <NSObject>

- (void)kvoActionDidChange:(GSKVOAction *)action;

@end

@interface GSKVOAction<Observable> ()

@property (nonatomic, weak) id <GSKVOActionDelegate> internalDelegate;
@property (nonatomic, readonly) BOOL(^validator)(GSKVOAction<Observable> *action);

- (BOOL)removeKVO;

@end

@interface GSKVOValidator () <GSKVOActionDelegate>

@property (nonatomic, readonly) NSArray <GSKVOAction *> *actions;
@property (nonatomic, readonly) BOOL(^allValidate)(NSArray *actions);
@property (nonatomic, readonly) void(^result)(BOOL succeed, NSArray *actions, GSKVOAction *failed);

@end

@implementation GSKVOValidator
#pragma mark - API
- (instancetype)initWithActions:(NSArray<GSKVOAction *> *)actions
                         result:(void(^)(BOOL succeed, NSArray *actions, GSKVOAction *failed))result {
    return [self initWithActions:actions allValidate:nil result:result];
}

- (instancetype)initWithActions:(NSArray<GSKVOAction *> *)actions
                    allValidate:(BOOL (^)(NSArray <GSKVOAction *> *))allValidate
                         result:(void (^)(BOOL, NSArray *, GSKVOAction *))result {
    self = [super init];
    if (self) {
        
        _actions = [actions copy];
        _allValidate = [allValidate copy];
        _result = [result copy];
        
        [_actions makeObjectsPerformSelector:@selector(setInternalDelegate:) withObject:self];
    }
    
    return self;
}

- (BOOL)validate {
    [self kvoActionDidChange:nil];
    
    return _isRecentValid;
}

- (BOOL)removeKVO {
    BOOL removed = YES;
    for (GSKVOAction *action in self.actions) {
        removed &= [action removeKVO];
    }
    
    return removed;
}

#pragma mark - protocol
- (void)kvoActionDidChange:(GSKVOAction *)action {
    if (action.validator && !action.validator(action)) {
        [self handleResult:NO failed:action];
        return;
    }
    
    BOOL validateOK = YES;
    GSKVOAction *failed = nil;
    for (GSKVOAction *item in self.actions) {
        if (!item.validator) continue;
        if (item == action) continue;
        
        validateOK &= item.validator(item);
        if (!validateOK) {
            failed = item;
            [self handleResult:NO failed:failed];
            return;
        }
    }
    
    if (self.allValidate) {
        validateOK &= self.allValidate(self.actions);
    }
    
    [self handleResult:validateOK failed:failed];
}

- (BOOL)handleResult:(BOOL)ret failed:(GSKVOAction *)failed {
    _isRecentValid = ret;
    
    !self.result ?: self.result(ret, self.actions, failed);
    
    return _isRecentValid;
}

@end

@protocol Observable <NSObject> @end

@interface GSKVOAction <Observable>()

/*注意这里不使用 weak，因为会在 observee 对象释放时导致无法引用到*/
@property (nonatomic, unsafe_unretained, readonly) Observable observee_assign;
@property (nonatomic, strong, readonly) Observable observee_retain;

@property (nonatomic, assign) BOOL hasRemovedKVO;
@property (nonatomic, assign, getter=isCapturable) BOOL capturable;

@end

@implementation GSKVOAction
- (instancetype)initWithObservee:(id)observee
                         keyPath:(NSString *)keyPath
                       canRetain:(BOOL)canRetain
                           block:(BOOL (^)(id observee, NSString *keyPath))block {
    id validator = nil;
    if (block) {
        validator = ^BOOL(GSKVOAction *action){ return block(action.observee, action.keyPath); };
    }
    
    return [self initWithObservee:observee capturable:canRetain keyPath:keyPath validator:validator];
}

- (instancetype)initWithObservee:(id)observee
                      capturable:(BOOL)capturable
                         keyPath:(NSString *)keyPath
                       validator:(BOOL (^)(GSKVOAction<id> *action))validator // 真是烦死我了，泛型在 .m 必须用 id 替代
{
    self = [super init];
    if (self) {
        NSParameterAssert(observee);
        NSParameterAssert(keyPath);
        
        if (capturable) {
            _observee_retain = observee;
        } else {
            _observee_assign = observee;
        }
        
        _capturable = capturable;
        _keyPath = [keyPath copy];
        _validator = [validator copy];
        
        [self.observee addObserver:self forKeyPath:_keyPath options:NSKeyValueObservingOptionNew context:NULL];
    }
    
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (![keyPath isEqualToString:self.keyPath]) return;
    
    if (self.internalDelegate) {
        [self.internalDelegate kvoActionDidChange:self];
        
    } else if (self.validator) {
        self.validator(self);
    }
}

- (BOOL)removeKVO {
    if (self.hasRemovedKVO) return NO;
    
    [self.observee removeObserver:self forKeyPath:self.keyPath context:NULL];
    self.hasRemovedKVO = YES;
    
    return YES;
}

- (void)dealloc {
    [self removeKVO];
}

- (id)observee {
    return self.isCapturable ? self.observee_retain : self.observee_assign;
}

@end
