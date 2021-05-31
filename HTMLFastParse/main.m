//
//  main.m
//  HTMLFastParse
//
//  Created by Allison Husain on 5/14/21.
//

#import <Foundation/Foundation.h>
#import "HFPHTMLParser.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
    }
    
    const char *input = "<h1>Hello there</h1> <em>its me</em>";
    HFPHTMLParser_formatting *formatting = NULL;
    int result = 0;
    if ((result = HFPHTMLParser_create_formatting_from_html(&formatting, input, strlen(input))) < 0) {
        abort();
    }
    
    for (size_t i = 0; i < formatting->formatting_descriptor_count; i++) {
        HFPHTMLParser_formatting_descriptor *descriptor = formatting->formatting_descriptors + i;
        printf("Descriptor: %p\n", descriptor);
    }
    
    return 0;
}
