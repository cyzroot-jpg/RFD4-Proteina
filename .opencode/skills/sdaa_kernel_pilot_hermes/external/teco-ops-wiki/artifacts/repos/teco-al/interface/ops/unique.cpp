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
#include "ual/args/unique_args.h"
#include "interface/common/marco.h"
#include "ual/ops/unique/unique.hpp"

using tecoal::ual::ops::UniqueOp;
using tecoal::ual::args::UniqueArgs;
using tecoal::ual::args::UniquePatchArgs;
using tecoal::Convert;

tecoalStatus_t TECOALWINAPI tecoalUnique(tecoalHandle_t handle, tecoalUniqueMode_t mode, int axis,
                                         bool sorted, bool return_inverse, bool return_counts,
                                         const tecoalTensorDescriptor_t inputDesc,
                                         const void *input,
                                         const tecoalTensorDescriptor_t outputDesc, void *output,
                                         const tecoalTensorDescriptor_t inverseDesc, void *inverse,
                                         const tecoalTensorDescriptor_t countsDesc, void *counts,
                                         void *out_size, tecoalAlgo_t algo) {
    // Initialize and fill the structure with tensor operation arguments
    UniqueArgs arg;
    arg.spe_num = handle->spe_num;
    arg.x = (void *)input;
    arg.y = (void *)output;
    arg.inverse = (void *)inverse;
    arg.counts = (void *)counts;
    arg.sorted = sorted;
    arg.return_inverse = return_inverse;
    arg.return_counts = return_counts;
    arg.out_size = (void *)out_size;
    int ndimsA = inputDesc->nbDims;
    arg.data_len = 1;
    for (int i = 0; i < ndimsA; i++) {
        arg.data_len *= inputDesc->dimA[i];
    }

    // Initialize patch arguments structure for additional configurations
    UniquePatchArgs patch_arg;
    patch_arg.args = &arg;
    patch_arg.data_type = Convert::toUALDataType(inputDesc->dataType);
    patch_arg.algo = Convert::toUalAlgoType(algo);

    RUN_OP(UniqueOp, arg, patch_arg, handle);
    return TECOAL_STATUS_SUCCESS;
}
