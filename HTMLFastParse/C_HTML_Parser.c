//
//  C_HTML_Parser.c
//  HTMLFastParse
//
//  Created by Allison Husain on 4/27/18.
//  Copyright © 2018 CarbonDev. All rights reserved.
//
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <limits.h>

#include "C_HTML_Parser.h"
#include "t_tag.h"
#include "t_format.h"
#include "Stack.h"
#include "entities.h"
#include "base64.h"

//Disable printf
#define ENABLE_HTML_FASTPARSE_DEBUG 0

#if !ENABLE_HTML_FASTPARSE_DEBUG
#define printf(fmt, ...) (0)
#endif

//Enable reddit tune. Comment this out to remove them
#define reddit_mode 1;

#define EXPAND_IF_TOO_SMALL(addr, buffer_size, filled_size, new_bytes) do { \
if (filled_size + new_bytes >= buffer_size) \
    addr = realloc(addr, buffer_size * 2); \
} while(0);

//Used for encoding the table out of band links
static const char DATA_URI_PREFIX[] = "data:text/html;base64,";
static const char VIEW_TABLE_TEXT[] = "[View table]\n";


/**
 Get the number of bytes that a given character will use when displayed (multi-byte unicode characters need to be handled like this because NSString counts multi-byte chars as single characters while C does not obviously)
 
 @param character The character
 @return A value between 0-1 if that character is valid
 */
int getVisibleByteEffectForCharacter(unsigned char character) {
    int firstHighBit = (character & 0x80);
    if (firstHighBit == 0x0) {
        //Regular ASCII
        return 1;
    }else {
        unsigned char secondHighBit = ((character << 1) & 0x80);
        if (secondHighBit == 0x0) {
            //Additional byte character (10xxxxxx character). Not visible
            return 0;
        }else {
            //This is the start of a multibyte character, count it (1+)
            unsigned char fourByteTest = character & 0b11110000;
            if (fourByteTest == 0b11110000) {
                //Patch for apple's weirdness with four byte characters (they're counted as two visible? WHY?!?!?)
                return 2;
            }else {
                //We're multibyte but not a four byte which requires the patch, count normally
                return 1;
            }
        }
    }
}

/**
 Tokenize and extract tag info from the input and then output the cleaned string alongside a tag array with relevant position info
 
 @param input Input text as a char array
 @param inputLength The number of characters (as bytes) to read, excluding the null byte!
 @param completedTags (returned) The array to write the t_format structs to (provides position and tag info). Tags positions are character relative, not byte relative! Usable in NSAttributedString etc
 @param numberOfTags (returned) The number of tags discovered
 @return The displayed text buffer
 */
char * tokenizeHTML(char *input, size_t inputLength, struct t_tag *completedTags, int *numberOfTags, int *numberOfHumanVisibleCharacters) {
    size_t displayTextBufferSize = (strlen(input) + 1) * sizeof(char);
    char *displayText = malloc(displayTextBufferSize);
    //A stack used for processing tags. The stack size allocates space for x number of POINTERS. Ie this is not creating an overflow vulnerability AFAIK
    struct Stack* htmlTags = createStack((int)inputLength);
    //Completed / filled tags
    //struct t_format completedTags[(int)inputLength];
    int completedTagsPosition = 0;
    
    //Used to track if we are currently reading the label of an HTML tag
    bool isInTag = false;
    char *tagNameCharArray = malloc(inputLength * sizeof(char) + 1); //+1 for a null byte
    char *tagNameBuffer = &tagNameCharArray[0];//Hack to get our buffer on the stack because it's a very fast allocation
    int tagNameCopyPosition = 0;
    
    //If we are reading a table, skip normal behavior since tables are handled out of band
    bool isInTable = false;
    //The index of the first byte of the table tag
    int tableStartI = 0;
    
    //Used to track if we are currently reading an HTML entity
    bool isInHTMLEntity = false;
    char *htmlEntityCharArray = malloc(inputLength * sizeof(char) + 1); //+1 for a null byte
    char *htmlEntityBuffer = &htmlEntityCharArray[0];//Hack to get our buffer on the stack because it's a very fast allocation
    int htmlEntityCopyPosition = 0;
    
    int stringCopyPosition = 0;
    //Used for applying tokens, DO NOT USE FOR MEMORY WORK. This is used because NSString handles multibyte characters as single characters and not as multiple like we have to
    int stringVisiblePosition = 0;
    
    char previous = 0x00;
    //The current index label (i.e. 1,2,3) of the list, USHRT_MAX for unordered
    unsigned short currentListValue = 0x00;
    
    for (int i = 0; i < inputLength; i++) {
        char current = input[i];
        if (current == '<') {
            isInTag = true;
            tagNameCopyPosition = 0;
            
            //If there's a next character (data validation) and it's NOT '/' (i.e. we're an open tag) we want to create a new formatter on the stack
            if (i+1 < inputLength && input[i+1] != '/') {
                struct t_tag format;
                format.tag = NULL;
                format.tableDataLength = 0;
                format.tableData = NULL;
                format.startPosition = stringVisiblePosition;
                format.endPosition = stringVisiblePosition;
                push(htmlTags, format);
            }
            
        } else if (current == '>') {
            //We've hit an unencoded less than which terminates an HTML tag
            isInTag = false;
            //Terminate the buffer
            tagNameBuffer[tagNameCopyPosition] = 0x00;
            
            //Are we a closing HTML tag (i.e. the first character in our tag is a '/')
            if (tagNameBuffer[0] == '/') {
                //We are a closing tag, commit
                struct t_tag* formatP = pop(htmlTags);
                //Make sure we didn't get a NULL from popping an empty stack
                if (formatP) {
                    struct t_tag format = *formatP;
                    
                    //Table commit
                    if (isInTable && strncmp(tagNameBuffer, "/table", 6) == 0) {
                        isInTable = false;
                        size_t expectedEncodeSize = i - tableStartI + 1;
                        char *base64Table = malloc(Base64encode_len(expectedEncodeSize));
                        size_t encodedLength = Base64encode(base64Table, (input + tableStartI), expectedEncodeSize);
                        if (base64Table) {
                            format.tableDataLength = encodedLength;
                            format.tableData = base64Table;
                        }
                    }
                    
                    format.endPosition = stringVisiblePosition;
                    completedTags[completedTagsPosition] = format;
                    completedTagsPosition++;
                }
            }
            //Are we a self closing tag like <br/> or <hr/>?
            else if ((tagNameCopyPosition > 0 && tagNameBuffer[tagNameCopyPosition-1] == '/')) {
                //These tags are special because they're an action in it of themselves so they both start themselves and commit all in one.
                struct t_tag* formatP = pop(htmlTags);
                if (formatP) {
                    /* special cases, take a shortcut and remove the tags */
                    if (strncmp(tagNameBuffer, "br/", 3) == 0) {
                        //We're a <br/> tag, drop a new line into the actual text and remove the tag
                        //IGNORE THESE WHEN USING THE REDDIT MODE because Reddit already sends a new line after <br/> tags so it's duplicated in effect
#ifndef reddit_mode
                        if (!isInTable) {
                            displayText[stringCopyPosition] = '\n';
                            stringCopyPosition++;
                            stringVisiblePosition++;
                        }
#endif
                    } else {
                        //We're not a known case, add the tag into the extracted tag array
                        long tagNameLength = (tagNameCopyPosition + 1) * sizeof(char);
                        char *newTagBuffer = malloc(tagNameLength);
                        strncpy(newTagBuffer, tagNameBuffer, tagNameLength);
                        
                        formatP->tag = newTagBuffer;
                        formatP->startPosition = stringVisiblePosition;
                        formatP->endPosition = stringVisiblePosition;
                        
                        completedTags[completedTagsPosition] = *formatP;
                        completedTagsPosition++;
                    }
                }
            } else {
                //No -- so let's push the operation onto our stack
                //We've ended the tag definition, so pull the tag from the buffer and push that on to the stack
                long tagNameLength = (tagNameCopyPosition + 1) * sizeof(char);
                char *newTagBuffer = malloc(tagNameLength);
                memset(newTagBuffer, 0x0, tagNameLength);
                strncpy(newTagBuffer, tagNameBuffer, tagNameLength);
                struct t_tag* formatP = pop(htmlTags);
                //Make sure we didn't get a NULL from popping an empty stack
                //If we end up failing here the text will be horribly mangled however "broken formatting" IMHO is better than a full crash or a sec issue
                if (formatP) {
                    formatP->tag = newTagBuffer;
                    push(htmlTags, *formatP);
                    
                    //Add textual descriptors for order/unordered lists
                    if (strncmp(newTagBuffer, "ol", 2) == 0) {
                        //Ordered list
                        currentListValue = 1;
                    } else if (strncmp(newTagBuffer, "ul", 2) == 0) {
                        //Unordered list
                        currentListValue = USHRT_MAX;
                    } else if (strncmp(newTagBuffer, "li", 2) == 0) {
                        //Apply current list index
                        if (currentListValue == USHRT_MAX) {
                            stringVisiblePosition += 2;
                            displayText[stringCopyPosition++] = 0xE2;
                            displayText[stringCopyPosition++] = 0x80;
                            displayText[stringCopyPosition++] = 0xA2;
                            displayText[stringCopyPosition++] = ' ';
                        }else {
                            int written = sprintf(&displayText[stringCopyPosition], "%i. ", currentListValue);
                            stringCopyPosition += written;
                            stringVisiblePosition += written;
                            currentListValue++;
                        }
                    //We check that we aren't already in a table as nested tables are not supported directly (handled out of band)
                    } else if (!isInTable && strncmp(tagNameBuffer, "table", 5) == 0) {
                        isInTable = true;
                        tableStartI = i - tagNameCopyPosition - 1;
                        
                        size_t tablePromptTextWithoutNull = sizeof(VIEW_TABLE_TEXT) - 1;
                        //Since VIEW_TABLE_TEXT is LONGER than the text we're replacing, we can't guarantee it fits.
                        EXPAND_IF_TOO_SMALL(displayText, displayTextBufferSize, stringCopyPosition, tablePromptTextWithoutNull);
                        memcpy(displayText + stringCopyPosition, VIEW_TABLE_TEXT, tablePromptTextWithoutNull);
                        stringCopyPosition += tablePromptTextWithoutNull;
                        stringVisiblePosition += tablePromptTextWithoutNull;
                        previous = '\n';
                    }

                } else {
                    free(newTagBuffer);
                }
            }
            tagNameCopyPosition = 0;
        } else if (current == '&' && !isInTable) {
            //We are starting an HTML entity;
            isInHTMLEntity = true;
            htmlEntityCopyPosition = 0;
            htmlEntityBuffer[htmlEntityCopyPosition] = '&';
            htmlEntityCopyPosition++;
        } else if (isInHTMLEntity == true && current == ';' && !isInTable) {
            //We are finishing an HTML entity
            isInHTMLEntity = false;
            htmlEntityBuffer[htmlEntityCopyPosition] = ';';
            htmlEntityCopyPosition++;
            htmlEntityBuffer[htmlEntityCopyPosition] = 0x00;
            htmlEntityCopyPosition++;
            
            //Are we decoding into a tag (i.e. into the url portion of <a href='http://test/forks?t=yes&f=no'/>
            if (isInTag) {
                //Yes!
                size_t numberDecodedBytes = decode_html_entities_utf8(&tagNameBuffer[tagNameCopyPosition], htmlEntityBuffer);
                tagNameCopyPosition += numberDecodedBytes;
            }else {
                //Expand into regular text
                size_t numberDecodedBytes = decode_html_entities_utf8(&displayText[stringCopyPosition], htmlEntityBuffer);
                for (unsigned long decodedI = 0; decodedI < numberDecodedBytes; decodedI++) {
                    //Add the visual effect for each character. This lets us also handle when decode sends back a tag it can't decode.
                    //Also helpful incase we have codes which decode to multiple characters, which could happen
                    stringVisiblePosition += getVisibleByteEffectForCharacter(displayText[stringCopyPosition + decodedI]);
                }
                
                stringCopyPosition += numberDecodedBytes;
            }
        } else {
            //copy in to the right buffer
            //this is a priority list (i.e. decoding an entity before going in to a tag before going in to visible)
            if (isInHTMLEntity) {
                htmlEntityBuffer[htmlEntityCopyPosition] = current;
                htmlEntityCopyPosition++;
            } else if (isInTag) {
                tagNameBuffer[tagNameCopyPosition] = current;
                tagNameCopyPosition++;
            } else if (isInTable) {
                //If we are in a table, do not emit characters and 'swallow' them instead since we handle tables out of band as raw html
            } else {
                //Don't allow double new lines (thanks Reddit for sending these?)
                //Don't allow just new lines (happens between blockquotes and p tags, again reddit issue)
                //This messes up quote formatting
#ifdef reddit_mode
                if ((current != '\n' || previous != '\n') && (current != '\n' || stringVisiblePosition > 1 )) {
#endif
                    previous = current;
                    displayText[stringCopyPosition] = current;
                    stringVisiblePosition += getVisibleByteEffectForCharacter(current);
                    stringCopyPosition++;
#ifdef reddit_mode
                }
#endif
                
            }
        }
    }
    
    //Check if the last tag is incomplete (i.e. "blah blah <tag") so we can remove the unfinished tag from the stack
    if (tagNameCopyPosition > 0) {
        printf("!!! Found incomplete tag, popping and continuing...");
        pop(htmlTags);
    }
    
    //and now terminate our output.
    displayText[stringCopyPosition] = 0x00;
    
    //Run through the unclosed tags so we can either process them and or free them
    while (!isEmpty(htmlTags)) {
        struct t_tag* formatP = pop(htmlTags);
        //Make sure we didn't get a NULL from popping an empty stack
        if (formatP != NULL) {
            struct t_tag in = *formatP;
            printf("!!! UNCLOSED TAG: %s starts at %i ends at %i\n", in.tag, in.startPosition,in.endPosition);
            free(in.tag);
        }
    }
    
    //Now print out all tags
    
#if ENABLE_HTML_FASTPARSE_DEBUG
    for (int i = 0; i < completedTagsPosition; i++) {
        struct t_tag inTag = completedTags[i];
        printf("TAG: %s starts at %i ends at %i\n", inTag.tag, inTag.startPosition,inTag.endPosition);
    }
#endif
    
    *numberOfTags = completedTagsPosition;
    *numberOfHumanVisibleCharacters = stringVisiblePosition;
    
    //Release everything that's not necessary
    prepareForFree(htmlTags);
    free(htmlTags);
    free(tagNameCharArray);
    free(htmlEntityCharArray);
    
    return displayText;
}

void print_t_format(struct t_format format) {
    printf("Format [%i,%i): Bold %i, Italic %i, Struck %i, Code %i, Exponent %i, Quote %i, H%i, ListNest %i LinkURL %s\n",format.startPosition, format.endPosition, FORMAT_TAG_GET_BIT_FIELD(format.formatTag, FORMAT_TAG_IS_BOLD), FORMAT_TAG_GET_BIT_FIELD(format.formatTag, FORMAT_TAG_IS_ITALICS), FORMAT_TAG_GET_BIT_FIELD(format.formatTag, FORMAT_TAG_IS_STRUCK), FORMAT_TAG_GET_BIT_FIELD(format.formatTag, FORMAT_TAG_IS_CODE), format.exponentLevel, format.quoteLevel, FORMAT_TAG_GET_H_LEVEL(format.formatTag), format.listNestLevel, format.linkURL);
}


/**
 Compare two t_formats. Returns 0 for the same, 1 if different in anyway
 
 @param format1 The first t_format struct
 @param format2 The second t_format struct
 @return 0 or 1
 */
int t_format_cmp(struct t_format format1,struct t_format format2) {
    //ints are 4 bytes, which covers all the packed properties and the other sizes
    //this is packing safe (in theory) because chars never cause padding
    //Tip from one of the LLVM people at WWDC`18
    int format1Sum = *(((int*)&format1.formatTag));
    int format2Sum = *(((int*)&format2.formatTag));

    if (format1Sum != format2Sum) {
        return 1;
    } else if (format1.linkURL != format2.linkURL || (format1.linkURL != NULL && format2.linkURL != NULL && strcmp(format1.linkURL, format2.linkURL) != 0)) {
        return 1;
    } else {
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
    size_t bufferSize = displayTextLength * sizeof(struct t_format);
    struct t_format *displayTextFormat = malloc(bufferSize);
    //Init everything to zero in a single pass memory zero
    memset(displayTextFormat, 0, bufferSize);
    
    //Apply format from each tag
    for (int i = 0; i < numberOfInputTags; i++) {
        struct t_tag tag = inputTags[i];
        char* tagText = tag.tag;
        if (tagText) {
            //switch on the first character to minimize string comparisons
            switch (tagText[0]) {
                case 'a':
                    if (strncmp(tagText, "a href=", 7) == 0) {
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
                        
                        //If we never got into the loop above (and so url is never stored else where), free it now.
                        if (tag.endPosition - tag.startPosition <= 0) {
                            free(url);
                        }
                        
                    }
                    break;
                case 'b':
                    if (strncmp(tagText, "blockquote", 10) == 0) {
                        //Increase quote level
                        for (int j = tag.startPosition; j < tag.endPosition; j++) {
                            displayTextFormat[j].quoteLevel++;
                        }
                    }
                    break;
                case 'c':
                    if (strncmp(tagText, "code", 4) == 0) {
                        //Apply CODE! to all
                        for (int j = tag.startPosition; j < tag.endPosition; j++) {
                            //Since we only ever set these bit fields to true, we can skip erasing
                            displayTextFormat[j].formatTag |= 1 << FORMAT_TAG_IS_CODE_OFFSET;
                        }
                    }
                    break;
                case 'd':
                    if (strncmp(tagText, "del", 3) == 0) {
                        //Apply strike to all
                        for (int j = tag.startPosition; j < tag.endPosition; j++) {
                            displayTextFormat[j].formatTag |= 1 << FORMAT_TAG_IS_STRUCK_OFFSET;
                        }
                    }
                    break;
                case 'e':
                    if (strncmp(tagText, "em", 2) == 0) {
                        //Apply italics to all
                        for (int j = tag.startPosition; j < tag.endPosition; j++) {
                            displayTextFormat[j].formatTag |= 1 << FORMAT_TAG_IS_ITALICS_OFFSET;
                        }
                    }
                    break;
                case 'h':
                    if (tagText[0] == 'h' && tagText[1] >= '1' && tagText[1] <= '6') {
                        //Set our header level
                        unsigned char headerLevel = tagText[1] - '0';
                        //since we're stuffing this into a 4 bit field and the above only really expects up to 9 we cap this value
                        if (headerLevel >= 10) {
                            headerLevel = 9;
                        }
                        for (int j = tag.startPosition; j < tag.endPosition; j++) {
                            displayTextFormat[j].formatTag |= headerLevel < FORMAT_TAG_H_LEVEL_OFFSET;
                        }
                    }
                    break;
                case 's':
                    if (strncmp(tagText, "strong", 6) == 0) {
                        //Apply bold to all
                        for (int j = tag.startPosition; j < tag.endPosition; j++) {
                            displayTextFormat[j].formatTag |= 1 << FORMAT_TAG_IS_BOLD_OFFSET;
                        }
                    } else if (strncmp(tagText, "sup", 3) == 0) {
                        //Increase superscript level
                        for (int j = tag.startPosition; j < tag.endPosition; j++) {
                            displayTextFormat[j].exponentLevel++;
                        }
                    }
                    break;
                case 't':
                    if (strncmp(tagText, "table", 5) == 0) {
                        //Apply our encoded table link
                        if (!tag.tableData || tag.tableDataLength == 0) {
                            //invalid table data?
                            break;
                        }
                                                
                        //Remove the null from DATA_URI_PREFIX and take the null from the table data length
                        size_t dataURIPrefixWithoutNull = sizeof(DATA_URI_PREFIX) - 1;
                        char *url = malloc(dataURIPrefixWithoutNull + tag.tableDataLength);
                        memcpy(url, DATA_URI_PREFIX, dataURIPrefixWithoutNull);
                        memcpy(url + dataURIPrefixWithoutNull, tag.tableData, tag.tableDataLength);
                        
                        //Set our link
                        for (int j = tag.startPosition; j < tag.endPosition; j++) {
                            displayTextFormat[j].linkURL = url;
                        }
                        
                        //If we never got into the loop above (and so url is never stored else where), free it now.
                        if (tag.endPosition - tag.startPosition <= 0) {
                            free(url);
                        }
                    }
                    
                    break;
                case 'o':
                case 'u':
                    if (strncmp(tagText, "ol", 2) == 0 || (strncmp(tagText, "ul", 2) == 0)) {
                        //Apply list indentation
                        for (int j = tag.startPosition; j < tag.endPosition; j++) {
                            displayTextFormat[j].listNestLevel++;
                        }
                    }
                    
                    break;
                default:
                    //nil tag
                    break;
            }
        } else {
            printf("NULL TAG TEXT?? SKIPPING!");
        }

        //Destroy inputTags data as warned
        free(tag.tag);
        free(tag.tableData);
        tag.tag = NULL;
    }
    
    for (int i = 0; i < displayTextLength; i++) {
        //print_t_format(displayTextFormat[i]);
    }
    printf("--------\n");
    
    //Now that each character has it's style, let's simplify to a 1D
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
                memcpy(simplifiedTags[*numberOfSimplifiedTags].linkURL, displayTextFormat[i-1].linkURL, strlen(displayTextFormat[i-1].linkURL) + 1);
            }
            
            print_t_format(displayTextFormat[i-1]);
            *numberOfSimplifiedTags+=1;
            activeStyleStart = i;
        }
    }
    
    //and commit the final style
    //We need to make sure we have displayed text otherwise we over/underflow here
    if (displayTextLength > 0) {
        displayTextFormat[displayTextLength-1].startPosition = activeStyleStart;
        displayTextFormat[displayTextLength-1].endPosition = displayTextLength;
        simplifiedTags[*numberOfSimplifiedTags] = displayTextFormat[displayTextLength-1];
        if (displayTextFormat[displayTextLength-1].linkURL) {
            simplifiedTags[*numberOfSimplifiedTags].linkURL = malloc(strlen(displayTextFormat[displayTextLength-1].linkURL) + 1);
            memcpy(simplifiedTags[*numberOfSimplifiedTags].linkURL, displayTextFormat[displayTextLength-1].linkURL, strlen(displayTextFormat[displayTextLength-1].linkURL) + 1);
        }
        print_t_format(displayTextFormat[displayTextLength-1]);
        *numberOfSimplifiedTags+=1;
    }
    
    //now free
    for (int i = 0; i < displayTextLength; i++) {
        //do we have a linkURL and is it either different from the next one or are we the last one
        //this is necessary so we don't double free the URL
        if (displayTextFormat[i].linkURL && ((i + 1 < displayTextLength && displayTextFormat[i+1].linkURL != displayTextFormat[i].linkURL) || (i+1 >= displayTextLength))) {
            free(displayTextFormat[i].linkURL);
            displayTextFormat[i].linkURL = NULL;
        }
    }
    
    free(displayTextFormat);
}
