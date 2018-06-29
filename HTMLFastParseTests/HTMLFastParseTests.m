//
//  HTMLFastParseTests.m
//  HTMLFastParseTests
//
//  Created by Salman Husain on 6/28/18.
//  Copyright © 2018 CarbonDev. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "FormatToAttributedString.h"
#import "C_HTML_Parser.h"
@interface HTMLFastParseTests : XCTestCase
@property (nonatomic,strong) NSDictionary *testData;
@property (nonatomic,strong) NSDictionary *answerData;
@end

@implementation HTMLFastParseTests

-(BOOL)testAttributedFormatUsingDebugDescriptionKey:(NSString *)key {
    FormatToAttributedString * formatter = [[FormatToAttributedString alloc]init];
    NSString *testData = [_testData objectForKey:key];
    NSAttributedString *output = [formatter attributedStringForHTML:testData];
    
    NSString *answer = [_answerData objectForKey:key];
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<.*?>" options:NSRegularExpressionCaseInsensitive error:&error];
    answer = [regex stringByReplacingMatchesInString:answer options:0 range:NSMakeRange(0, [answer length]) withTemplate:@""];

    NSString * outputDescription = [output debugDescription];
    outputDescription = [regex stringByReplacingMatchesInString:outputDescription options:0 range:NSMakeRange(0, [outputDescription length]) withTemplate:@""];

    BOOL areEqual = [answer isEqualToString:outputDescription];
    if (areEqual == false) {
        NSLog(@"OUTPUT: %@",outputDescription);
        NSLog(@"ANSWER: %@",answer);
    }
    return areEqual;
}


/**
 Generate code for all the test case pairs based on the AnswerData.plist
 */
-(void)generateTestCodeFromAnswerData {
    for (NSString* key in _answerData.allKeys) {
        printf("-(void)test%s {\nXCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@\"%s\"]);\n}\n\n",[key cStringUsingEncoding:NSUTF8StringEncoding],[key cStringUsingEncoding:NSUTF8StringEncoding]);
    }
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _testData = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleForClass:[self class]]pathForResource:@"TestData" ofType:@"plist"]];
    _answerData = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleForClass:[self class]]pathForResource:@"AnswerData" ofType:@"plist"]];
    [self generateTestCodeFromAnswerData];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


/*
 AUTO GENERATED QUESTION ANSWER TESTS
 */
-(void)testBasicHeaders {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"BasicHeaders"]);
}

-(void)testNoTags {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"NoTags"]);
}

-(void)testTwoByteEmojiFormatter {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"TwoByteEmojiFormatter"]);
}

-(void)testFormattingOnHeaders {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"FormattingOnHeaders"]);
}

-(void)testBlockCode {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"BlockCode"]);
}

-(void)testPlainBoldItalicsCombo {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"PlainBoldItalicsCombo"]);
}

-(void)testUnterminatedOpeningAndWithoutLabel {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"UnterminatedOpeningAndWithoutLabel"]);
}

-(void)testBrokenManyByteEmojiFormatter {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"BrokenManyByteEmojiFormatter"]);
}

-(void)testBlockquote {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"Blockquote"]);
}

-(void)testThreeByteEmojiFormatter {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"ThreeByteEmojiFormatter"]);
}

-(void)testClosingTagBeforeOpening {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"ClosingTagBeforeOpening"]);
}

-(void)testInlineCode {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"InlineCode"]);
}

-(void)testLink {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"Link"]);
}

-(void)testOpenedButNotClosedTag {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"OpenedButNotClosedTag"]);
}

-(void)testTerminatingTagWithNoOpening {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"TerminatingTagWithNoOpening"]);
}

-(void)testTerminatingTagWithNoOpeningButLabel {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"TerminatingTagWithNoOpeningButLabel"]);
}

-(void)testFourByteEmojiFormatter {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"FourByteEmojiFormatter"]);
}

/*
 Other, manual tests
 */

-(void)testTwoMegabytesOfDevRandom {
    FormatToAttributedString * formatter = [[FormatToAttributedString alloc]init];
    //Disable depreacted warning. This is important because obviously we can't open random garbage with an encoding because it doesn't have one. It will be nil if we try, so we open agnositcly and get a string of garbage
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    NSString *testData = [NSString stringWithContentsOfFile:[[NSBundle bundleForClass:[self class]]pathForResource:@"2MB_dev_random" ofType:@"txt"]];
#pragma GCC diagnostic pop
    NSAttributedString *output = [formatter attributedStringForHTML:testData];
    XCTAssert([output length] > 0);
}

-(void)testVeryLongTag {
    NSString *longTagName = [@"" stringByPaddingToLength:50000 withString:@"A" startingAtIndex:0];
    NSString *testData = [NSString stringWithFormat:@"<%@>TEST</%@>",longTagName,longTagName];
    
    FormatToAttributedString * formatter = [[FormatToAttributedString alloc]init];
    NSAttributedString *output = [formatter attributedStringForHTML:testData];
    XCTAssert([output length] == 4);
}

/*
 
 PERFORMANCE TESTS
 
 */

- (void)testLargeStringPerformance {
    FormatToAttributedString * formatter = [[FormatToAttributedString alloc]init];
    NSString *testData = [_testData objectForKey:@"MarkdownExplainer"];
    [self measureBlock:^{
        for (int i = 0; i < 1000; i++) {
            [formatter attributedStringForHTML:testData];
        }
    }];
}

- (void)testSmallStringPerformance {
    FormatToAttributedString * formatter = [[FormatToAttributedString alloc]init];
    NSString *testData = [_testData objectForKey:@"SingleChar"];
    [self measureBlock:^{
        for (int i = 0; i < 5000; i++) {
            [formatter attributedStringForHTML:testData];
        }
    }];
}

@end
