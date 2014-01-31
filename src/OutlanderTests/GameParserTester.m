//
//  GameParserTester.m
//  Outlander
//
//  Created by Joseph McBride on 1/24/14.
//  Copyright (c) 2014 Joe McBride. All rights reserved.
//

#import "Kiwi.h"
#import "GameParser.h"
#import "TextTag.h"

SPEC_BEGIN(GameParserTester)

describe(@"GameParser", ^{
    
    __block GameParser *_parser = [[GameParser alloc] init];
    
    context(@"parse", ^{
        
        it(@"should parse prompt", ^{
            NSString *prompt = @"<prompt time=\"1390623788\">&gt;</prompt>";
            
            __block TextTag *result = nil;
            
            [_parser parse:prompt then:^(NSArray* res) {
                result = res[0];
            }];
            
            [[[result text] should] equal:@">"];
        });
        
        it(@"should parse room name", ^{
            NSString *data = @"<resource picture=\"0\"/><style id=\"roomName\" />[Woodland Path, Brook]";
            
            __block TextTag *result = nil;
            
            [_parser parse:data then:^(NSArray* res) {
                result = res[0];
            }];
            
            [[[result text] should] equal:@"[Woodland Path, Brook]"];
            [[[result color] should] equal:@"#0000FF"];
        });

        it(@"should parse room description", ^{
            NSString *data = @"<style id=\"\"/><preset id='roomDesc'>This shallow stream would probably only come chest-high on a short Halfling.  The water moves lazily southward, but the shifting, sharp rocky floor makes crossing uncomfortable.</preset>  \n";
            
            __block TextTag *result = nil;
            
            [_parser parse:data then:^(NSArray* res) {
                result = res[0];
            }];
            
            [[[result text] should] equal:@"This shallow stream would probably only come chest-high on a short Halfling.  The water moves lazily southward, but the shifting, sharp rocky floor makes crossing uncomfortable.  \n"];
        });
        
        it(@"should handle exp mono", ^{
            NSString *data = @"<--><output class=\"mono\"/>\r\n"
            "<-->\r\n"
            "<-->Circle: 8\r\n"
            "<-->Showing all skills with field experience.\r\n"
            "<-->\r\n"
            "<-->          SKILL: Rank/Percent towards next rank/Amount learning/Mindstate Fraction\r\n"
            "<-->      Attunement:     61 11% perusing       (2/34)       Athletics:     51 39% thinking       (5/34)\r\n"
            "<-->\r\n"
            "<-->Total Ranks Displayed: 112\r\n"
            "<-->Time Development Points: 62  Favors: 4  Deaths: 0  Departs: 0\r\n"
            "<-->Overall state of mind: clear\r\n"
            "<-->EXP HELP for more information\r\n"
            "<--><output class=\"\"/>\r\n";
            
            NSArray *lines = [data componentsSeparatedByString:@"<-->"];
            
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            for(NSString *line in lines) {
                [_parser parse:[line stringByReplacingOccurrencesOfString:@"<-->" withString:@""] then:^(NSArray* res) {
                    [results addObjectsFromArray:res];
                    NSLog(@"%@", res);
                }];
            }
            
            [[results should] haveCountOf:11];
            TextTag *tag = results[1];
            [[theValue([tag mono]) should] beYes];
            
            tag = results[4];
            [[tag.text should] equal:@"          SKILL: Rank/Percent towards next rank/Amount learning/Mindstate Fraction\r\n"];
        });
        
        it(@"should ignore component tag newline", ^{
            NSString *data = @"<component id='room objs'></component>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
        });
        
        it(@"should ignore compdef tag newline", ^{
            NSString *data = @"<compDef id='exp Shield Usage'></compDef>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
        });
        
        it(@"should ignore dialogdata tag newline", ^{
            NSString *data = @"<dialogData id='minivitals'><skin id='manaSkin' name='manaBar' controls='mana' left='20%' top='0%' width='20%' height='100%'/><progressBar id='mana' value='100' text='mana 100%' left='20%' customText='t' top='0%' width='20%' height='100%'/></dialogData>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
        });
        
        it(@"should ignore streamwindow tag newline", ^{
            NSString *data = @"<streamWindow id='main' title='Story' subtitle=\" - [Woodland Path, Brook]\" location='center' target='drop'/>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
        });
        
        it(@"should ignore nav tag newline", ^{
            NSString *data = @"<nav/>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
        });
        
        it(@"should ignore opendialog tag newline", ^{
            NSString *data = @"<openDialog id='quick-blank' location='quickBar' title='Blank'><dialogData id='quick-blank' clear='true'></dialogData></openDialog>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
        });
        
        it(@"should ignore switchquickbar tag newline", ^{
            NSString *data = @"<switchQuickBar id='quick-simu'/>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
        });
        
        it(@"should ignore indicator tag newline", ^{
            NSString *data = @"<indicator id=\"IconKNEELING\" visible=\"n\"/><indicator id=\"IconPRONE\" visible=\"n\"/><indicator id=\"IconSITTING\" visible=\"n\"/><indicator id=\"IconSTANDING\" visible=\"y\"/><indicator id=\"IconSTUNNED\" visible=\"n\"/><indicator id=\"IconHIDDEN\" visible=\"n\"/><indicator id=\"IconINVISIBLE\" visible=\"n\"/><indicator id=\"IconDEAD\" visible=\"n\"/><indicator id=\"IconWEBBED\" visible=\"n\"/><indicator id=\"IconJOINED\" visible=\"n\"/>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
        });
        
        it(@"should color monsterbold", ^{
            NSString *data = @"<preset id='roomDesc'>For a moment you lose your sense of direction.  Bending down to gain a better perspective of the lie of the land, you manage to identify several landmarks and reorient yourself.</preset>  You also see <pushBold/>a musk hog<popBold/>, <pushBold/>a musk hog<popBold/> and <pushBold/>a musk hog<popBold/>.";
            
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:7];
        });
        
        it(@"should set roomdesc global var", ^{
            NSString *data = @"<preset id='roomDesc'>For a moment you lose your sense of direction.  Bending down to gain a better perspective of the lie of the land, you manage to identify several landmarks and reorient yourself.</preset>  You also see <pushBold/>a musk hog<popBold/>, <pushBold/>a musk hog<popBold/> and <pushBold/>a musk hog<popBold/>.";
            
            [_parser parse:data then:^(NSArray* res) {
            }];
            
            [[theValue([_parser.globalVars cacheDoesContain:@"roomdesc"]) should] beYes];
            
            NSString *roomDesc = [_parser.globalVars cacheObjectForKey:@"roomdesc"];
            [[roomDesc should] equal:@"For a moment you lose your sense of direction.  Bending down to gain a better perspective of the lie of the land, you manage to identify several landmarks and reorient yourself."];
        });

        it(@"should set roomobjs global var", ^{
            NSString *data = @"<component id='room objs'>You also see a two auroch caravan with several things on it.</component>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
            
            [[theValue([_parser.globalVars cacheDoesContain:@"roomobjs"]) should] beYes];
            
            NSString *roomObjs = [_parser.globalVars cacheObjectForKey:@"roomobjs"];
            [[roomObjs should] equal:@"You also see a two auroch caravan with several things on it."];
        });
        
        it(@"should set spell global var", ^{
            NSString *data = @"<spell>None</spell>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
            
            [[theValue([_parser.globalVars cacheDoesContain:@"spell"]) should] beYes];
            
            NSString *roomObjs = [_parser.globalVars cacheObjectForKey:@"spell"];
            [[roomObjs should] equal:@"None"];
        });

        it(@"should set left global var", ^{
            NSString *data = @"<left exist=\"41807070\" noun=\"longsword\">longsword</left>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
            
            [[theValue([_parser.globalVars cacheDoesContain:@"lefthand"]) should] beYes];
            
            [[[_parser.globalVars cacheObjectForKey:@"lefthand"] should] equal:@"longsword"];
            [[[_parser.globalVars cacheObjectForKey:@"lefthandid"] should] equal:@"41807070"];
            [[[_parser.globalVars cacheObjectForKey:@"lefthandnoun"] should] equal:@"longsword"];
        });
        
        it(@"should set left global var as Empty", ^{
            NSString *data = @"<left>Empty</left>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
            
            [[theValue([_parser.globalVars cacheDoesContain:@"lefthand"]) should] beYes];
            [[theValue([_parser.globalVars cacheDoesContain:@"lefthandid"]) should] beYes];
            [[theValue([_parser.globalVars cacheDoesContain:@"lefthandnoun"]) should] beYes];
            
            [[[_parser.globalVars cacheObjectForKey:@"lefthand"] should] equal:@"Empty"];
            [[[_parser.globalVars cacheObjectForKey:@"lefthandid"] should] equal:@""];
            [[[_parser.globalVars cacheObjectForKey:@"lefthandnoun"] should] equal:@""];
        });
        
        it(@"should set right global var", ^{
            NSString *data = @"<right exist=\"41807070\" noun=\"longsword\">longsword</right>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
            
            [[theValue([_parser.globalVars cacheDoesContain:@"righthand"]) should] beYes];
            [[theValue([_parser.globalVars cacheDoesContain:@"righthandid"]) should] beYes];
            [[theValue([_parser.globalVars cacheDoesContain:@"righthandnoun"]) should] beYes];
            
            [[[_parser.globalVars cacheObjectForKey:@"righthand"] should] equal:@"longsword"];
            [[[_parser.globalVars cacheObjectForKey:@"righthandid"] should] equal:@"41807070"];
            [[[_parser.globalVars cacheObjectForKey:@"righthandnoun"] should] equal:@"longsword"];
        });
        
        it(@"should set right global var as Empty", ^{
            NSString *data = @"<right>Empty</right>\r\n";
            __block NSMutableArray *results = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [results addObjectsFromArray:res];
            }];
            
            [[results should] haveCountOf:0];
            
            [[theValue([_parser.globalVars cacheDoesContain:@"righthand"]) should] beYes];
            [[theValue([_parser.globalVars cacheDoesContain:@"righthandid"]) should] beYes];
            [[theValue([_parser.globalVars cacheDoesContain:@"righthandnoun"]) should] beYes];
            
            [[[_parser.globalVars cacheObjectForKey:@"righthand"] should] equal:@"Empty"];
            [[[_parser.globalVars cacheObjectForKey:@"righthandid"] should] equal:@""];
            [[[_parser.globalVars cacheObjectForKey:@"righthandnoun"] should] equal:@""];
        });
        
        it(@"should signal arrivals", ^{
            NSString *data = @"<pushStream id=\"logons\"/> * Tayek joins the adventure.\r\n<popStream/>\r\n";
            __block NSMutableArray *parseResults = [[NSMutableArray alloc] init];
            __block NSMutableArray *signalResults = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [parseResults addObjectsFromArray:res];
            }];
            
            [_parser.arrivals subscribeNext:^(id x) {
                [signalResults addObject:x];
            }];
            
            [[parseResults should] haveCountOf:0];
            [[signalResults should] haveCountOf:1];
            
            TextTag *tag = signalResults[0];
            
            [[tag.text should] equal:@" * Tayek joins the adventure."];
        });
        
        it(@"should signal deaths", ^{
            NSString *data = @"<pushStream id=\"death\"/> * Tayek was just struck down!\r\n<popStream/>\r\n";
            __block NSMutableArray *parseResults = [[NSMutableArray alloc] init];
            __block NSMutableArray *signalResults = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [parseResults addObjectsFromArray:res];
            }];
            
            [_parser.deaths subscribeNext:^(id x) {
                [signalResults addObject:x];
            }];
            
            [[parseResults should] haveCountOf:0];
            [[signalResults should] haveCountOf:1];
            
            TextTag *tag = signalResults[0];
            
            [[tag.text should] equal:@" * Tayek was just struck down!"];
        });
        
        it(@"should signal thoughts", ^{
            NSString *data = @"<pushStream id=\"thoughts\"/><preset id='thought'>You hear your mental voice echo, </preset>\"Testing, one, two.\"\n<popStream/>\r\n";
            __block NSMutableArray *parseResults = [[NSMutableArray alloc] init];
            __block NSMutableArray *signalResults = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [parseResults addObjectsFromArray:res];
            }];
            
            [_parser.thoughts subscribeNext:^(id x) {
                [signalResults addObject:x];
            }];
            
            [[parseResults should] haveCountOf:0];
            [[signalResults should] haveCountOf:1];
            
            TextTag *tag = signalResults[0];
            
            [[tag.text should] equal:@"You hear your mental voice echo, \"Testing, one, two.\""];
        });
        
        it(@"should signal vitals", ^{
            NSString *data = @"<dialogData id='minivitals'><progressBar id='concentration' value='98' text='concentration 98%' left='80%' customText='t' top='0%' width='20%' height='100%'/></dialogData>\r\n";
            __block NSMutableArray *parseResults = [[NSMutableArray alloc] init];
            __block NSMutableArray *signalResults = [[NSMutableArray alloc] init];
            
            [_parser parse:data then:^(NSArray* res) {
                [parseResults addObjectsFromArray:res];
            }];
            
            [_parser.vitals subscribeNext:^(id x) {
                [signalResults addObject:x];
            }];
            
            [[parseResults should] haveCountOf:0];
            [[signalResults should] haveCountOf:1];
            
            TextTag *tag = signalResults[0];
            
            [[tag.text should] equal:@"You hear your mental voice echo, \"Testing, one, two.\""];
        });
    });
});

SPEC_END