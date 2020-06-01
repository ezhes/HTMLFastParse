//
//  main.m
//  HTMLFastParseFuzzingCli
//
//  Created by Allison Husain on 6/28/18.
//  Copyright © 2018 CarbonDev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FormatToAttributedStringMacOS.h"
#ifdef DEBUG
#else
#include <libhfuzz/instrument.h>
#endif

extern void HF_ITER(uint8_t** buf, size_t* len);
void dummyLogProc() { }

__attribute__ ((optnone)) int main(int argc, const char * argv[]) {
    @autoreleasepool {
        FormatToAttributedStringMacOS *fm = [[FormatToAttributedStringMacOS alloc]init];
        size_t fuzzSize;
        uint8_t* buffer;
        
        for (int i = 0; i < 100000; i++) {
            #ifdef DEBUG
            NSString *test = [[NSString alloc] initWithContentsOfFile:@"/Users/Allison/Downloads/HTMLFastParse/HTMLFastParseFuzzingCli/SIGABRT.EXC_CRASH.PC.00007fff6eb8e33a.STACK.00000003b1377cb7.ADDR.0000000000000000.fuzz" encoding:NSUTF8StringEncoding error:nil];
            #else
            HF_ITER(&buffer, &fuzzSize);
            NSString *test = [[NSString alloc] initWithBytes:buffer length:fuzzSize encoding:NSUTF8StringEncoding];
            #endif
            [fm attributedStringForHTML:test];
        }

    }
    return 0;
}
