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
#include "t_tag.h"
#include "t_format.h"
#include "Stack.h"

//Format specifiers
#define HTML_PARSER_BOLD_TEXT 1;


#define printf //printf

/**
 Tockenize and extract tag info from the input and then output the cleaned string alongisde a tag array with relevant position info

 @param input Input text as a char array
 @param inputLength The number of charachters to read, excluding the null byte!
 @param displayText The char array to write the clean, display text to
 @param completedTags (returned) The array to write the t_format structs to (provides position and tag info)
 @param numberOfTags (returned) The number of tags discovered
 */
void tokenizeHTML(char input[],size_t inputLength,char displayText[], struct t_tag completedTags[], int* numberOfTags) {
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
				struct t_tag format;
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
				struct t_tag format = *pop(htmlTags);
				format.endPosition = stringCopyPosition;
				completedTags[completedTagsPosition] = format;
				completedTagsPosition++;
			}
			//Are we a self closing tag like <br/> or <hr/>?
			else if ((tagNameCopyPosition > 0 && tagNameBuffer[tagNameCopyPosition-1] == '/')) {
				//These tags are special because they're an action in it of themselves so they both start themselves and commit all in one.
				struct t_tag format = *pop(htmlTags);
				
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
				struct t_tag format = *pop(htmlTags);
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
		struct t_tag in = *pop(htmlTags);
		printf("!!! UNCLOSED TAG: %s starts at %i ends at %i\n",in.tag,in.startPosition,in.endPosition);
		free(in.tag);
	}
	
	//Now print out all tags
	
	for (int i = 0; i < completedTagsPosition; i++) {
		struct t_tag inTag = completedTags[i];
		printf("TAG: %s starts at %i ends at %i\n",inTag.tag,inTag.startPosition,inTag.endPosition);
	}
	*numberOfTags = completedTagsPosition;
	
	//Release everything that's not necessary
	prepareForFree(htmlTags);
	free(htmlTags);
}

void print_t_format(struct t_format format) {
	printf("Format [%i,%i): Bold %i, Italic %i, Struck %i, Code %i, Exponent %i, Quote %i, H%i, LinkURL %s\n",format.startPosition,format.endPosition,format.isBold,format.isItalics,format.isStruck,format.isCode,format.exponentLevel,format.quoteLevel,format.hLevel,format.linkURL);
}


/**
 Compare two t_formats. Returns 0 for the same, 1 if different in anyway

 @param format1 The first t_format struct
 @param format2 The second t_format struct
 @return 0 or 1
 */
int t_format_cmp(struct t_format format1,struct t_format format2) {
	if (format1.isBold != format2.isBold) {
		return 1;
	}else if (format1.isItalics != format2.isItalics) {
		return 1;
	}else if (format1.isStruck != format2.isStruck) {
		return 1;
	}else if (format1.isCode != format2.isCode) {
		return 1;
	}else if (format1.exponentLevel != format2.exponentLevel) {
		return 1;
	}else if (format1.quoteLevel != format2.quoteLevel) {
		return 1;
	}else if (format1.hLevel != format2.hLevel) {
		return 1;
	//Are both linkURLs non-null? are they the different?
	}else if (format1.linkURL && format2.linkURL && strcmp(format1.linkURL, format2.linkURL) != 0) {
		return 1;
	}else {
		return 0;
	}
}

/**
 Takes in overlapping t_format tags and simplifies them into 1D range suitable for use in NSAttributedString. Destroys inputTags in the process!

 @param inputTags Overlapping tags buffer (given by tokenizeHTML)
 @param numberOfInputTags The number of inputTags
 @param simplifiedTags (return) Simplified tags buffer (return value)
 @param numberOfSimplifiedTags (return) the number of found simplified tags
 @param displayTextLength The size of the text that we will be applying these tags to
 */
void makeAttributesLinear(struct t_tag inputTags[], int numberOfInputTags, struct t_format simplifiedTags[], int* numberOfSimplifiedTags, int displayTextLength) {
	//Create our state array
	struct t_format displayTextFormat[displayTextLength];
	//Init everything to zero in a single pass memory zero
	memset(&displayTextFormat, 0, sizeof(displayTextFormat));
	
	//Apply format from each tag
	for (int i = 0; i < numberOfInputTags; i++) {
		struct t_tag tag = inputTags[i];
		char* tagText = tag.tag;
		
		if (strncmp(tagText, "strong", 6) == 0) {
			//Apply bold to all
			for (int j = tag.startPosition; j < tag.endPosition; j++) {
				displayTextFormat[j].isBold = 1;
			}
		}else if (strncmp(tagText, "em", 2) == 0) {
			//Apply italics to all
			for (int j = tag.startPosition; j < tag.endPosition; j++) {
				displayTextFormat[j].isItalics = 1;
			}
		}else if (strncmp(tagText, "del", 3) == 0) {
			//Apply strike to all
			for (int j = tag.startPosition; j < tag.endPosition; j++) {
				displayTextFormat[j].isStruck = 1;
			}
		}else if (strncmp(tagText, "pre", 3) == 0) {
			//Apply CODE! to all
			for (int j = tag.startPosition; j < tag.endPosition; j++) {
				displayTextFormat[j].isCode = 1;
			}
		}else if (strncmp(tagText, "blockquote", 10) == 0) {
			//Increase quote level
			for (int j = tag.startPosition; j < tag.endPosition; j++) {
				displayTextFormat[j].quoteLevel++;
			}
		}else if (strncmp(tagText, "sup", 3) == 0) {
			//Increase superscript level
			for (int j = tag.startPosition; j < tag.endPosition; j++) {
				displayTextFormat[j].exponentLevel++;
			}
		}else if (tagText[0] == 'h' && tagText[1] >= '1' && tagText[1] <= '6') {
			//Set our header level
			for (int j = tag.startPosition; j < tag.endPosition; j++) {
				displayTextFormat[j].hLevel = tagText[1] - '0';
			}
		}else if (strncmp(tagText, "a href=", 7) == 0) {
			//We first need to extract the link
			long tagTextLength = strlen(tagText);
			char *url = malloc(tagTextLength-7);
			//Extract the URL
			int z = 8;
			for (; z < tagTextLength; z++) {
				if (tagText[z] == '"') {
					break;
				}else {
					url[z-8] = tagText[z];
				}
			}
			url[z-8] = 0x00;
			
			//Set our link
			for (int j = tag.startPosition; j < tag.endPosition; j++) {
				displayTextFormat[j].linkURL = url;
			}
			
		}else {
			printf("Unknown tag: %s\n",tagText);
		}
		
		
		//Destroy inputTags data as warned
		free(tag.tag);
	}
	
	for (int i = 1; i < displayTextLength; i++) {
		print_t_format(displayTextFormat[i]);
	}
	printf("--------\n");
	
	//Now that each charachter has it's style, let's simplify to a 1D
	*numberOfSimplifiedTags = 0;
	unsigned int activeStyleStart = 0;
	for (int i = 1; i < displayTextLength; i++) {
		if (t_format_cmp(displayTextFormat[activeStyleStart], displayTextFormat[i]) != 0) {
			//We're different, so commit our previous style (with start and ends) and adopt the current one
			displayTextFormat[i-1].startPosition = activeStyleStart;
			displayTextFormat[i-1].endPosition = i;
			simplifiedTags[*numberOfSimplifiedTags] = displayTextFormat[i-1];
			
			if (displayTextFormat[i-1].linkURL) {
				simplifiedTags[*numberOfSimplifiedTags].linkURL = malloc(strlen(displayTextFormat[i-1].linkURL) + 1);
				memcpy(simplifiedTags[*numberOfSimplifiedTags].linkURL, displayTextFormat[displayTextLength-1].linkURL, strlen(displayTextFormat[displayTextLength-1].linkURL) + 1);
			}
			
			print_t_format(displayTextFormat[i-1]);
			*numberOfSimplifiedTags+=1;
			activeStyleStart = i;
		}else {

		}
	}
	
	//and commit the final style
	displayTextFormat[displayTextLength-1].startPosition = activeStyleStart;
	displayTextFormat[displayTextLength-1].endPosition = displayTextLength;
	simplifiedTags[*numberOfSimplifiedTags] = displayTextFormat[displayTextLength-1];
	if (displayTextFormat[displayTextLength-1].linkURL) {
		simplifiedTags[*numberOfSimplifiedTags].linkURL = malloc(strlen(displayTextFormat[displayTextLength-1].linkURL) + 1);
		memcpy(simplifiedTags[*numberOfSimplifiedTags].linkURL, displayTextFormat[displayTextLength-1].linkURL, strlen(displayTextFormat[displayTextLength-1].linkURL) + 1);
	}
	print_t_format(displayTextFormat[displayTextLength-1]);
	*numberOfSimplifiedTags+=1;
	
	//now free
	for (int i = 0; i < displayTextLength; i++) {
		//do we have a linkURL and is it either different from the next one or are we the last one
		//this is neccesary so we don't double free the URL
		if (displayTextFormat[i].linkURL && ((i + 1 < displayTextLength && displayTextFormat[i+1].linkURL != displayTextFormat[i].linkURL) || (i+1 >= displayTextLength))) {
			free(displayTextFormat[i].linkURL);
			displayTextFormat[i].linkURL = NULL;
		}
	}
}
