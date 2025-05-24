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
// #include "../HTMLFastParse/C_HTML_Parser.h" // Old C parser header
#include "../Sources/HTMLSwiftParser/HTMLFastParseCAPI.h" // New Swift C-API header


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
    // All old declarations, mallocs, function calls, and frees are removed.
    
    // Call the Swift parser via the C-API
    // The C-API was defined as: int32_t fuzz_swift_parser_from_data(const uint8_t* data, int length);
    // So, a cast is needed for fuzz_size.
    fuzz_swift_parser_from_data(buffer, (int)fuzz_size);
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
