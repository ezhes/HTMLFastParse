//
//  HFPHTMLParser.c
//  HTMLFastParse
//
//  Created by Allison Husain on 5/14/21.
//

#include "HFPHTMLParser.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "HFPManagedBuffer.h"

// Is this parser using optimizations for parsing HTML returned by reddit
#define OPTIMIZE_FOR_REDDIT 1

//MARK: - Private structs/enums
enum HFPHTMLParser_html_tag_flag {
    HFPHTMLPARSER_HTML_TAG_FLAG_NONE = 0,
    /// Indicates that `tag_contents` and `tag_contents_length` refers
    HFPHTMLPARSER_HTML_TAG_FLAG_TABLE = 1,
};

/// Represents a single HTML tag
typedef struct {
    /// The human visible starting character for which this tag applies
    size_t visible_start_position;
    /// The human visible ending character (exclusive) for which this tag applies
    size_t visible_end_position;
    /// A pointer to the starting inner contents of the tag (i.e. after `<` so that `<abc>` has tag_contents = "abc" with tag_contents_length=3)
    /// This pointer is NOT owned and points into the original HTML input
    const char *tag_contents;
    /// The length of tag_contents (i.e. to just before `>`)
    size_t tag_contents_length;
    /// Additional flags describing the type/state of this tag
    enum HFPHTMLParser_html_tag_flag flags;
} HFPHTMLParser_html_tag;

/// Represents our error codes. This are returned to consumers
enum HFPHTMLParser_Error {
    HFPHTMLPARSER_ERROR_NONE = 0,
    HFPHTMLPARSER_ERROR_OUT_OF_MEMORY = 1,
    HFPHTMLPARSER_ERROR_INVALID_ARGUMENT = 2,
    HFPHTMLPARSER_ERROR_NESTED_TAG_CONTENTS = 3,
    HFPHTMLPARSER_ERROR_BAD_TAG = 4,
};

/// Mapping table of error codes to error descriptions
static const char *error_descriptions[] = {
    [HFPHTMLPARSER_ERROR_NONE] = "Success",
    [HFPHTMLPARSER_ERROR_OUT_OF_MEMORY] = "Out of memory",
    [HFPHTMLPARSER_ERROR_INVALID_ARGUMENT] = "Invalid argument",
    [HFPHTMLPARSER_ERROR_NESTED_TAG_CONTENTS] = "Nested tags in HTML",
    [HFPHTMLPARSER_ERROR_BAD_TAG] = "Bad tag in HTML",
};

/// A value of list count that indicates the list is unordered
#define HFPHTMLPARSER_LIST_COUNT_IS_UNORDERED (-1)

enum HFPHTMLParser_crate_tags_state {
    /// We are currently reading plain, human visible text
    HFPHTMLPARSER_CREATE_TAGS_PLAIN_TEXT = 0,
    /// We are currently reading an HTML tag
    HFPHTMLPARSER_CREATE_TAGS_IN_TAG = 1,
    /// We are current reading an HTML entity for decoding
    HFPHTMLPARSER_CREATE_TAGS_IN_HTML_ENTITY = 2,
    /// We are currently reading an HTML table
    HFPHTMLPARSER_CREATE_TAGS_IN_TABLE = 3,
};

//MARK: - Implementation

/// Get the number of characters that a given character will be displayed as (multi-byte unicode characters need to be handled like this because NSString counts multi-byte chars as single characters while C does not obviously)
int visible_characters_effect_for_character(char character) {
    unsigned char first_high = (character & 0x80);
    if (first_high == 0x0) {
        //Regular ASCII
        return 1;
    } else {
        unsigned char second_high = ((character << 1) & 0x80);
        if (second_high == 0x0) {
            //Additional byte character (10xxxxxx character). Not visible
            return 0;
        } else {
            //This is the start of a multibyte character, count it (1+)
            unsigned char fourth_high = character & 0b11110000;
            if (fourth_high == 0b11110000) {
                //Patch for apple's weirdness with four byte characters
                return 2;
            } else {
                //We're multibyte but not a four byte which requires the patch, count normally
                return 1;
            }
        }
    }
}

/// Frees a tag buffer created by `create_tags_from_html`. Supports freeing broken/half initialized allocations so long as `tag_buffer_count` is correct.
static void free_html_tags(HFPHTMLParser_html_tag *tag_buffer, size_t tag_buffer_count) {
    if (!tag_buffer) {
        return;
    }
        
    free(tag_buffer);
}

/// Creates a buffer of (possibly overlapping) HTML tags by parsing a well-formatted HTML string.
/// @param html_input The HTML input to parse
/// @param html_input_length The length of the HTML input buffer
/// @param tag_output_buffer The location to place a pointer to the newly created buffer of tags. You own this buffer and are responsible for freeing it.
/// @param tag_output_count The location to place the number of generated tags
/// @return The number of human visible characters (as understood by NSAttributedString), or a negative number if an error occurred during parsing
static int parse_tags_from_html(const char *html_input, size_t html_input_length,
                                 HFPHTMLParser_html_tag **tag_output_buffer, size_t *tag_output_count,
                                 const char **plain_text_output, size_t *plain_text_length_output,
                                 size_t *human_visible_characters_output) {
    int result = HFPHTMLPARSER_ERROR_NONE;
    
    /* The plain text buffer holds the raw text that is to be formatted */
    struct HFPManagedBuffer plain_text;
    bzero(&plain_text, sizeof(plain_text));
    
    /* The tag buffer holds terminated tags */
    struct HFPManagedBuffer tags;
    bzero(&tags, sizeof(tags));

    /* The tag stack is a stack of nested HTML tags. We use a stack to ensure that closing tags have the correct termination point */
    struct HFPManagedBuffer tag_stack;
    bzero(&tag_stack, sizeof(tag_stack));
    
    /* To decode HTML entities, we need to track their start position and length. We DO NOT own these pointers, they are into `html_input` */
    const char *html_entity = NULL;
    size_t html_entity_length = 0;
    
    /* The tag that we are currently parsing in */
    HFPHTMLParser_html_tag *current_tag = NULL;
    
    /* Human visible characters count the number of UTF-16 codons we have seen */
    size_t human_visible_characters = 0;
    
    /* List counters are used to correctly number ordered/unordered list elements. INT32_MAX indicates unordered */
    int list_counter = HFPHTMLPARSER_LIST_COUNT_IS_UNORDERED;
    
    /* Tracks our current parsing state, determines how we interpret each character */
    enum HFPHTMLParser_crate_tags_state state = HFPHTMLPARSER_CREATE_TAGS_PLAIN_TEXT;
    
    for (size_t i = 0; i < html_input_length; i++) {
        char current_character = html_input[i];
        enum HFPHTMLParser_crate_tags_state last_state = state;
        
        if (current_character == '<') {
            /* Tag enter */
            state = HFPHTMLPARSER_CREATE_TAGS_IN_TAG;
            
            if (last_state == HFPHTMLPARSER_CREATE_TAGS_IN_TAG) {
                //We attempted to enter a tag while we were already in a tag. This is invalid.
                result = -HFPHTMLPARSER_ERROR_NESTED_TAG_CONTENTS;
                goto CLEANUP;
            }
            
            /* Create a new tag for our current tag context if it does not exist (i.e. we're reusing a zero'd closing tag) */
            if (!current_tag || !(current_tag = calloc(1, sizeof(*current_tag)))) {
                result = -HFPHTMLPARSER_ERROR_OUT_OF_MEMORY;
                goto CLEANUP;
            }
            
            current_tag->tag_contents = html_input + i + 1;
            current_tag->visible_start_position = human_visible_characters;
            current_tag->visible_end_position = human_visible_characters;
                        
        } else if (current_character == '>') {
            /* Tag exit */
            state = HFPHTMLPARSER_CREATE_TAGS_PLAIN_TEXT;
            
            if (!current_tag) {
                //We attempted to close a tag without having one open
                result = -HFPHTMLPARSER_ERROR_NESTED_TAG_CONTENTS;
                goto CLEANUP;
            }
            
            if (!current_tag->tag_contents_length) {
                //Empty tag
                result = -HFPHTMLPARSER_ERROR_BAD_TAG;
                goto CLEANUP;
            }
            
            //Are we a closing tag with the format `</`
            if (current_tag->tag_contents[0] == '/') {
                //Since we assume the input is well-formed, we can assume without checking that this tag is closing the last opened tag
                HFPHTMLParser_html_tag *target_tag = HFPManagedBuffer_pop_type_pointer_safe(&tag_stack);
                if (!target_tag) {
                    //Tag stack is empty, which means this closing tag has no tag to commit
                    result = -HFPHTMLPARSER_ERROR_BAD_TAG;
                    goto CLEANUP;
                }
                
                target_tag->visible_end_position = human_visible_characters;
                
                if ((result = HFPManagedBuffer_push_type_pointer_safe(&tags, target_tag)) < 0) {
                    result = -HFPHTMLPARSER_ERROR_OUT_OF_MEMORY;
                    goto CLEANUP;
                }
            } else if (current_tag->tag_contents[current_tag->tag_contents_length - 1] == '/' /* safe since length is at least 1 */) {
                if (strncmp("br/", current_tag->tag_contents, current_tag->tag_contents_length) == 0) /* are we a self-closing br tag? */ {
                    //We're a <br/> tag, drop a new line into the actual text and remove the tag
                    if ((result = HFPManagedBuffer_push_type_char_safe(&plain_text, '\n')) < 0) {
                        result = -HFPHTMLPARSER_ERROR_OUT_OF_MEMORY;
                        goto CLEANUP;
                    }

                    human_visible_characters++;
                } else {
                    //Unknown self-closing tag. Insert into tag stream since it opened and closed here
                    if ((result = HFPManagedBuffer_push_type_pointer_safe(&tags, current_tag)) < 0) {
                        result = -HFPHTMLPARSER_ERROR_OUT_OF_MEMORY;
                        goto CLEANUP;
                    }
                    
                    current_tag = NULL;
                }
            } else {
                //This is a regular opening tag, push it to our open tag stack
                if ((result = HFPManagedBuffer_push_type_pointer_safe(&tag_stack, current_tag)) < 0) {
                    result = -HFPHTMLPARSER_ERROR_OUT_OF_MEMORY;
                    goto CLEANUP;
                }
                
                //Drop the current tag pointer since it is now owned in the stack but hold a local reference since we may abort while entering the tag
                HFPHTMLParser_html_tag *pushed_tag = current_tag;
                current_tag = NULL;
                
                if (strncmp(pushed_tag->tag_contents, "ol", pushed_tag->tag_contents_length) == 0) {
                    /* Ordered list begin */
                    list_counter = 1;
                } else if (strncmp(pushed_tag->tag_contents, "ul", pushed_tag->tag_contents_length) == 0) {
                    /* Unordered list begin */
                    list_counter = INT32_MAX;
                } else if (state != HFPHTMLPARSER_CREATE_TAGS_IN_TABLE && strncmp(pushed_tag->tag_contents, "table", pushed_tag->tag_contents_length) == 0) {
                    /* Table begin */
                    state = HFPHTMLPARSER_CREATE_TAGS_IN_TABLE;
                    
                    //For tables, we set the table flag and record the inner table contents as the tag text
                    pushed_tag->flags |= HFPHTMLPARSER_HTML_TAG_FLAG_TABLE;
                    pushed_tag->tag_contents = html_input + i + 1;
                    pushed_tag->tag_contents_length = 0;
                    
                    static const char view_table_text[] = "[View table]\n";
                    size_t table_prompt_length_without_null = sizeof(view_table_text) - 1;
                    
                    if ((result = HFPManagedBuffer_push_safe(&plain_text, view_table_text, table_prompt_length_without_null)) < 0) {
                        result = -HFPHTMLPARSER_ERROR_OUT_OF_MEMORY;
                        goto CLEANUP;
                    }
                    
                    human_visible_characters += table_prompt_length_without_null;
                } else if (strncmp(pushed_tag->tag_contents, "li", pushed_tag->tag_contents_length) == 0) {
                    /* List element */
                    if (list_counter == HFPHTMLPARSER_LIST_COUNT_IS_UNORDERED) {
                        //Unicode character for a bullet and a space, used for the unordered list marker
                        static const char unordered_list_marker[] = {0xE2, 0x80, 0xA2, ' '};
                        if ((result = HFPManagedBuffer_push_safe(&plain_text, &unordered_list_marker, sizeof(unordered_list_marker))) < 0) {
                            result = -HFPHTMLPARSER_ERROR_OUT_OF_MEMORY;
                            goto CLEANUP;
                        }
                        
                        human_visible_characters += 2;
                    } else {
                        //For ordered lists, we generate the label and copy it into our display text buffer
                        char ordered_label_buffer[16];
                        int written = snprintf(ordered_label_buffer, sizeof(ordered_label_buffer), "%i. ", list_counter);
                        if ((result = HFPManagedBuffer_push_safe(&plain_text, &ordered_label_buffer, written)) < 0) {
                            result = -HFPHTMLPARSER_ERROR_OUT_OF_MEMORY;
                            goto CLEANUP;
                        }
                        
                        human_visible_characters += written;
                    }
                }
            }
            
            //If we have not removed the current tag pointer, this means it can be reused (i.e. it was not pushed to the stack or tag stream).
            if (current_tag) {
                bzero(current_tag, sizeof(*current_tag));
            }
        } else if (current_character == '&') {
            /* Entity begin */
            state = HFPHTMLPARSER_CREATE_TAGS_IN_HTML_ENTITY;
            html_entity = html_input + i;
            html_entity_length = 0;
        } else if (state == HFPHTMLPARSER_CREATE_TAGS_IN_HTML_ENTITY && current_character == ';') {
            state = HFPHTMLPARSER_CREATE_TAGS_PLAIN_TEXT;
            //FIXME: states are not mutually exlcusive, can decode entity in tag
        }
    }

CLEANUP:
    if (result < 0) {
        
    }
    return result;
}


int HFPHTMLParser_create_formatting_from_html(HFPHTMLParser_formatting **formatting_output,
                                              const char *html_input, size_t html_input_length) {
    int result = HFPHTMLPARSER_ERROR_NONE;
    size_t html_tags_count = 0;
    HFPHTMLParser_html_tag *html_tags = NULL;
    HFPHTMLParser_formatting *formatting = NULL;
    
    if (!(html_input && formatting_output)) {
        return -HFPHTMLPARSER_ERROR_INVALID_ARGUMENT;
    }
    
    if (!(formatting = calloc(1, sizeof(*formatting)))) {
        result = -HFPHTMLPARSER_ERROR_OUT_OF_MEMORY;
        goto CLEANUP;
    }
    
    if ((result = parse_tags_from_html(html_input, html_input_length,
                                        &html_tags, &html_tags_count,
                                        &formatting->plain_text, &formatting->plain_text_length,
                                        &formatting->human_visible_character_count)) < 0) {
        goto CLEANUP;
    }
    
    
    /* Parsing success, copy out results */
    *formatting_output = formatting;
    result = HFPHTMLPARSER_ERROR_NONE;
    
CLEANUP:
    free_html_tags(html_tags, html_tags_count);
    
    if (result < 0) {
        //If we failed, do not return a formatting output struct
        *formatting_output = NULL;
        HFPHTMLParser_free_formatting(formatting);
    }
    
    return result;
}

void HFPHTMLParser_free_formatting(HFPHTMLParser_formatting *formatting) {
    
}

const char * HFPHTMLParser_error_description(int error) {
    if (error < 0) {
        error = -error;
    }
    
    size_t error_count = sizeof(error_descriptions) / sizeof(*error_descriptions);
    if (error >= error_count) {
        return NULL; /* Out of bounds error */
    }
    
    return error_descriptions[error];
}
