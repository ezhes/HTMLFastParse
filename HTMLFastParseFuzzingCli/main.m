//
//  main.m
//  HTMLFastParseFuzzingCli
//
//  Created by Salman Husain on 6/28/18.
//  Copyright © 2018 CarbonDev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FormatToAttributedStringMacOS.h"
int main(int argc, const char * argv[]) {
    @autoreleasepool {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        NSString * test = @"test&#00000000;";//[NSString stringWithContentsOfFile:[NSString stringWithCString:argv[1]]];
#pragma GCC diagnostic pop
        FormatToAttributedStringMacOS *fm = [[FormatToAttributedStringMacOS alloc]init];
        NSAttributedString * formattedString = [fm attributedStringForHTML:test];
        NSLog(@"Visible str: %@",[formattedString string]);
        NSLog(@"Produced length: %lu",[formattedString length]);
    }
    return 0;
}
