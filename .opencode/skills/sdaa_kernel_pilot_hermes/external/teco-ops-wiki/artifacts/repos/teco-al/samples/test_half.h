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

#ifndef SAMPLES_TEST_HALF_H_
#define SAMPLES_TEST_HALF_H_

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <cstdio>

typedef uint16_t half_t;
typedef uint16_t half_rep_t;
typedef float float_t;
typedef uint32_t float_rep_t;

static float __half2float(half_t a);
static half_t __float2half(float a);
static void transform_data_h2f(void *dst, void *src, int num);
static void transform_data_f2h(void *dst, void *src, int num);

// #############################################################################
#ifndef CHAR_BIT
#define CHAR_BIT 8
#endif

static const int halfSigBits = 10;
static const int floatSigBits = 23;

static inline half_rep_t halfToRep(half_t x) {
    const union {
        half_t f;
        half_rep_t i;
    } rep = {.f = x};
    return rep.i;
}

static inline float_rep_t floatToRep(float x) {
    const union {
        float f;
        float_rep_t i;
    } rep = {.f = x};
    return rep.i;
}

static inline half_t halfFromRep(half_rep_t x) {
    const union {
        half_t f;
        half_rep_t i;
    } rep = {.i = x};
    return rep.f;
}

static inline float floatFromRep(float_rep_t x) {
    const union {
        float f;
        float_rep_t i;
    } rep = {.i = x};
    return rep.f;
}

static void print_half_bits(half_t a) {
    uint16_t mask = 0x1;
    for (int i = 15; i >= 0; i--) {
        printf(" %d", (a >> i) & mask);
        if (i == 15) printf(" | ");
        if (i == 10) printf(" | ");
    }
    printf("\n");
}

static void print_float_bits(float a) {
    uint32_t mask = 0x1;
    for (int i = 31; i >= 0; i--) {
        float_rep_t tmp = floatToRep(a);
        printf(" %d", (tmp >> i) & mask);
        if (i == 31) printf(" | ");
        if (i == 23) printf(" | ");
    }
    printf("\n");
}

float __half2float(half_t a) {
    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const int halfBits = sizeof(half_t) * CHAR_BIT;
    const int halfExpBits = halfBits - halfSigBits - 1;
    const int halfInfExp = (1 << halfExpBits) - 1;
    const int halfExpBias = halfInfExp >> 1;

    const half_rep_t halfMinNormal = (half_rep_t)(1) << halfSigBits;
    const half_rep_t halfInfinity = (half_rep_t)halfInfExp << halfSigBits;
    const half_rep_t halfSignMask = (half_rep_t)(1) << (halfSigBits + halfExpBits);
    const half_rep_t halfAbsMask = halfSignMask - 1;
    const half_rep_t halfQNaN = (half_rep_t)(1) << (halfSigBits - 1);
    const half_rep_t halfNaNCode = halfQNaN - 1;

    const int floatBits = sizeof(float) * CHAR_BIT;
    const int floatExpBits = floatBits - floatSigBits - 1;
    const int floatInfExp = (1 << floatExpBits) - 1;
    const int floatExpBias = floatInfExp >> 1;

    const float_rep_t floatMinNormal = (float_rep_t)(1) << floatSigBits;

    // Break a into a sign and representation of the absolute value
    const half_rep_t aRep = halfToRep(a);
    const half_rep_t aAbs = aRep & halfAbsMask;
    const half_rep_t sign = aRep & halfSignMask;
    float_rep_t absResult;

    // If sizeof(half_rep_t) < sizeof(int), the subtraction result is promoted
    // to (signed) int.  To avoid that, explicitly cast to half_rep_t.
    if ((half_rep_t)(aAbs - halfMinNormal) < halfInfinity - halfMinNormal) {
        // a is a normal number.
        // Extend to the destination type by shifting the significand and
        // exponent into the proper position and rebiasing the exponent.
        absResult = (float_rep_t)aAbs << (floatSigBits - halfSigBits);
        absResult += (float_rep_t)(floatExpBias - halfExpBias) << floatSigBits;
    } else if (aAbs >= halfInfinity) {
        // a is NaN or infinity.
        // Conjure the result by beginning with infinity, then setting the qNaN
        // bit (if needed) and right-aligning the rest of the trailing NaN
        // payload field.
        absResult = (float_rep_t)floatInfExp << floatSigBits;
        absResult |= (float_rep_t)(aAbs & halfQNaN) << (floatSigBits - halfSigBits);
        absResult |= (float_rep_t)(aAbs & halfNaNCode) << (floatSigBits - halfSigBits);
    } else if (aAbs) {
        // a is denormal.
        // renormalize the significand and clear the leading bit, then insert
        // the correct adjusted exponent in the destination type.
        const int scale = __builtin_clz(aAbs) - __builtin_clz(halfMinNormal);
        absResult = (float_rep_t)aAbs << (floatSigBits - halfSigBits + scale);
        absResult ^= floatMinNormal;
        const int resultExponent = floatExpBias - halfExpBias - scale + 1;
        absResult |= (float_rep_t)resultExponent << floatSigBits;
    } else {
        // a is zero.
        absResult = 0;
    }

    // Apply the signbit to (float)abs(a).
    const float_rep_t result = absResult | (float_rep_t)sign << (floatBits - halfBits);
    return floatFromRep(result);
}

half_t __float2half(float a) {
    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const int floatBits = sizeof(float) * CHAR_BIT;
    const int floatExpBits = floatBits - floatSigBits - 1;
    const int floatInfExp = (1 << floatExpBits) - 1;
    const int floatExpBias = floatInfExp >> 1;

    const float_rep_t floatMinNormal = (float_rep_t)(1) << floatSigBits;
    const float_rep_t floatSignificandMask = floatMinNormal - 1;
    const float_rep_t floatInfinity = (float_rep_t)floatInfExp << floatSigBits;
    const float_rep_t floatSignMask = (float_rep_t)(1) << (floatSigBits + floatExpBits);
    const float_rep_t floatAbsMask = floatSignMask - 1;
    const float_rep_t roundMask = ((float_rep_t)(1) << (floatSigBits - halfSigBits)) - 1;
    const float_rep_t halfway = (float_rep_t)(1) << (floatSigBits - halfSigBits - 1);
    const float_rep_t floatQNaN = (float_rep_t)(1) << (floatSigBits - 1);
    const float_rep_t floatNaNCode = floatQNaN - 1;

    const int halfBits = sizeof(half_t) * CHAR_BIT;
    const int halfExpBits = halfBits - halfSigBits - 1;
    const int halfInfExp = (1 << halfExpBits) - 1;
    const int halfExpBias = halfInfExp >> 1;

    const int underflowExponent = floatExpBias + 1 - halfExpBias;
    const int overflowExponent = floatExpBias + halfInfExp - halfExpBias;
    const float_rep_t underflow = (float_rep_t)underflowExponent << floatSigBits;
    const float_rep_t overflow = (float_rep_t)overflowExponent << floatSigBits;

    const half_rep_t halfQNaN = (half_rep_t)(1) << (halfSigBits - 1);
    const half_rep_t halfNaNCode = halfQNaN - 1;

    // Break a into a sign and representation of the absolute value
    const float_rep_t aRep = floatToRep(a);
    const float_rep_t aAbs = aRep & floatAbsMask;
    const float_rep_t sign = aRep & floatSignMask;
    half_rep_t absResult;

    if (aAbs - underflow < aAbs - overflow) {
        // The exponent of a is within the range of normal numbers in the
        // destination format.  We can convert by simply right-shifting with
        // rounding and adjusting the exponent.
        absResult = aAbs >> (floatSigBits - halfSigBits);
        absResult -= (half_rep_t)(floatExpBias - halfExpBias) << halfSigBits;

        const float_rep_t roundBits = aAbs & roundMask;
        // Round to nearest
        if (roundBits > halfway) absResult++;
        // Ties to even
        else if (roundBits == halfway)
            absResult += absResult & 1;
    } else if (aAbs > floatInfinity) {
        // a is NaN.
        // Conjure the result by beginning with infinity, setting the qNaN
        // bit and inserting the (truncated) trailing NaN field.
        absResult = (half_rep_t)halfInfExp << halfSigBits;
        absResult |= halfQNaN;
        absResult |= ((aAbs & floatNaNCode) >> (floatSigBits - halfSigBits)) & halfNaNCode;
    } else if (aAbs >= overflow) {
        // a overflows to infinity.
        absResult = (half_rep_t)halfInfExp << halfSigBits;
    } else {
        // a underflows on conversion to the destination type or is an exact
        // zero.  The result may be a denormal or zero.  Extract the exponent
        // to get the shift amount for the denormalization.
        const int aExp = aAbs >> floatSigBits;
        const int shift = floatExpBias - halfExpBias - aExp + 1;

        const float_rep_t significand = (aRep & floatSignificandMask) | floatMinNormal;

        // Right shift by the denormalization amount with sticky.
        if (shift > floatSigBits) {
            absResult = 0;
        } else {
            const int sticky = (significand << (floatBits - shift) != 0) ? 1 : 0;
            float_rep_t denormalizedSignificand = significand >> shift | sticky;
            absResult = denormalizedSignificand >> (floatSigBits - halfSigBits);
            const float_rep_t roundBits = denormalizedSignificand & roundMask;
            // Round to nearest
            if (roundBits > halfway) absResult++;
            // Ties to even
            else if (roundBits == halfway)
                absResult += absResult & 1;
        }
    }

    // Apply the signbit to (half_t)abs(a).
    const half_rep_t result = absResult | sign >> (floatBits - halfBits);
    return halfFromRep(result);
}

static void transform_data_h2f(void *dst, void *src, int num) {
    half_t *src_f16 = (half_t *)src;
    float *dst_f32 = (float *)dst;

    for (int i = 0; i < num; i++) {
        dst_f32[i] = __half2float(src_f16[i]);
    }
}

static void transform_data_f2h(void *dst, void *src, int num) {
    float *src_f32 = (float *)src;
    half_t *dst_f16 = (half_t *)dst;

    for (int i = 0; i < num; i++) {
        dst_f16[i] = __float2half(src_f32[i]);
    }
}

#endif  // SAMPLES_TEST_HALF_H_
