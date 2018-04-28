//
//  C_HTML_Parser.c
//  HTMLFastParse
//
//  Created by Salman Husain on 4/27/18.
//  Copyright © 2018 CarbonDev. All rights reserved.
//
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

#include "C_HTML_Parser.h"
#include "t_format.h"
#include "Stack.h"
void attributeHTML(char input[],size_t inputLength,char output[]) {
	//A stack used for processing tags
	struct Stack* htmlTags = createStack((int)inputLength);
	//Completed / filled tags
	struct t_format completedTags[(int)inputLength];
	int completedTagsPosition = 0;
	
	//Used to track if we are currently reading the label of an HTML tag
	bool isInTag = false;
	char tagNameCharArray[inputLength * sizeof(char)];
	char *tagNameBuffer = &tagNameCharArray[0];//Hack to get our buffer on the stack because it's a very fast allocation
	int tagNameCopyPosition = 0;
	
	int stringCopyPosition = 0;
	
	for (int i = 0; i < inputLength; i++) {
		char current = input[i];
		if (current == '<') {
			isInTag = true;
			tagNameCopyPosition = 0;
			
			//If there's a next charachter (data validation) and it's NOT '/' (i.e. we're an open tag) we want to create a new formatter on the stack
			if (i+1 < inputLength && input[i+1] != '/') {
				struct t_format format;
				format.startPosition = stringCopyPosition;
				push(htmlTags,format);
			}
			
		}else if (current == '>') {
			//We've hit an unencoded less than which terminates an HTML tag
			isInTag = false;
			//Terminate the buffer
			tagNameBuffer[tagNameCopyPosition] = 0x00;
			
			//Are we a closing HTML tag (i.e. the first character in our tag is a '/')
			if (tagNameBuffer[0] == '/') {
				//We are a closing tag, so we're just going to ignore that for now and move on
				struct t_format format = *pop(htmlTags);
				format.endPosition = stringCopyPosition;
				completedTags[completedTagsPosition] = format;
				completedTagsPosition++;
			}else {
				//No -- so let's push the operation onto our stack
				//We've ended the tag definition, so pull the tag from the buffer and push that on to the stack
				long tagNameLength = (tagNameCopyPosition + 1) * sizeof(char);
				char *newTagBuffer = malloc(tagNameLength);
				strncpy(newTagBuffer,tagNameBuffer,tagNameLength);
				struct t_format format = *pop(htmlTags);
				format.tag = newTagBuffer;
				push(htmlTags,format);
			}
		}else {
			if (isInTag) {
				tagNameBuffer[tagNameCopyPosition] = current;
				tagNameCopyPosition++;
			}else {
				output[stringCopyPosition] = current;
				stringCopyPosition++;
			}
		}
	}
	//and now terminate our output.
	output[stringCopyPosition] = 0x00;
	
	while (!isEmpty(htmlTags)) {
		struct t_format in = *pop(htmlTags);
		//printf("!!! UNCLOSED TAG: %s starts at %i ends at %i\n",in.tag,in.startPosition,in.endPosition);
		free(in.tag);
	}
	
	//Now print out all tags
	
	for (int i = 0; i < completedTagsPosition; i++) {
		struct t_format inTag = completedTags[i];
		printf("TAG: %s starts at %i ends at %i\n",inTag.tag,inTag.startPosition,inTag.endPosition);
		free(inTag.tag);
	}
	
	//Release everything that's not necessary
	prepareForFree(htmlTags);
	free(htmlTags);
}
