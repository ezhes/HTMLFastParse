//
//  HFPFormatToAttributedString.m
//  HTMLFastParse
//
//  Created by Allison Husain on 5/14/21.
//

#import <Foundation/Foundation.h>
#import "HFPFormatToAttributedString.h"

#if TARGET_OS_EMBEDDED
#define HFPFont UIFont
#define HFPColor UIColor
#else /* if TARGET_OS_EMBEDDED */
#define HFPFont NSFont
#define HFPColor NSColor
#endif /* if not TARGET_OS_EMBEDDED */


@implementation HFPFormatToAttributedString {
    /* font cache */
    HFPFont *plainFont;
    HFPFont *boldFont;
    HFPFont *italicsFont;
    HFPFont *italicsBoldFont;
    HFPFont *codeFont;
    
    /* color cache */
    HFPColor *defaultFontColor;
    HFPColor *codeFontColor;
    HFPColor *containerBackgroundColor;
    HFPColor *quoteFontColor;
    HFPColor *linkColor;
    
    /* paragraph quote style cache */
    NSMutableParagraphStyle *quoteParagraphStyle1;
    NSMutableParagraphStyle *quoteParagraphStyle2;
    NSMutableParagraphStyle *quoteParagraphStyle3;
    NSMutableParagraphStyle *quoteParagraphStyle4;
    NSMutableParagraphStyle *defaultParagraphStyle;
    
    /// This is the size of the plain font which is used as the source of truth for text scaling
    CGFloat baseFontSize;
}

- (instancetype)init {
    if (!(self = [super init])) {
        return NULL;
    }
    
    /* default fonts */
    
    /* default colors */
    codeFontColor = [HFPColor colorWithRed:1 green:0 blue:0 alpha:1];
    containerBackgroundColor = [HFPColor colorWithRed:242.0/255 green:242.0/255 blue:242.0/255 alpha:1];
    quoteFontColor = [HFPColor colorWithRed:119.0/255 green:119.0/255 blue:119.0/255 alpha:1];
    linkColor = [HFPColor colorWithRed:9.0/255 green:95.0/255 blue:255.0/255 alpha:1];
    defaultFontColor = [HFPColor blackColor];

    
    return self;
}

- (void)configureFonts {
//    NSFontDescriptor * f = [NSFontDescriptor preferredFontDescriptorForTextStyle:NSFontTextStyleBody options:@{}];
}

/// Generate the attributed string for a given HTML string
/// @param htmlInput The HTML string to attribute
- (NSAttributedString *)attributedStringForHTML:(NSString *)htmlInput {
    return NULL;
}

- (void)setDefaultFontColor:(NSObject *)defaultColor {
    
}

@end
