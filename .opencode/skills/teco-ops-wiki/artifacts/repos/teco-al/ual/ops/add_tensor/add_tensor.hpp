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

#ifndef UAL_OPS_ADD_TENSOR_ADD_TENSOR_HPP_
#define UAL_OPS_ADD_TENSOR_ADD_TENSOR_HPP_

#include "ual/kernel/add_tensor/add_tensor.h"
#include "ual/com/log.h"
#include "ual/args/add_tensor_args.h"
#include "ual/com/def.h"
#include "ual/ops/base_op.hpp"
#include "ual/ops/add_tensor/find_add_tensor.h"

using tecoal::ual::args::AddTensorArgs;
using tecoal::ual::args::AddTensorPatchArgs;
using namespace tecoal::ual::common;
using namespace tecoal::ual::kernel;

namespace tecoal {
namespace ual {
namespace ops {

struct AddTensorType {
    using ArgsType = AddTensorArgs;        // using implement kernel args
    using PatchType = AddTensorPatchArgs;  // using patch args
    using RetType = void;
    using PImplType = void (*)(ArgsType);
};

static AddTensorType::PImplType AddTensorAlgos[] = {
    tecoKernelAddTensorHalfSingleThread, tecoKernelAddTensorHalfMultiThreads,
    tecoKernelAddTensorHalfDMA,          tecoKernelAddTensorHalfSIMD,
    tecoKernelAddTensorHalfUnroll,       tecoKernelAddTensorHalfDoubleBuffer,
    // more branches
};

static const char *AddTensorDiscription[] = {
    "tecoKernelAddTensorHalfSingleThread", "tecoKernelAddTensorHalfMultiThreads",
    "tecoKernelAddTensorHalfDMA",          "tecoKernelAddTensorHalfSIMD",
    "tecoKernelAddTensorHalfUnroll",       "tecoKernelAddTensorHalfDoubleBuffer",
    // more branches
};

struct AddTensorOp : public BaseOp<AddTensorOp, AddTensorType> {
 public:
    using ArgsType = typename AddTensorType::ArgsType;    // using implement kernel args
    using PatchType = typename AddTensorType::PatchType;  // using dispatch args
    using RetType = typename AddTensorType::RetType;
    using PImplType = typename AddTensorType::PImplType;

    static const char *name() { return "add_tensor"; }

    Status findImpl(const PatchType *args) {
        int index = findAddTensorBranch(args);
        if (index == -1) {
            ERROR("add_tensor branch is not exit!");
            return Status::NOT_IMPLEMENTED;
        }
        setInstance(AddTensorAlgos[index], AddTensorDiscription[index]);
        return Status::SUCCESS;
    }
};
}  // namespace ops
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_OPS_ADD_TENSOR_ADD_TENSOR_HPP_
