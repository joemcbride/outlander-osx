//
//  ExecuteBlock.m
//  Outlander
//
//  Created by Joseph McBride on 6/13/14.
//  Copyright (c) 2014 Joe McBride. All rights reserved.
//

#import "ExecuteBlock.h"

@interface ExecuteBlock () {
    void(^_run)(id block, NSTimeInterval interval);
}
@end

@implementation ExecuteBlock

- (instancetype)initWith:(void(^)(id block, NSTimeInterval interval))runBlock {
    self = [super init];
    if(!self) return nil;
    
    _run = runBlock;
    
    return self;
}

- (void)run {
    [self runUntil:0];
}

- (void)runUntil:(NSTimeInterval)interval {
    _run(self, interval);
}

-(ExecuteBlock *)execute:(executeBlock)block {
    _doExecute = block;
    return self;
}

-(ExecuteBlock *)execute:(executeBlock)block done:(doneBlock)done {
    _doExecute = block;
    _doDone = done;
    
    return self;
}

@end
