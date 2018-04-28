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


/**
 Tockenize and extract tag info from the input and then output the cleaned string alongisde a tag array with relevant position info

 @param input Input text as a char array
 @param inputLength The number of charachters to read, excluding the null byte!
 @param displayText The char array to write the clean, display text to
 @param completedTags The array to write the t_format structs to (provides position and tag info)
 */
void tokenizeHTML(char input[],size_t inputLength,char displayText[], struct t_format completedTags[]) {
	//A stack used for processing tags
	struct Stack* htmlTags = createStack((int)inputLength);
	//Completed / filled tags
	//struct t_format completedTags[(int)inputLength];
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
				//We are a closing tag, commit
				struct t_format format = *pop(htmlTags);
				format.endPosition = stringCopyPosition;
				completedTags[completedTagsPosition] = format;
				completedTagsPosition++;
			}
			//Are we a self closing tag like <br/> or <hr/>?
			else if ((tagNameCopyPosition > 0 && tagNameBuffer[tagNameCopyPosition-1] == '/')) {
				//These tags are special because they're an action in it of themselves so they both start themselves and commit all in one.
				struct t_format format = *pop(htmlTags);
				
				/* special cases, take a shortcut and remove the tags */
				if (strncmp(tagNameBuffer, "br/", 3) == 0) {
					//We're a <br/> tag, drop a new line into the actual text and remove the tag
					displayText[stringCopyPosition] = '\n';
					stringCopyPosition++;
				}else {
					//We're not a known case, add the tag into the extracted tag array
					long tagNameLength = (tagNameCopyPosition + 1) * sizeof(char);
					char *newTagBuffer = malloc(tagNameLength);
					strncpy(newTagBuffer,tagNameBuffer,tagNameLength);
					
					format.tag = newTagBuffer;
					format.startPosition = stringCopyPosition;
					format.endPosition = stringCopyPosition;
					
					completedTags[completedTagsPosition] = format;
					completedTagsPosition++;
				}
				
				
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
				displayText[stringCopyPosition] = current;
				stringCopyPosition++;
			}
		}
	}
	//and now terminate our output.
	displayText[stringCopyPosition] = 0x00;
	
	//Run through the unclosed tags so we can either process them and or free them
	while (!isEmpty(htmlTags)) {
		struct t_format in = *pop(htmlTags);
		printf("!!! UNCLOSED TAG: %s starts at %i ends at %i\n",in.tag,in.startPosition,in.endPosition);
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
