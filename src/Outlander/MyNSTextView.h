//
//  MyNSTextView.h
//  Outlander
//
//  Created by Joseph McBride on 5/20/14.
//  Copyright (c) 2014 Joe McBride. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface MyNSTextView : NSTextView 

@property (nonatomic, strong) RACSignal *keyupSignal;

@end
