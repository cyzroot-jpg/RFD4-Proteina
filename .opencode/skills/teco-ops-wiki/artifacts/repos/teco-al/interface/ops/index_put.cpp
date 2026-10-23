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

#include <utility>
#include "interface/include/tecoal.h"
#include "interface/include/builtin_type.h"
#include "interface/common/marco.h"
#include "ual/args/index_put_args.h"
#include "ual/com/log.h"
#include "ual/ops/index_put/index_put.hpp"

using tecoal::ual::ops::IndexPutOp;
using tecoal::ual::args::IndexPutArgs;
using tecoal::ual::args::IndexPutPatchArgs;
using tecoal::Convert;

static inline void reverse_array(int *array, int length) {
    int loop_cnt = length >> 1;
    for (int i = 0; i < loop_cnt; ++i) {
        std::swap(array[i], array[length - 1 - i]);
    }
}

tecoalStatus_t TECOALWINAPI
tecoalIndexPut(tecoalHandle_t handle, int indices_length, bool accumulate,
               const tecoalTensorDescriptor_t *indicesDesc, void **indices,
               const tecoalTensorDescriptor_t valuesDesc, const void *values,
               const tecoalTensorDescriptor_t inputDesc, const void *input,
               const tecoalTensorDescriptor_t outputDesc, void *output, tecoalAlgo_t algo) {
    auto indexDesc = indicesDesc[0];
    int *dim_index = indexDesc->dimA;
    int *dim_value = valuesDesc->dimA;
    int dim_ln_value = valuesDesc->nbDims;

    int dim_ln_index = indexDesc->nbDims;
    int dim_ln = outputDesc->nbDims;
    auto output_type = outputDesc->dataType;

    IndexPutArgs arg;
    arg.spe_cnt = handle->spe_num;
    arg.sz_type = Convert::toDescDataTypeSize(output_type);
    arg.list_length = indices_length;

    arg.broadcast_indice = 0;
    arg.broadcast_value = 0;

    int flag = 0, cnt_ = 0;
    for (int i = 0; i < dim_ln_value; i++) {
        if (dim_value[i] == 1) {
            flag++;
            if (i == dim_ln_value - 1 && flag == dim_ln_value) {
                cnt_ = 1;
            }
        } else {
            cnt_ = 0;
            i = dim_ln_value;
        }
    }
    arg.one_nb_flag = cnt_;

    if (indexDesc->dataType == TECOAL_DATA_INT64) {
        int cnt = 0;
        for (int i = 0; i < arg.list_length; i++) {
            int *dim_index_bct = indicesDesc[i]->dimA;
            if (*dim_index_bct != 1) {
                dim_index = indicesDesc[i]->dimA;
                break;
            }
        }
        for (int i = 0; i < arg.list_length; i++) {
            int *dim_index_bct = indicesDesc[i]->dimA;
            arg.bro_indice[i] = *dim_index_bct == 1 && dim_index[0] != 1 ? 1 : 0;
            if (!cnt && arg.bro_indice[i]) {
                arg.broadcast_indice = 1;
                cnt++;
            }
        }

        int mid_ln = dim_ln - indices_length;
        arg.r_value_dim[0] = dim_index[0];
        int start_v, end_v, s_v, d_value;
        for (int d = 1; d < MAX_DIM; d++) {
            arg.r_value_dim[d] = d < mid_ln + 1 ? outputDesc->dimA[d + indices_length - 1] : 0;
        }

        if (dim_ln_value == mid_ln + 1) {
            end_v = mid_ln;
            start_v = -1;
            arg.broadcast_value = 0;
        } else {
            end_v = dim_ln_value - 1;
            start_v = -1;
            arg.broadcast_value = 1;
        }
        for (int v = end_v; v > start_v; v--) {
            s_v = dim_ln_value == mid_ln + 1 ? v : v + mid_ln - dim_ln_value + 1;
            ERROR_IF_NOT(dim_value[v] == 1 || dim_value[v] == arg.r_value_dim[s_v],
                         "value's dim[i] does not Conform to the Rules.\n"
                         "for example, if you want to get value[x][y][z],"
                         "you can give me a n-dims tensor(0<n<=3)"
                         " the tensor must be [x][y][z], [y][z] or [z]"
                         "and x, y, z may be equal to 1\n");
            if (dim_value[v] == 1 && dim_value[v] != arg.r_value_dim[s_v]) {
                arg.broadcast_value = 1;
            }
        }
        for (int d = 0; d < mid_ln + 1; d++) {
            if (dim_ln_value != mid_ln + 1) {
                d_value = d - mid_ln + dim_ln_value - 1;
                arg.bro_value[d] = d < mid_ln - dim_ln_value + 1 ?
                                       1 :
                                       (dim_value[d_value] == 1 && arg.r_value_dim[d] != 1 ? 1 : 0);
            } else {
                arg.bro_value[d] = dim_value[d] == 1 && arg.r_value_dim[d] != 1 ? 1 : 0;
            }
        }
    }

    arg.broadcast = arg.broadcast_indice || arg.broadcast_value;

    arg.dim_ln_index = dim_ln_index;
    arg.dim_ln = dim_ln;
    arg.indices = indices;
    arg.input = input;
    arg.value = values;
    arg.output = output;
    arg.accumulate = accumulate;
    arg.dim_ln_value = dim_ln_value;
    arg.TYPE_CODE = 1;  // BROADCAST_DATA_TYPE_HALF
    arg.FUNC_CODE = 0;  // BROADCAST_BINARY_OP_ADD

    arg.is_bool_index =
        indexDesc->dataType == TECOAL_DATA_BOOL || indexDesc->dataType == TECOAL_DATA_UINT8;

    int *dim_input = inputDesc->dimA;
    int *dim_output = outputDesc->dimA;

    memcpy(arg.dim_value, dim_value, sizeof(int) * dim_ln_value);
    memcpy(arg.dim_index, dim_index, sizeof(int) * dim_ln_index);
    memcpy(arg.dim_output, outputDesc->dimA, sizeof(int) * dim_ln);

    reverse_array(arg.dim_index, dim_ln_index);
    reverse_array(arg.dim_output, dim_ln);

    IndexPutPatchArgs patch_arg;
    patch_arg.arg = &arg;
    patch_arg.data_type = Convert::toUALDataType(valuesDesc->dataType);
    patch_arg.index_data_type = Convert::toUALDataType(indexDesc->dataType);
    patch_arg.algo = Convert::toUalAlgoType(algo);

    RUN_OP(IndexPutOp, arg, patch_arg, handle);
    return TECOAL_STATUS_SUCCESS;
}
