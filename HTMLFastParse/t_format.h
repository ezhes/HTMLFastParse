//
//  t_format.h
//  HTMLFastParse
//
//  Created by Allison Husain on 4/27/18.
//  Copyright © 2018 CarbonDev. All rights reserved.
//

#ifndef t_format_h
#define t_format_h

#define FORMAT_TAG_IS_BOLD 1<<0
#define FORMAT_TAG_IS_ITALICS 1<<1
#define FORMAT_TAG_IS_STRUCK 1<<2
#define FORMAT_TAG_IS_CODE 1<<3
#define FORMAT_TAG_H_LEVEL 1<<4
#define FORMAT_TAG_H_MASK 0b1111<<4

#define FORMAT_TAG_GET_BIT_FIELD(v, field) (v & field) >> field
#define FORMAT_TAG_GET_H_LEVEL(v) (v & FORMAT_TAG_H_MASK)/FORMAT_TAG_H_LEVEL
//#define FORMAT_TAG_SET_FIELD(v, field, value) 
/**
 A structure representing a character/range's text formatting
 
 BIT MAP:
 1 bold
 2 italics
 3 struck
 4 code
 5 HLEVEL_BIT_1
 6 HLEVEL_BIT_2
 7 HLEVEL_BIT_3
 8 HLEVEL_BIT_4
 */
struct t_format {
	//ZERO MEANS DISABLED
    
    /**
        Format tag blob. See t_format.h for what each bit means.
     */
    unsigned char formatTag;
	unsigned char exponentLevel;
	unsigned char quoteLevel;
    unsigned char listNestLevel;
	char *linkURL;
	
	unsigned int startPosition;
	unsigned int endPosition;
};

#endif /* t_format_h */
