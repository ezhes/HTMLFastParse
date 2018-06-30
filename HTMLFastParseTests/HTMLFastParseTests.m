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
        //NSLog(@"ANSWER: %@",answer);
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

/**
 Regenerate the answer data from the test cases defined in TestData (but used in the existing Answer plist)
 This is useful if you KNOW!!! all your unit tests are already passing but you now need to change some major formatting that effects everything (system font, etc)
 */
-(void)generateAnswerData {
    NSMutableDictionary *answerDataNew = [[NSMutableDictionary alloc]init];
    for (NSString* key in _answerData.allKeys) {
        FormatToAttributedString * formatter = [[FormatToAttributedString alloc]init];
        NSAttributedString *output = [formatter attributedStringForHTML:_testData[key]];
        [answerDataNew setObject:[output debugDescription] forKey:key];
    }
    
    [answerDataNew writeToFile:@"/tmp/AnswerData.plist" atomically:YES];
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _testData = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleForClass:[self class]]pathForResource:@"TestData" ofType:@"plist"]];
    _answerData = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleForClass:[self class]]pathForResource:@"AnswerData" ofType:@"plist"]];
    //[self generateTestCodeFromAnswerData];
    //[self generateAnswerData];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


/*
 AUTO GENERATED QUESTION ANSWER TESTS
 
 THESE TESTS REQUIRE THE SIMULATOR TO BE ON THE REGULAR ACCESSIBILITY FONT SIZE, SORRY!
 */
-(void)testBadURLDefinitionAFLCrash {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"BadURLDefinitionAFLCrash"]);
}

-(void)testHTMLEntityInsertsNullByte {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"HTMLEntityInsertsNullByte"]);
}

-(void)testLink {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"Link"]);
}

-(void)testFourByteEmojiFormatter {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"FourByteEmojiFormatter"]);
}

-(void)testFormattingOnHeaders {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"FormattingOnHeaders"]);
}

-(void)testBasicHeaders {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"BasicHeaders"]);
}

-(void)testTwoByteEmojiFormatter {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"TwoByteEmojiFormatter"]);
}

-(void)testInlineCode {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"InlineCode"]);
}

-(void)testHTMLEntityDecode {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"HTMLEntityDecode"]);
}

-(void)testTerminatingTagWithNoOpening {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"TerminatingTagWithNoOpening"]);
}

-(void)testBlockquote {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"Blockquote"]);
}

-(void)testUnicodeHeapOverFlowBadNSStringLength1 {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"UnicodeHeapOverFlowBadNSStringLength1"]);
}

-(void)testUnterminatedOpeningAndWithoutLabel {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"UnterminatedOpeningAndWithoutLabel"]);
}

-(void)testClosingTagBeforeOpening {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"ClosingTagBeforeOpening"]);
}

-(void)testThreeByteEmojiFormatter {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"ThreeByteEmojiFormatter"]);
}

-(void)testSoloHTMLEntityHeapOverflow {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"SoloHTMLEntityHeapOverflow"]);
}

-(void)testBrokenManyByteEmojiFormatter {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"BrokenManyByteEmojiFormatter"]);
}

-(void)testTerminatingTagWithNoOpeningButLabel {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"TerminatingTagWithNoOpeningButLabel"]);
}

-(void)testBlockCode {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"BlockCode"]);
}

-(void)testOpenedButNotClosedTag {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"OpenedButNotClosedTag"]);
}

-(void)testNoTags {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"NoTags"]);
}

-(void)testPlainBoldItalicsCombo {
    XCTAssert([self testAttributedFormatUsingDebugDescriptionKey:@"PlainBoldItalicsCombo"]);
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

-(void)testNonUTF8InputCrash {
    //AFL found a weird bug where if the input cannot be converted to UTF8 (for whatever reason)
    FormatToAttributedString * formatter = [[FormatToAttributedString alloc]init];
    //Disable depreacted warning. This is important because obviously we can't open random garbage with an encoding because it doesn't have one. It will be nil if we try, so we open agnositcly and get a string of garbage
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    NSString *testData = [NSString stringWithContentsOfFile:[[NSBundle bundleForClass:[self class]]pathForResource:@"non_utf8_fuzzer_crash" ofType:@"txt"]];
#pragma GCC diagnostic pop
    NSAttributedString *output = [formatter attributedStringForHTML:testData];
    //We expect that unparsable data is replaced with a failure warning
    XCTAssert([output length] == 231);
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
