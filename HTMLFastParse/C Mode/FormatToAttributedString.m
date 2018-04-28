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
NSString *fontName;
UIFontDescriptor *fontDescriptor;
UIFont *plainFont;
UIFont *boldFont;
UIFont *italicsFont;
UIFont *italicsBoldFont;

-(id)init {
	self = [super init];
	//Prepare our common fonts once
	fontName = @"Avenir-Light";
	[self prepareFonts];
	return self;
}

-(void)prepareFonts {
	fontDescriptor = [UIFontDescriptor fontDescriptorWithName:fontName size:UIFont.systemFontSize];
	plainFont = [UIFont fontWithName:fontName size:UIFont.systemFontSize];
	boldFont = [UIFont fontWithDescriptor:[fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:UIFont.systemFontSize];
	italicsFont = [UIFont fontWithDescriptor:[fontDescriptor fontDescriptorWithSymbolicTraits: UIFontDescriptorTraitItalic] size:UIFont.systemFontSize];
	italicsBoldFont = [UIFont fontWithDescriptor:[fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold | UIFontDescriptorTraitItalic] size:UIFont.systemFontSize];
}
-(NSAttributedString *)attributedStringForHTML:(NSString *)htmlInput {
	char* input = [htmlInput UTF8String];
	unsigned long inputLength = strlen(input);
	
	char* displayText = malloc(inputLength * sizeof(char));//&displayTextBuffer[0];
	struct t_tag* tokens = malloc(inputLength * sizeof(struct t_tag));//&tokenBuffer[0];
	
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
	/* basic fonts! */
	//Check if we can take a shortcut. We don't need dynamic font in this case
	if (format.hLevel == 0 && format.exponentLevel == 0) {
		if (format.isBold == 0 && format.isItalics == 0) {
			//Plain text
			//Do nothing since it's the default as set above
		}else if (format.isBold == 1 && format.isItalics == 1) {
			//Bold italics
			[string addAttribute:NSFontAttributeName value:italicsBoldFont range:NSMakeRange(format.startPosition, format.endPosition-format.startPosition)];
		}else if (format.isBold == 1) {
			//Bold
			[string addAttribute:NSFontAttributeName value:boldFont range:NSMakeRange(format.startPosition, format.endPosition-format.startPosition)];
		}else if (format.isItalics == 1) {
			//Italics
			[string addAttribute:NSFontAttributeName value:italicsFont range:NSMakeRange(format.startPosition, format.endPosition-format.startPosition)];
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
			fontSize *= (0.75 * format.exponentLevel);
			[string addAttribute:NSBaselineOffsetAttributeName value:[NSNumber numberWithFloat:format.exponentLevel*10] range:NSMakeRange(format.startPosition, format.endPosition-format.startPosition)];
		}
		
		UIFontDescriptorSymbolicTraits traits = 0x00000;
		//Perform a bitwise or on the trait times the bool. If isItalics is one, it applies, otherwise it's an or against 0x0
		traits |= (UIFontDescriptorTraitItalic * format.isItalics);
		traits |= (UIFontDescriptorTraitBold * format.isBold);
		UIFont *customFont = [UIFont fontWithDescriptor:[fontDescriptor fontDescriptorWithSymbolicTraits:traits] size:fontSize];
		[string addAttribute:NSFontAttributeName value:customFont range:NSMakeRange(format.startPosition, format.endPosition-format.startPosition)];
	}
}
@end
