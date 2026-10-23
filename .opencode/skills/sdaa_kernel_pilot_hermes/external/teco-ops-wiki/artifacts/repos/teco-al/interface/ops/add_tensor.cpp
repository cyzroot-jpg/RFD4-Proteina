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
#include "ual/args/add_tensor_args.h"
#include "interface/common/marco.h"
#include "ual/ops/add_tensor/add_tensor.hpp"

using tecoal::ual::ops::AddTensorOp;
using tecoal::ual::args::AddTensorArgs;
using tecoal::ual::args::AddTensorPatchArgs;
using tecoal::Convert;

tecoalStatus_t TECOALWINAPI tecoalAddTensor(tecoalHandle_t handle, const void *alpha,
                                            const tecoalTensorDescriptor_t aDesc, const void *A,
                                            const void *beta, const tecoalTensorDescriptor_t cDesc,
                                            void *C, tecoalAlgo_t algo) {
    // Initialize and fill the structure with tensor operation arguments
    AddTensorArgs arg;
    arg.spe_num = handle->spe_num;
    arg.a_n_num = aDesc->n;
    arg.c_n_num = cDesc->n;
    arg.a_c_num = aDesc->c;
    arg.a_hw_num = aDesc->h * aDesc->w;
    arg.c_hw_num = cDesc->h * cDesc->w;
    arg.format = cDesc->format;
    arg.alpha = *reinterpret_cast<const float *>(alpha);
    arg.beta = *reinterpret_cast<const float *>(beta);
    arg.A = A;
    arg.C = C;

    // Initialize patch arguments structure for additional configurations
    AddTensorPatchArgs patch_arg;
    patch_arg.atargs = &arg;
    patch_arg.algo = Convert::toUalAlgoType(algo);
    patch_arg.data_type = Convert::toUALDataType(aDesc->dataType);

    // Execute the tensor addition operation
    RUN_OP(AddTensorOp, arg, patch_arg, handle);
    return TECOAL_STATUS_SUCCESS;
}
