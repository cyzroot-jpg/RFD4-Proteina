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
#include "ual/args/scatter_nd_add_args.h"
#include "interface/common/marco.h"
#include "ual/ops/scatter_nd_add/scatter_nd_add.hpp"

using tecoal::ual::ops::ScatterNdAddOp;
using tecoal::ual::args::ScatterNdAddArgs;
using tecoal::ual::args::ScatterNdAddPatchArgs;
using tecoal::Convert;

tecoalStatus_t TECOALWINAPI
tecoalScatterNdAdd(tecoalHandle_t handle, const tecoalTensorDescriptor_t xDesc, const void *x,
                   const tecoalTensorDescriptor_t indexDesc, const void *index,
                   const tecoalTensorDescriptor_t updatesDesc, const void *updates,
                   const tecoalTensorDescriptor_t outDesc, void *out, tecoalAlgo_t algo) {
    // define ops args
    ScatterNdAddArgs arg;
    int indexDims = indexDesc->nbDims;
    int index_last_dim = indexDesc->dimA[indexDims - 1];
    arg.spe_num = handle->spe_num;
    int dim_x0 = 1;
    for (int i = 0; i < index_last_dim; i++) {
        dim_x0 *= xDesc->dimA[i];
        arg.dim_x8[i] = xDesc->dimA[i];
    }
    arg.dim_x[0] = dim_x0;
    int dim_x1 = 1;
    for (int i = index_last_dim; i < xDesc->nbDims; i++) {
        dim_x1 *= xDesc->dimA[i];
    }
    arg.dim_x[1] = dim_x1;

    arg.dim_index[0] = 1;
    for (int i = 0; i < indexDesc->nbDims - 1; i++) {
        arg.dim_index[0] *= indexDesc->dimA[i];
    }
    arg.dim_index[1] = indexDesc->dimA[indexDims - 1];
    arg.dim_updates[0] = arg.dim_index[0];
    arg.dim_updates[1] = arg.dim_x[1];
    arg.x = x;
    arg.index = index;
    arg.updates = updates;
    arg.out = out;

    ScatterNdAddPatchArgs arg_patch;
    arg_patch.arg = &arg;
    arg_patch.x_data_type = Convert::toUALDataType(xDesc->dataType);
    arg_patch.index_data_type = Convert::toUALDataType(indexDesc->dataType);
    arg_patch.algo = Convert::toUalAlgoType(algo);
    RUN_OP(ScatterNdAddOp, arg, arg_patch, handle);
    return TECOAL_STATUS_SUCCESS;
}
