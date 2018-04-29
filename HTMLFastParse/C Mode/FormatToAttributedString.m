//
//  FormatToAttributedString.m
//  HTMLFastParse
//
//  Created by Salman Husain on 4/28/18.
//  Copyright © 2018 CarbonDev. All rights reserved.
//

#import "FormatToAttributedString.h"
#import "C_HTML_Parser.h"
#import <UIKit/UIKit.h>

@implementation FormatToAttributedString
NSString *standardFontName;
NSString *boldFontName;
NSString *italicFontName;
NSString *italicsBoldFontName;
NSString *codeFontName;

UIFont *plainFont;
UIFont *boldFont;
UIFont *italicsFont;
UIFont *italicsBoldFont;
UIFont *codeFont;


UIColor *codeFontColor;
UIColor *containerBackgroundColor;
UIColor *quoteFontColor;

//We pregenerate nested quotes up to four for speed, after that they're dynamically allocated
NSMutableParagraphStyle *quoteParagraphStyle1;
NSMutableParagraphStyle *quoteParagraphStyle2;
NSMutableParagraphStyle *quoteParagraphStyle3;
NSMutableParagraphStyle *quoteParagraphStyle4;

float quotePadding = 20.0;
-(id)init {
	self = [super init];
	//Configure out colors
	
	codeFontColor = [UIColor colorWithRed:255.0/255 green:0 blue:255.0/255 alpha:1];
	containerBackgroundColor = [UIColor colorWithRed:242.0/255 green:242.0/255 blue:242.0/255 alpha:1];
	quoteFontColor = [UIColor colorWithRed:119.0/255 green:119.0/255 blue:119.0/255 alpha:1];
	
	//Prepare our common fonts once
	standardFontName = @"Avenir-Light";
	boldFontName = @"Avenir-Heavy";
	italicFontName = @"Avenir-BookOblique";
	italicsBoldFontName = @"Avenir-HeavyOblique";
	codeFontName = @"CourierNewPSMT";
	[self prepareFonts];
	return self;
}

-(void)prepareFonts {
	plainFont = [UIFont fontWithName:standardFontName size:UIFont.systemFontSize];
	boldFont = [UIFont fontWithName:boldFontName size:UIFont.systemFontSize];
	italicsFont = [UIFont fontWithName:italicFontName size:UIFont.systemFontSize];
	italicsBoldFont = [UIFont fontWithName:italicsBoldFontName size:UIFont.systemFontSize];
	codeFont = [UIFont fontWithName:codeFontName size:UIFont.systemFontSize];
	
	quoteParagraphStyle1 = [self generateParagraphStyleAtLevel:1];
	quoteParagraphStyle2 = [self generateParagraphStyleAtLevel:2];
	quoteParagraphStyle3 = [self generateParagraphStyleAtLevel:3];
	quoteParagraphStyle4 = [self generateParagraphStyleAtLevel:4];
}

-(NSMutableParagraphStyle *)generateParagraphStyleAtLevel:(int)depth {
	NSMutableParagraphStyle *quoteParagraphStyle = [[NSMutableParagraphStyle alloc]init];
	CGFloat levelQuoteIndentPadding = quotePadding * depth;
	[quoteParagraphStyle setHeadIndent:levelQuoteIndentPadding];
	[quoteParagraphStyle setFirstLineHeadIndent:levelQuoteIndentPadding];
	[quoteParagraphStyle setTailIndent:-levelQuoteIndentPadding];
	return quoteParagraphStyle;
}
-(NSAttributedString *)attributedStringForHTML:(NSString *)htmlInput {
	char* input = (char*)[htmlInput UTF8String];
	unsigned long inputLength = strlen(input);
	
	char* displayText = malloc(inputLength * sizeof(char));
	struct t_tag* tokens = malloc(inputLength * sizeof(struct t_tag));
	
	int numberOfTags = -1;
	tokenizeHTML(input, inputLength, displayText,tokens,&numberOfTags);
	
	struct t_format* finalTokens =  malloc(inputLength * sizeof(struct t_format));//&finalTokenBuffer[0];
	int numberOfSimplifiedTags = -1;
	makeAttributesLinear(tokens, (int)numberOfTags, finalTokens,&numberOfSimplifiedTags,(int)strlen(displayText));
	
	//Now apply our linear attributes to our attributed string
	NSMutableAttributedString *answer = [[NSMutableAttributedString alloc]initWithString:[NSString stringWithUTF8String:displayText]];
	//Set the whole thing to plain by default
	[answer addAttribute:NSFontAttributeName value:plainFont range:NSMakeRange(0, answer.length)];
	
	for (int i = 0; i < numberOfSimplifiedTags; i++) {
		[self addAttributeToString:answer forFormat:finalTokens[i]];
		free(finalTokens[i].linkURL);
	}
	
	
	
	free(displayText);
	
	//Free and get ready to return
	free(tokens);
	free(finalTokens);
	return answer;
}

-(void)addAttributeToString:(NSMutableAttributedString *)string forFormat:(struct t_format)format {
	//This is the range of the style
	NSRange currentRange = NSMakeRange(format.startPosition, format.endPosition-format.startPosition);
	
	if (format.linkURL) {
		[string addAttribute:NSLinkAttributeName value:[NSString stringWithUTF8String:format.linkURL] range:currentRange];
	}
	
	if (format.isStruck) {
		[string addAttribute:NSStrikethroughStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:currentRange];
	}
	
	if (format.quoteLevel > 0) {
		NSMutableParagraphStyle *quoteParagraphStyle;
		switch (format.quoteLevel) {
			case 1:
				quoteParagraphStyle = quoteParagraphStyle1;
				break;
			case 2:
				quoteParagraphStyle = quoteParagraphStyle2;
				break;
			case 3:
				quoteParagraphStyle = quoteParagraphStyle3;
				break;
			case 4:
				quoteParagraphStyle = quoteParagraphStyle4;
				break;
				
			default:
				quoteParagraphStyle = [self generateParagraphStyleAtLevel:format.quoteLevel];
				break;
		}
		[string addAttribute:NSParagraphStyleAttributeName value:quoteParagraphStyle range:currentRange];
		[string addAttribute:NSForegroundColorAttributeName value:quoteFontColor range:currentRange];
	}
	
	
	
	/* Styling that uses fonts. This includes exponents, h#, bold, italics, and any combination thereof. Code formatting skips all of these */
	
	if (format.isCode == 1) {
		[string addAttribute:NSFontAttributeName value:codeFont range:currentRange];
		[string addAttribute:NSBackgroundColorAttributeName value:containerBackgroundColor range:currentRange];
		[string addAttribute:NSForegroundColorAttributeName value:codeFontColor range:currentRange];
	}
	//Check if we can take a shortcut. We don't need dynamic font in this case
	else if (format.hLevel == 0 && format.exponentLevel == 0) {
		if (format.isBold == 0 && format.isItalics == 0) {
			//Plain text
			//Do nothing since it's the default as set above
		}else if (format.isBold == 1 && format.isItalics == 1) {
			//Bold italics
			[string addAttribute:NSFontAttributeName value:italicsBoldFont range:currentRange];
		}else if (format.isBold == 1) {
			//Bold
			[string addAttribute:NSFontAttributeName value:boldFont range:currentRange];
		}else if (format.isItalics == 1) {
			//Italics
			[string addAttribute:NSFontAttributeName value:italicsFont range:currentRange];
		}
	}else {
		//Apply the dynamic font
		CGFloat fontSize = UIFont.systemFontSize;
		//Handle H#
		if (format.hLevel > 0) {
			switch (format.hLevel) {
				case 0:
					break;
				case 1:
					fontSize *= 2;
					break;
				case 2:
					fontSize *= 1.5;
					break;
				case 3:
					fontSize *= 1.17;
					break;
				case 4:
					fontSize *= 1.12;
					break;
				case 5:
					fontSize *= 0.83;
					break;
				case 6:
					fontSize *= 0.75;
					break;
				default:
					NSLog(@"Unknown HLevel");
					break;
			}
		}
		//Handle exponent
		if (format.exponentLevel > 0) {
			fontSize *= 0.75;
			[string addAttribute:NSBaselineOffsetAttributeName value:[NSNumber numberWithFloat:format.exponentLevel*10] range:currentRange];
		}
		
		
		UIFont *customFont;
		if (format.isBold == 0 && format.isItalics == 0) {
			//Plain text
			customFont = [plainFont fontWithSize:fontSize];
		}else if (format.isBold == 1 && format.isItalics == 1) {
			//Bold italics
			customFont = [italicsBoldFont fontWithSize:fontSize];
		}else if (format.isBold == 1) {
			//Bold
			customFont = [boldFont fontWithSize:fontSize];
		}else if (format.isItalics == 1) {
			//Italics
			customFont = [italicsFont fontWithSize:fontSize];
		}
		
		
		[string addAttribute:NSFontAttributeName value:customFont range:currentRange];
	}
}
@end
