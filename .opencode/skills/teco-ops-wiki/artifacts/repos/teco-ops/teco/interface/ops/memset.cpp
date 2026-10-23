// BSD 3-Clause License
//
// Copyright (c) 2024, Tecorigin Co., Ltd.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include "ual/ops/memset/memset.hpp"
#include "interface/common/convert.h"
#include "interface/common/macro.h"
#include "interface/include/builtin_type.h"
#include "interface/include/tecoops.h"
#include "ual/args/memset_args.h"

using tecoops::Convert;
using tecoops::ual::args::MemsetArgs;
using tecoops::ual::ops::MemsetOp;

static tecoopsStatus_t checkMemsetInput(tecoopsHandle_t handle, void* x, const int value,
                                        size_t size) {
    if (handle == NULL) {
        return TECOOPS_STATUS_BAD_PARAM;
    }
    if (x == NULL) {
        return TECOOPS_STATUS_BAD_PARAM;
    }
    return TECOOPS_STATUS_SUCCESS;
}

tecoopsStatus_t tecoopsMemset(tecoopsHandle_t handle, void* x, const int value, size_t size) {
    // check input
    tecoopsStatus_t input_error = checkMemsetInput(handle, x, value, size);
    if (input_error != TECOOPS_STATUS_SUCCESS)
        return input_error;

    MemsetArgs mem_arg;

    mem_arg.spe_num = handle->spe_num;
    mem_arg.data_size = size;
    mem_arg.value = value;
    mem_arg.x = x;

    RUN_OP(MemsetOp, mem_arg, mem_arg, handle);
    return TECOOPS_STATUS_SUCCESS;
}
