//
//  GameParser.m
//  Outlander
//
//  Created by Joseph McBride on 1/24/14.
//  Copyright (c) 2014 Joe McBride. All rights reserved.
//

#import "GameParser.h"
#import "Shared.h"
#import "HTMLNode.h"
#import "HTMLParser.h"
#import "TextTag.h"
#import "NSString+Files.h"

@implementation GameParser

-(id)init {
    self = [super init];
    if(self == nil) return nil;
    
    _subject = [RACReplaySubject subject];
    _globalVars = [[TSMutableDictionary alloc] initWithName:@"com.outlander.gobalvars"];
    _currenList = [[NSMutableArray alloc] init];
    _currentResult = [[NSMutableString alloc] init];
    _inStream = NO;
    _publishStream = YES;
    _bold = NO;
    _mono = NO;
    
    return self;
}

-(void) parse:(NSString*)data then:(CompleteBlock)block {
    NSError *error = nil;
    
    if(data == nil) return;
    
    data = [data stringByReplacingOccurrencesOfString:@"<style id=\"\"/>" withString:@""];
    data = [data stringByReplacingOccurrencesOfString:@"<d>" withString:@""];
    data = [data stringByReplacingOccurrencesOfString:@"<d/>" withString:@""];
    
    if([data length] == 0) return;
    
    if(![data containsString:@"<"]) {
        data = [NSString stringWithFormat:@"<pre>%@</pre>", data];
    }
    
    HTMLParser *parser = [[HTMLParser alloc] initWithString:data error:&error];
    
    if (error) {
        NSLog(@"Error: %@", error);
        return;
    }
    
    HTMLNode *bodyNode = [parser body];
    NSArray *children = [bodyNode children];
    NSUInteger count = [children count];
//    NSLog(@"Count: %lu", count);
    
    for (__block NSInteger i=0; i<count; i++) {
        HTMLNode *node = children[i];
//        NSLog(@"%@", [node tagName]);
        if([[node tagName] isEqualToString:@"prompt"]){
            NSString *time = [node getAttributeNamed:@"time"];
            NSString *prompt = [node contents];
            
            [_globalVars setCacheObject:prompt forKey:@"prompt"];
            [_globalVars setCacheObject:time forKey:@"time"];
            
            [_currentResult appendString:prompt];
        }
        else if([[node tagName] isEqualToString:@"pushstream"]) {
            _inStream = YES;
            _streamId = [node getAttributeNamed:@"id"];
            if([_streamId isEqualToString:@"inv"]) _publishStream = NO;
            else _publishStream = YES;
            
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"popstream"]) {
            _inStream = NO;
            _streamId = nil;
            _publishStream = YES;
            
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"spell"]) {
            [_globalVars setCacheObject:[node contents] forKey:@"spell"];
            
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"left"]) {
            NSString *val = [node contents];
            [_globalVars setCacheObject:val forKey:@"lefthand"];
            [_globalVars setCacheObject:[node getAttributeNamed:@"exist"] forKey:@"lefthandid"];
            [_globalVars setCacheObject:[node getAttributeNamed:@"noun"] forKey:@"lefthandnoun"];

            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"right"]) {
            NSString *val = [node contents];
            [_globalVars setCacheObject:val forKey:@"righthand"];
            [_globalVars setCacheObject:[node getAttributeNamed:@"exist"] forKey:@"righthandid"];
            [_globalVars setCacheObject:[node getAttributeNamed:@"noun"] forKey:@"righthandnoun"];

            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"clearstream"]) {
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"pushbold"]) {
            if([_currentResult length] > 0){
                TextTag *tag = [TextTag tagFor:[NSString stringWithString:_currentResult] mono:_mono];
                [_currentResult setString:@""];
                [_currenList addObject:tag];
            }
            _bold = YES;
        }
        else if([[node tagName] isEqualToString:@"popbold"]) {
            if([_currentResult length] > 0){
                TextTag *tag = [TextTag tagFor:[NSString stringWithString:_currentResult] mono:_mono];
                tag.color = @"#FFFF00";
                [_currentResult setString:@""];
                [_currenList addObject:tag];
            }
            _bold = NO;
        }
        else if([[node tagName] isEqualToString:@"component"]) {
            NSString *compId = [node getAttributeNamed:@"id"];
            
            if (compId != nil && [compId length] >-0) {
                compId = [compId stringByReplacingOccurrencesOfString:@" " withString:@""];
                NSString *raw = [node contents];
                [_globalVars setCacheObject:raw forKey:compId];
            }
            
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"compdef"]) {
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"style"]) {
            
            NSString *attr = [node getAttributeNamed:@"id"];
            if ([attr isEqualToString:@"roomName"]){
                HTMLNode *roomnode = children[i+1];
                NSString *val = [roomnode rawContents];
                [_globalVars setCacheObject:val forKey:@"roomname"];
                TextTag *tag = [TextTag tagFor:[NSString stringWithString:val] mono:_mono];
                tag.color = @"#0000FF";
                [_currenList addObject:tag];
                i++;
            }
            
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"dialogdata"]) {
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"opendialog"]) {
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"switchquickbar"]) {
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"streamwindow"]) {
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"indicator"]) {
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"nav"]) {
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"mode"]) {
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"app"]) {
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"endsetup"]) {
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"output"]) {
            NSString *attr = [node getAttributeNamed:@"class"];
            if([attr isEqual: @"mono"]) _mono = YES;
            else _mono = NO;
            if([self isNextNodeNewline:children index:i]) {
                i++;
            }
        }
        else if([[node tagName] isEqualToString:@"preset"]){
            NSString *val = [node contents];
            NSString *attr = [node getAttributeNamed:@"id"];
            
            if([attr isEqualToString:@"roomDesc"]) {
                [_globalVars setCacheObject:val forKey:@"roomdesc"];
            }
            
            if(![attr isEqualToString:@"speech"])
                [_currentResult appendString:val];
        }
        else if([[node tagName] isEqualToString:@"p"]){
            NSString *val = [node contents];
            NSLog(@"raw: %@", [node rawContents]);
            [_currentResult appendString:val];
        }
        else if([[node tagName] isEqualToString:@"pre"]){
            if(!_publishStream) {
                if([self isNextNodeNewline:children index:i]) {
                    i++;
                }
                continue;
            }
            
            NSString *val = [node contents];
            NSLog(@"%@", [node rawContents]);
            [_currentResult appendString:val];
        }
        else if([[node tagName] isEqualToString:@"text"]){
            if(!_publishStream) {
                if([self isNextNodeNewline:children index:i]) {
                    i++;
                }
                continue;
            }
            
            NSString *val = [node rawContents];
//            NSLog(@"text:%@", val);
            
            [_currentResult appendString:val];
        }
    }
    if(!_inStream && [_currentResult length] > 0){
        TextTag *tag = [TextTag tagFor:[NSString stringWithString:_currentResult] mono:_mono];
        if (_bold) {
            tag.color = @"#FFFF00";
        }
        [_currentResult setString:@""];
        [_currenList addObject:tag];
    }
    
    if ([_currenList count] > 0) {
        NSArray *items = [NSArray arrayWithArray:_currenList];
        block(items);
        [_subject sendNext:items];
        [_currenList removeAllObjects];
    }
}

-(BOOL) isNextNodeNewline:(NSArray *)array index:(NSUInteger)index {
    BOOL isNewLine = NO;
    NSUInteger next = index + 1;
    
    if(next < [array count]) {
        HTMLNode *node = array[next];
        if([[node tagName] isEqualToString:@"text"]){
            NSString *contents = [node rawContents];
            isNewLine = [contents isEqualToString:@"\r\n"];
        }
    }
    
    return isNewLine;
}

-(void) ifNext:(PredicateBlock)filter then:(CompleteBlock)then {
    if(filter(nil)) {
        then(nil);
    }
}

@end
