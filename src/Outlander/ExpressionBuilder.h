//
//  ExpressionBuilder.h
//  Outlander
//
//  Created by Joseph McBride on 6/4/14.
//  Copyright (c) 2014 Joe McBride. All rights reserved.
//

#import <PEGKit/PEGKit.h>
#import "AssignmentToken.h"
#import "Atom.h"
#import "EchoToken.h"
#import "GotoToken.h"
#import "IdToken.h"
#import "LabelToken.h"
#import "MoveToken.h"
#import "PauseToken.h"
#import "PutToken.h"
#import "VarToken.h"
#import "WaitToken.h"

@interface ExpressionBuilder : NSObject

-(NSArray *)build:(NSString *)data;

@end