//
//  HFPManagedBuffer.h
//  HTMLFastParse
//
//  Created by Allison Husain on 5/30/21.
//

#ifndef HFPManagedBuffer_h
#define HFPManagedBuffer_h

#include <stdlib.h>
#include <string.h>

/*
 HFPManagedBuffer is a set of functions meant to make simple buffer operations like pushing and popping both easier and safer.
 It is not meant to act as an abstraction.
 */

struct HFPManagedBuffer {
    /// The underlying buffer
    void *buffer;
    /// The number of allocated elements
    size_t buffer_allocated_count;
    /// The number of used slots in the buffer
    size_t element_count;
    /// The size of the elements in the buffer
    size_t element_size;
};

inline int HFPManagedBuffer_grow(struct HFPManagedBuffer *buffer, size_t new_element_count) {
    if (buffer->element_count + new_element_count >= buffer->buffer_allocated_count) {
        /* We need to grow the buffer */
        void *new_buffer = realloc(buffer->buffer, buffer->buffer_allocated_count * buffer->element_size * 2);
        if (!new_buffer) {
            return -1;
        }
        
        buffer->buffer = new_buffer;
    }
    
    return 0;
}

/// Safely push a pointer element to the end of a buffer
/// @param buffer The buffer to push to
/// @param element The address of the element that should be pushed
/// @return Negative on error, zero on success. On error, the buffer is not freed
inline int HFPManagedBuffer_push_type_pointer_safe(struct HFPManagedBuffer *buffer, void *element) {
    if (HFPManagedBuffer_grow(buffer, 1) < 0) {
        return -1;
    }
    
    ((void **)(buffer->buffer))[buffer->element_count++] = element;
    return 0;
}

/// Safely push a pointer element to the end of a buffer
/// @param buffer The buffer to push to
/// @param element The address of the element that should be pushed
/// @return Negative on error, zero on success. On error, the buffer is not freed
inline int HFPManagedBuffer_push_type_char_safe(struct HFPManagedBuffer *buffer, char element) {
    if (HFPManagedBuffer_grow(buffer, 1) < 0) {
        return -1;
    }
    
    ((char *)(buffer->buffer))[buffer->element_count++] = element;
    return 0;
}


/// Push `element_count` items starting at pointer `elements_ptr` safely
inline int HFPManagedBuffer_push_safe(struct HFPManagedBuffer *buffer, const void *elements_ptr, size_t element_count) {
    if (HFPManagedBuffer_grow(buffer, element_count) < 0) {
        return -1;
    }
    
    memcpy((uint8_t *)(buffer->buffer) + buffer->element_size * buffer->element_count, elements_ptr, buffer->element_size * element_count);
    return 0;
}

inline void * HFPManagedBuffer_pop_type_pointer_safe(struct HFPManagedBuffer *buffer) {
    if (buffer->element_count == 0) {
        return NULL;
    }
    
    return ((void **)(buffer->buffer))[buffer->element_count--];
}

#endif /* HFPManagedBuffer_h */
