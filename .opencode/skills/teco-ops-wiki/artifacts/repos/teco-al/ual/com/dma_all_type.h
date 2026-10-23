// BSD 3- Clause License Copyright (c) 2024, Tecorigin Co., Ltd. All rights
// reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// Neither the name of the copyright holder nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY,OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)  ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
// OF SUCH DAMAGE.

#ifndef UAL_COM_DMA_ALL_TYPE_H_
#define UAL_COM_DMA_ALL_TYPE_H_

#define ADDRESS_MODE_4(x) ((unsigned long)(x) % 4)
#define MIN(a, b) ((a) < (b) ? (a) : (b))

template <typename Type>
__device__ __inline__ __attribute__((always_inline)) void allDmaIgetSdaa(
    Type *dest, const Type *src, int size, sdaa::MemcpyHandle &get_reply) {  // NOLINT
    sdaa::memcpy_async(dest, src, size, sdaa::MemcpyGlobalToSpm, get_reply);
}

template <typename Type>
__device__ __inline__ __attribute__((always_inline)) void allDmaIgetTwoByteAlignedSdaa(
    Type *dest, const Type *src, int size, sdaa::MemcpyHandle &get_reply) {  // NOLINT
    if (ADDRESS_MODE_4(dest) == ADDRESS_MODE_4(src)) {  // first address alignment
        int left_unaligned_flag = ADDRESS_MODE_4(dest);
        int right_unaligned_flag = ADDRESS_MODE_4((uint8_t *)dest + size);
        int reminder_size = size - left_unaligned_flag - right_unaligned_flag;
        if (reminder_size > 0) {
            sdaa::memcpy_async(dest + left_unaligned_flag / 2, src + left_unaligned_flag / 2,
                               reminder_size, sdaa::MemcpyGlobalToSpm, get_reply);
        }

        if (left_unaligned_flag) {
            *dest = *src;
        }
        if (right_unaligned_flag) {
            *(dest + (reminder_size + left_unaligned_flag) / 2) =
                *(src + (reminder_size + left_unaligned_flag) / 2);
        }
    } else {
        memcpy((void *)dest, (void *)src, size);
    }
}

template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIgetSdaa<uint16_t>(
    uint16_t *dest, const uint16_t *src, int size, sdaa::MemcpyHandle &get_reply) {  // NOLINT
    allDmaIgetTwoByteAlignedSdaa(dest, src, size, get_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIgetSdaa<int16_t>(
    int16_t *dest, const int16_t *src, int size, sdaa::MemcpyHandle &get_reply) {  // NOLINT
    allDmaIgetTwoByteAlignedSdaa(dest, src, size, get_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIgetSdaa<half>(
    half *dest, const half *src, int size, sdaa::MemcpyHandle &get_reply) {  // NOLINT
    allDmaIgetTwoByteAlignedSdaa(dest, src, size, get_reply);
}

template <typename Type>
__device__ __inline__ __attribute__((always_inline)) void allDmaIgetOneByteAlignedSdaa(
    Type *dest, const Type *src, int size, sdaa::MemcpyHandle &get_reply) {  // NOLINT
    if (ADDRESS_MODE_4(dest) == ADDRESS_MODE_4(src)) {  // first address alignment
        int left_reminder = MIN((4 - ADDRESS_MODE_4(dest)) % 4, size);
        int right_reminder = (size - left_reminder) % 4;
        if (size - left_reminder - right_reminder > 0) {
            sdaa::memcpy_async(dest + left_reminder, src + left_reminder,
                               size - left_reminder - right_reminder, sdaa::MemcpyGlobalToSpm,
                               get_reply);
        }
        for (int i = 0; i < left_reminder; i++) {
            *(dest + i) = *(src + i);
        }
        for (int i = 0; i < right_reminder; i++) {
            *(dest + size - i - 1) = *(src + size - i - 1);
        }
    } else {
        memcpy((void *)dest, (void *)src, size);
    }
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIgetSdaa<uint8_t>(
    uint8_t *dest, const uint8_t *src, int size, sdaa::MemcpyHandle &get_reply) {  // NOLINT
    allDmaIgetOneByteAlignedSdaa(dest, src, size, get_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIgetSdaa<int8_t>(
    int8_t *dest, const int8_t *src, int size, sdaa::MemcpyHandle &get_reply) {  // NOLINT
    allDmaIgetOneByteAlignedSdaa(dest, src, size, get_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIgetSdaa<bool>(
    bool *dest, const bool *src, int size, sdaa::MemcpyHandle &get_reply) {  // NOLINT
    allDmaIgetOneByteAlignedSdaa(dest, src, size, get_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIgetSdaa<char>(
    char *dest, const char *src, int size, sdaa::MemcpyHandle &get_reply) {  // NOLINT
    allDmaIgetOneByteAlignedSdaa(dest, src, size, get_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIgetSdaa<void>(
    void *dest, const void *src, int size, sdaa::MemcpyHandle &get_reply) {  // NOLINT
    allDmaIgetOneByteAlignedSdaa((uint8_t *)dest, (const uint8_t *)src, size, get_reply);
}

template <typename Type>
__device__ __inline__ __attribute__((always_inline)) void allDmaIputSdaa(
    Type *dest, Type *src, int size, sdaa::MemcpyHandle &put_reply) {  // NOLINT
    sdaa::memcpy_async(dest, src, size, sdaa::MemcpySpmToGlobal, put_reply);
}

template <typename Type>
__device__ __inline__ __attribute__((always_inline)) void allDmaIputTwoByteAlignedSdaa(
    Type *dest, Type *src, int size, sdaa::MemcpyHandle &put_reply) {  // NOLINT
    if (ADDRESS_MODE_4(dest) == ADDRESS_MODE_4(src)) {                 // first address alignment
        int left_unaligned_flag = ADDRESS_MODE_4(dest);
        int right_unaligned_flag = ADDRESS_MODE_4((uint8_t *)dest + size);
        int reminder_size = size - left_unaligned_flag - right_unaligned_flag;
        if (reminder_size > 0) {
            sdaa::memcpy_async(dest + left_unaligned_flag / 2, src + left_unaligned_flag / 2,
                               reminder_size, sdaa::MemcpySpmToGlobal, put_reply);
        }

        if (left_unaligned_flag) {
            *dest = *src;
        }
        if (right_unaligned_flag) {
            *(dest + (reminder_size + left_unaligned_flag) / 2) =
                *(src + (reminder_size + left_unaligned_flag) / 2);
        }
    } else {
        memcpy((void *)dest, (void *)src, size);
    }
}

template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIputSdaa<uint16_t>(
    uint16_t *dest, uint16_t *src, int size, sdaa::MemcpyHandle &put_reply) {  // NOLINT
    allDmaIputTwoByteAlignedSdaa(dest, src, size, put_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIputSdaa<int16_t>(
    int16_t *dest, int16_t *src, int size, sdaa::MemcpyHandle &put_reply) {  // NOLINT
    allDmaIputTwoByteAlignedSdaa(dest, src, size, put_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIputSdaa<half>(
    half *dest, half *src, int size, sdaa::MemcpyHandle &put_reply) {  // NOLINT
    allDmaIputTwoByteAlignedSdaa(dest, src, size, put_reply);
}

template <typename Type>
__device__ __inline__ __attribute__((always_inline)) void allDmaIputOneByteAlignedSdaa(
    Type *dest, Type *src, int size, sdaa::MemcpyHandle &put_reply) {  // NOLINT
    if (ADDRESS_MODE_4(dest) == ADDRESS_MODE_4(src)) {                 // first address alignment
        int left_reminder = MIN((4 - ADDRESS_MODE_4(dest)) % 4, size);
        int right_reminder = (size - left_reminder) % 4;
        if (size - left_reminder - right_reminder > 0) {
            sdaa::memcpy_async(dest + left_reminder, src + left_reminder,
                               size - left_reminder - right_reminder, sdaa::MemcpySpmToGlobal,
                               put_reply);
        }

        for (int i = 0; i < left_reminder; i++) {
            *(dest + i) = *(src + i);
        }
        for (int i = 0; i < right_reminder; i++) {
            *(dest + size - i - 1) = *(src + size - i - 1);
        }
    } else {
        memcpy((void *)dest, (void *)src, size);
    }
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIputSdaa<uint8_t>(
    uint8_t *dest, uint8_t *src, int size, sdaa::MemcpyHandle &put_reply) {  // NOLINT
    allDmaIputOneByteAlignedSdaa(dest, src, size, put_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIputSdaa<int8_t>(
    int8_t *dest, int8_t *src, int size, sdaa::MemcpyHandle &put_reply) {  // NOLINT
    allDmaIputOneByteAlignedSdaa(dest, src, size, put_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIputSdaa<bool>(
    bool *dest, bool *src, int size, sdaa::MemcpyHandle &put_reply) {  // NOLINT
    allDmaIputOneByteAlignedSdaa(dest, src, size, put_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIputSdaa<char>(
    char *dest, char *src, int size, sdaa::MemcpyHandle &put_reply) {  // NOLINT
    allDmaIputOneByteAlignedSdaa(dest, src, size, put_reply);
}
template <>
__device__ __inline__ __attribute__((always_inline)) void allDmaIputSdaa<void>(
    void *dest, void *src, int size, sdaa::MemcpyHandle &put_reply) {  // NOLINT
    allDmaIputOneByteAlignedSdaa((uint8_t *)dest, (uint8_t *)src, size, put_reply);
}

// get_address
template <typename TYPE>
__device__ __inline__ __attribute__((always_inline)) TYPE *get_aligned_address(
    const TYPE *align_address, TYPE *source_address) {
    size_t src_offset = ADDRESS_MODE_4(source_address),
           aligned_offset = ADDRESS_MODE_4(align_address);
    if (src_offset == aligned_offset) {
        return source_address;
    } else if (aligned_offset > src_offset) {
        return source_address + (aligned_offset - src_offset) / sizeof(TYPE);
    } else {
        return source_address + (4 - aligned_offset + src_offset) / sizeof(TYPE);
    }
}

template <>
__device__ __inline__ __attribute__((always_inline)) uint64_t *get_aligned_address(
    const uint64_t *align_address, uint64_t *source_address) {
    return source_address;
}

template <>
__device__ __inline__ __attribute__((always_inline)) uint32_t *get_aligned_address(
    const uint32_t *align_address, uint32_t *source_address) {
    return source_address;
}

template <>
__device__ __inline__ __attribute__((always_inline)) uint16_t *get_aligned_address(
    const uint16_t *align_address, uint16_t *source_address) {
    int non_4B_aligned_flag = ADDRESS_MODE_4(align_address) != 0;
    return source_address + non_4B_aligned_flag;
}

template <>
__device__ __inline__ __attribute__((always_inline)) _Float16 *get_aligned_address(
    const _Float16 *align_address, _Float16 *source_address) {
    int non_4B_aligned_flag = ADDRESS_MODE_4(align_address) != 0;
    return source_address + non_4B_aligned_flag;
}

template <>
__device__ __inline__ __attribute__((always_inline)) uint8_t *get_aligned_address(
    const uint8_t *align_address, uint8_t *source_address) {
    int non_4B_aligned_byte = ADDRESS_MODE_4(align_address);
    return source_address + non_4B_aligned_byte;
}

#endif  // UAL_COM_DMA_ALL_TYPE_H_
