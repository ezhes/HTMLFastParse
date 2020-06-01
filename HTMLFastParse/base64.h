//
//  base64.h
//  HTMLFastParseDemo
//
//  Created by Salman Husain on 5/31/20.
//  Copyright © 2020 CarbonDev. All rights reserved.
//

#ifndef base64_h
#define base64_h

#include <stdio.h>
size_t Base64encode_len(size_t len);
size_t Base64encode(char *encoded, const char *string, size_t len);
#endif /* base64_h */
