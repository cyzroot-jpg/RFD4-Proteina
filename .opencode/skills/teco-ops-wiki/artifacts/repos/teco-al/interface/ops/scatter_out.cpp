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

#include "interface/include/tecoal.h"
#include "interface/include/builtin_type.h"
#include "ual/args/scatter_out_args.h"
#include "interface/common/marco.h"
#include "ual/ops/scatter_out/scatter_out.hpp"

using tecoal::ual::ops::ScatterOutOp;
using tecoal::ual::args::ScatterOutArgs;
using tecoal::ual::args::ScatterOutPatchArgs;
using tecoal::Convert;

#define SWAP_TYPE(type, x, y) \
    do {                      \
        type t = x;           \
        x = y;                \
        y = t;                \
    } while (0)

static inline void REV(int *a, int ln) {
    int cnt = ln >> 1;
    for (int i = 0; i < cnt; ++i) {
        SWAP_TYPE(int, a[i], a[ln - 1 - i]);
    }
}

tecoalStatus_t TECOALWINAPI tecoalScatterOut(
    tecoalHandle_t handle, const unsigned int axis, const float alpha,
    const tecoalScatterOutInputType_t input_type, const tecoalScatterOutReductionMode_t reduce,
    const tecoalTensorDescriptor_t desc_input, const void *input,
    const tecoalTensorDescriptor_t desc_index, const void *index,
    const tecoalTensorDescriptor_t desc_output, void *output, tecoalAlgo_t algo) {
    // Initialize and fill the structure with tensor operation arguments
    ScatterOutArgs arg;
    arg.spe_cnt = handle->spe_num;

    int dim_ln = desc_input->nbDims;

    ERROR_IF_NOT(axis >= 0 && axis < dim_ln, "invalid axis\n");
    ERROR_IF_NOT(dim_ln == desc_index->nbDims && dim_ln == desc_output->nbDims,
                 "input's, output's, index's dim_ln must equal\n");
    ERROR_IF_NOT(dim_ln > 0, "dim_ln must > 0\n");

    arg.axis = dim_ln - 1 - axis;
    arg.dim_ln = dim_ln;

    int *dim_input = desc_input->dimA;
    int *dim_index = desc_index->dimA;
    int *dim_output = desc_output->dimA;
    // according to pytorch API, dim_ln must be same
    ERROR_IF(!dim_input || !dim_index || !dim_output, "dim NULL Pointer\n");

    memcpy(arg.dim_input, dim_input, sizeof(int) * dim_ln);
    memcpy(arg.dim_output, dim_output, sizeof(int) * dim_ln);
    memcpy(arg.dim_index, dim_index, sizeof(int) * dim_ln);

    REV(arg.dim_input, dim_ln);
    REV(arg.dim_output, dim_ln);
    REV(arg.dim_index, dim_ln);

    for (int i = 0; i < dim_ln; ++i) {
        ERROR_IF_NOT(dim_input[i] > 0, "assert: dim[i] > 0\n");
        ERROR_IF_NOT(dim_index[i] > 0, "assert: dim[i] > 0\n");
        ERROR_IF_NOT(dim_output[i] > 0, "assert: dim[i] > 0\n");
    }

    arg.input = (void *)input;
    arg.index = (int *)index;
    arg.output = (void *)output;

    arg.func_opcode = reduce;
    arg.is_scalar = input_type == TECOAL_SCATTEROUT_INPUT_SCALAR;
    arg.alpha = alpha;
    arg.data_type = Convert::toUALDataType(desc_input->dataType);

    ScatterOutPatchArgs patch_arg;
    patch_arg.args = &arg;
    patch_arg.data_type = Convert::toUALDataType(desc_input->dataType);
    patch_arg.algo = Convert::toUalAlgoType(algo);

    RUN_OP(ScatterOutOp, arg, patch_arg, handle);
    return TECOAL_STATUS_SUCCESS;
}
