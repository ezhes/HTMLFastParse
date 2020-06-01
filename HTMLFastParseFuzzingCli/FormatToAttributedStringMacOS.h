//
//  FormatToAttributedStringMacOS.h
//  HTMLFastParseFuzzingCli
//
//  Created by Allison Husain on 6/28/18.
//  Copyright © 2018 CarbonDev. All rights reserved.
//


/******
 
 NOTICE::: THIS IS NOT AN OSX IMPLMENTATION, THIS IS FOR FUZZING TO VERIFY SECURITY. IT IS FUNCTIONALLY THE SAME HOWEVER CERTAIN FONT NICEITIES ARE BROKEN!
 
 ******/

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
NS_ASSUME_NONNULL_BEGIN

@interface FormatToAttributedStringMacOS : NSObject
-(NSAttributedString *)attributedStringForHTML:(NSString *)htmlInput;
-(void)setDefaultFontColor:(NSColor *)defaultColor;
@end

NS_ASSUME_NONNULL_END
