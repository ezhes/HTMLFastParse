#ifndef HTMLFastParseCAPI_h
#define HTMLFastParseCAPI_h

#include <stddef.h> // For size_t (though Swift func uses Int, C might use size_t)
#include <stdint.h> // For int32_t, uint8_t

#ifdef __cplusplus
extern "C" {
#endif

// Declaration of the C-callable Swift function
// The actual name will be `fuzz_swift_parser_from_data` due to @_cdecl.
// The parameters match the Swift function.
int32_t fuzz_swift_parser_from_data(const uint8_t* data, int length);

#ifdef __cplusplus
}
#endif

#endif /* HTMLFastParseCAPI_h */
