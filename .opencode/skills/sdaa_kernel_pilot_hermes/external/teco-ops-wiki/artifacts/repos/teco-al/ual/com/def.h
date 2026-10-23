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

#ifndef UAL_COM_DEF_H_
#define UAL_COM_DEF_H_

namespace tecoal {
namespace ual {
namespace common {
typedef enum {
    SUCCESS = 0,
    BAD_PARAMETER = 1,
    NOT_INITIALIZED = 2,
    NOT_SUPPORTED = 3,
    NOT_IMPLEMENTED = 4,
    NO_IMPLEMENTATION = 5,
    REINITIALIZED = 6,
    TRY_FAILED = 7
} Status;

typedef enum {
    UAL_LAYOUT_ARRAY = 0,
    UAL_LAYOUT_NHWC = 1,
    UAL_LAYOUT_NCHW = 2,
    UAL_LAYOUT_CHWN = 3,
    UAL_LAYOUT_NWHC = 4,
} UALLayout;

typedef enum {
    UAL_DTYPE_FLOAT = 0,
    UAL_DTYPE_HALF = 1,
    UAL_DTYPE_INT8 = 2,
    UAL_DTYPE_INT16 = 3,
    UAL_DTYPE_INT32 = 4,
    UAL_DTYPE_INT64 = 5,
    UAL_DTYPE_UINT8 = 6,
    UAL_DTYPE_BOOL = 7,
    UAL_DTYPE_DOUBLE = 8,
    UAL_DTYPE_UINT16 = 9,
    UAL_DTYPE_UINT32 = 10,
    UAL_DTYPE_UINT64 = 11,
    UAL_DTYPE_COMPLEX_FLOAT = 12,
    UAL_DTYPE_COMPLEX_HALF = 13,
    UAL_DTYPE_COMPLEX_DOUBLE = 14,
    UAL_DTYPE_BFLOAT16 = 15,
} UALDataType;

typedef enum UALOperation {
    UAL_OP_N = 0,  // no transpose
    UAL_OP_T = 1,  // transpose
    UAL_OP_C = 2,  // conjugate transpose
} UALOperation;

typedef enum {
    UAL_ALGO_0 = 0,
    UAL_ALGO_1,
    UAL_ALGO_2,
    UAL_ALGO_3,
    UAL_ALGO_4,
    UAL_ALGO_5,
    UAL_ALGO_6,
    UAL_ALGO_7,
    UAL_ALGO_8,
    UAL_ALGO_9,
    UAL_ALGO_10,
    UAL_ALGO_11,
    UAL_ALGO_12,
    UAL_ALGO_13,
    UAL_ALGO_14,
    UAL_ALGO_15,
    UAL_ALGO_16,
    UAL_ALGO_17,
    UAL_ALGO_18,
    UAL_ALGO_19,
    UAL_ALGO_20,
    UAL_ALGO_21,
    UAL_ALGO_22,
    UAL_ALGO_23,
    UAL_ALGO_24,
    UAL_ALGO_25,
    UAL_ALGO_26,
    UAL_ALGO_27,
    UAL_ALGO_28,
    UAL_ALGO_29,
    UAL_ALGO_30,
    UAL_ALGO_31,
    UAL_ALGO_32,
    UAL_ALGO_33,
    UAL_ALGO_34,
    UAL_ALGO_35,
    UAL_ALGO_36,
    UAL_ALGO_37,
    UAL_ALGO_38,
    UAL_ALGO_39,
    UAL_ALGO_40,
    UAL_ALGO_41,
    UAL_ALGO_42,
    UAL_ALGO_43,
    UAL_ALGO_44,
    UAL_ALGO_45,
    UAL_ALGO_46,
    UAL_ALGO_47,
    UAL_ALGO_48,
    UAL_ALGO_49,
    UAL_ALGO_50,
    UAL_ALGO_51,
    UAL_ALGO_52,
    UAL_ALGO_53,
    UAL_ALGO_54,
    UAL_ALGO_55,
    UAL_ALGO_56,
    UAL_ALGO_57,
    UAL_ALGO_58,
    UAL_ALGO_59,
    UAL_ALGO_60,
    UAL_ALGO_61,
    UAL_ALGO_62,
    UAL_ALGO_63,
    UAL_ALGO_64,
    UAL_ALGO_65,
    UAL_ALGO_66,
    UAL_ALGO_67,
    UAL_ALGO_68,
    UAL_ALGO_69,
    UAL_ALGO_70,
    UAL_ALGO_71,
    UAL_ALGO_72,
    UAL_ALGO_73,
    UAL_ALGO_74,
    UAL_ALGO_75,
    UAL_ALGO_76,
    UAL_ALGO_77,
    UAL_ALGO_78,
    UAL_ALGO_79,
    UAL_ALGO_80,
    UAL_ALGO_81,
    UAL_ALGO_82,
    UAL_ALGO_83,
    UAL_ALGO_84,
    UAL_ALGO_85,
    UAL_ALGO_86,
    UAL_ALGO_87,
    UAL_ALGO_88,
    UAL_ALGO_89,
    UAL_ALGO_90,
    UAL_ALGO_91,
    UAL_ALGO_92,
    UAL_ALGO_93,
    UAL_ALGO_94,
    UAL_ALGO_95,
    UAL_ALGO_96,
    UAL_ALGO_97,
    UAL_ALGO_98,
    UAL_ALGO_99,
    UAL_ALGO_100,
    UAL_ALGO_101,
    UAL_ALGO_102,
    UAL_ALGO_103,
    UAL_ALGO_104,
    UAL_ALGO_105,
    UAL_ALGO_106,
    UAL_ALGO_107,
    UAL_ALGO_108,
    UAL_ALGO_109,
    UAL_ALGO_110
} UALAlgoType;

// used by unary ops
typedef enum {
    // without alpha
    // UAL_BATCH_LOG = 0,
    // UAL_BATCH_EXP = 1,
    // UAL_BATCH_SQRT = 2,
    // UAL_BATCH_RSQRT = 3,
    // UAL_BATCH_SQUARE = 4,
    // UAL_BATCH_SIN = 5,
    // UAL_BATCH_COS = 6,
    // UAL_BATCH_TANH = 7,
    // UAL_BATCH_CEIL = 8,
    // UAL_BATCH_FLOOR = 9,
    // UAL_BATCH_FABS = 10,

    // with alpha
    UAL_BATCH_ADD_A = 11,
    // UAL_BATCH_SUB_A = 12,
    UAL_BATCH_MUL_A = 13,
    // UAL_BATCH_DIV_A = 14,
    // UAL_BATCH_RDIV = 15,
    // UAL_BATCH_POW = 16,

    // convert
    // UAL_BATCH_S2H = 17,
    // UAL_BATCH_H2S = 18
} UALUnaryOpsMode;

}  // namespace common
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_COM_DEF_H_
