//
//  HFPFormatToAttributedString.h
//  HTMLFastParse
//
//  Created by Allison Husain on 5/14/21.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_EMBEDDED
#import <UIKit/UIKit.h>
#else /* if TARGET_OS_EMBEDDED */
#import <AppKit/AppKit.h>
#endif /* if not TARGET_OS_EMBEDDED */

NS_ASSUME_NONNULL_BEGIN

@interface HFPFormatToAttributedString : NSObject

/// Generate the attributed string for a given HTML string
/// @param htmlInput The HTML string to attribute
- (NSAttributedString *)attributedStringForHTML:(NSString *)htmlInput;

#if TARGET_OS_EMBEDDED
/// Set the default text color if no other coloring formatting is applied to a string of text
- (void)setDefaultFontColor:(UIColor *)defaultColor;
#else /* if TARGET_OS_EMBEDDED */
/// Set the default text color if no other coloring formatting is applied to a string of text
- (void)setDefaultFontColor:(NSColor *)defaultColor;
#endif /* if not TARGET_OS_EMBEDDED */

@end

NS_ASSUME_NONNULL_END
