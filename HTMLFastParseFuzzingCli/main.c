//
//  main.c
//  HTMLFastParseDemoFuzzingCli
//
//  Created by Allison Husain on 1/1/21.
//  Copyright © 2021 CarbonDev. All rights reserved.
//

#include <stdint.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include "../HTMLFastParse/C_HTML_Parser.h"


/*
 0 = debug / blackbox
 1 = coverage guided honggfuzz
 */

#define FUZZ_MODE 0
#if FUZZ_MODE == 1
#include <libhfuzz/instrument.h>
#endif

extern void HF_ITER(uint8_t** buf, size_t* len);

__attribute__ ((optnone))
void do_fuzz_case(uint8_t* buffer, size_t fuzz_size) {
    struct t_tag* tokens = NULL;
    struct t_format* format_tokens = NULL;
    char* display_text = NULL;
    char *input = (char *)buffer;
    unsigned long inputLength = strnlen(input, fuzz_size);
    
    if (!(tokens = malloc(inputLength * sizeof(struct t_tag)))
          || !(format_tokens =  malloc(inputLength * sizeof(struct t_format)))) {
        goto CLEANUP;
    }

    
    int numberOfTags = -1;
    int numberOfHumanVisibleCharachters = -1;
    display_text = tokenizeHTML(input, inputLength, tokens, &numberOfTags, &numberOfHumanVisibleCharachters);

    
    int numberOfSimplifiedTags = -1;
    makeAttributesLinear(tokens, (int)numberOfTags, format_tokens, &numberOfSimplifiedTags, numberOfHumanVisibleCharachters);
    
CLEANUP:
    if (tokens) {
        free(tokens);
    }
    
    if (format_tokens) {
        free(format_tokens);
    }
    
    if (display_text) {
        free(display_text);
    }

}

__attribute__ ((optnone)) int main(int argc, const char * argv[]) {
    size_t fuzz_size;
    uint8_t* buffer;
    
#if FUZZ_MODE == 1
    for (int i = 0; i < 100000; i++) {
        HF_ITER(&buffer, &fuzz_size);
#else
    if (argc != 2) {
        return 1;
    }
    
    struct stat s;
    int fd = open(argv[1], O_RDONLY);
    if (fd < 0) {
        return 1;
    }
    
    fstat(fd, &s);
    fuzz_size = s.st_size;
    buffer = mmap(NULL, fuzz_size, PROT_READ, MAP_SHARED, fd, 0);
    
    close(fd);
    
    if (buffer == MAP_FAILED) {
        return 2;
    }
#endif

    do_fuzz_case(buffer, fuzz_size);
#if FUZZ_MODE == 1
    }
#endif

    return 0;
}
