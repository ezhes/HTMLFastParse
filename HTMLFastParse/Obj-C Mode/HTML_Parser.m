//
//  HTML_Parser.m
//  HTMLFastParse
//
//  Created by Salman Husain on 4/27/18.
//  Copyright © 2018 CarbonDev. All rights reserved.
//

#import "HTML_Parser.h"
#include "Stack.h"
#include "t_format.h"
#import "DKStack.h"
#import "Format.h"
@implementation HTML_Parser

-(NSString *)parseHTML:(NSString*)inputString {
	const char* input = [inputString UTF8String];
	unsigned long inputLength = strlen(input);
	
	unsigned long bufferSize = inputLength * sizeof(char);
	char* output = malloc(bufferSize);
	
	DKStack *htmlTags = [[DKStack alloc]init];
	bool isInTag = false;
	char *tagBuffer = malloc(bufferSize);
	int tagCopyPosition = 0;
	
	int stringCopyPosition = 0;
	
	for (int i = 0; i < inputLength; i++) {
		char current = input[i];
		if (current == '<') {
			isInTag = true;
			tagCopyPosition = 0;
			//If there's a next charachter (data validation) and it's NOT '/' (i.e. we're an open tag) we want to create a new formatter on the stack
			if (i+1 < inputLength && input[i+1] != '/') {
				Format *format = [[Format alloc]init];
				format->stackIndex = stringCopyPosition;
				[htmlTags push:format];
			}
		}else if (current == '>') {
			//We've hit an unencoded less than which terminates an HTML tag
			isInTag = false;
			//Terminate the buffer
			tagBuffer[tagCopyPosition] = 0x00;
			
			//Are we a closing HTML tag (i.e. the first character in our tag is a '/')
			if (tagBuffer[0] == '/') {
				//We are a closing tag, so we're just going to ignore that for now and move on
				Format *format = [htmlTags pop];
				format->endIndex = stringCopyPosition;
				[htmlTags push:format];
			}else {
				//No -- so let's push the operation onto our stack
				//We've ended the tag definition, so pull the tag from the buffer and push that on to the stack
				Format *format = [htmlTags pop];
				format->tag = [NSMutableString stringWithUTF8String:tagBuffer];
				[htmlTags push:format];
			}
		}else {
			if (isInTag) {
				tagBuffer[tagCopyPosition] = current;
				tagCopyPosition++;
			}else {
				output[stringCopyPosition] = current;
				stringCopyPosition++;
			}
		}
	}
	//and now terminate our output.
	output[stringCopyPosition] = 0x00;
	
	while (![htmlTags isEmpty]) {
		Format *format = [htmlTags pop];
		//printf("TAG: %s starts at %i ends at %i\n",[format->tag UTF8String],format->stackIndex,format->endIndex);
	}
	NSString *outputNS = [NSString stringWithUTF8String:output];
	free(output);
	free(tagBuffer);
	return outputNS;
}

@end
