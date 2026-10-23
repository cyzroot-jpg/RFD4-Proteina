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

#ifndef UAL_ARGS_INDEX_PUT_ARGS_H_
#define UAL_ARGS_INDEX_PUT_ARGS_H_

#include "ual/com/def.h"

using namespace tecoal::ual::common;

namespace tecoal {
namespace ual {
namespace args {

#define MAX_DIM 8

typedef struct IndexPutArgs {
    int spe_cnt;

    int sz_type;
    int list_length;

    int dim_ln_index;
    int dim_index[MAX_DIM];
    int dim_ln;
    int dim_output[MAX_DIM];
    int bro_indice[MAX_DIM];
    int dim_ln_value;
    int dim_value[MAX_DIM];
    int bro_value[MAX_DIM];
    int r_value_dim[MAX_DIM];

    void **indices;
    const void *input;
    const void *value;
    void *output;

    int accumulate;
    int TYPE_CODE;
    int FUNC_CODE;
    int is_bool_index;
    int one_nb_flag;
    int broadcast_indice;
    int broadcast_value;

    int broadcast;
} IndexPutArgs;

typedef struct IndexPutPatchArgs {
    IndexPutArgs *arg;
    UALDataType data_type;
    UALDataType index_data_type;
    UALAlgoType algo;
} IndexPutPatchArgs;

}  // namespace args
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_ARGS_INDEX_PUT_ARGS_H_
