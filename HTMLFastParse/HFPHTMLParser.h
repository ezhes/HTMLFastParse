//
//  HFPHTMLParser.h
//  HTMLFastParse
//
//  Created by Allison Husain on 5/14/21.
//

#ifndef HFPHTMLParser_h
#define HFPHTMLParser_h

#include <stdlib.h>
#include <stdio.h>


typedef struct {
    
} HFPHTMLParser_formatting_descriptor;

typedef struct {
    /// The length of the plain text string, excluding the null byte
    size_t plain_text_length;
    /// The plain text associated with the HTML
    const char *plain_text;
    /// The number of human visible characters (as defined by NSAttributedString)
    size_t human_visible_character_count;
    /// The number of format descriptors in the formatting descriptor buffer
    size_t formatting_descriptor_count;
    /// The set of linear, non-overlapping formatting descriptors
    HFPHTMLParser_formatting_descriptor *formatting_descriptors;
} HFPHTMLParser_formatting;



/// Parses HTML input into a set of non-overlapping formatting directions. Each formatting description covers a discrete range and each formatting descriptor is distinct from the previous
/// @param html_input The HTML to format
/// @param html_input_length The length of the input (excluding the NULL)
/// @param formatting_output The location to place a pointer to the formatting result. You must free this with `HFPHTMLParser_free_formatting` when you are done
int HFPHTMLParser_create_formatting_from_html(HFPHTMLParser_formatting **formatting_output,
                                              const char *html_input, size_t html_input_length);


/// Free a formatting result and all dependent resources
/// @param formatting The formatting result to release
void HFPHTMLParser_free_formatting(HFPHTMLParser_formatting *formatting);


/// Converts a (negative) return code to an error code, or NULL of the error code is not known
/// @param error The negative error code returned by an HFPHTMLParser function
const char * HFPHTMLParser_error_description(int error);


#endif /* HFPHTMLParser_h */
