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

#ifndef UAL_OPS_ARG_MAX_ARG_MAX_HPP_
#define UAL_OPS_ARG_MAX_ARG_MAX_HPP_

#include "ual/kernel/arg_max/arg_max.h"
#include "ual/com/log.h"
#include "ual/args/arg_max_args.h"
#include "ual/com/def.h"
#include "ual/ops/base_op.hpp"
#include "ual/ops/arg_max/find_arg_max.h"

using tecoal::ual::args::ArgMaxArgs;
using tecoal::ual::args::ArgMaxPatchArgs;
using namespace tecoal::ual::common;
using namespace tecoal::ual::kernel;

namespace tecoal {
namespace ual {
namespace ops {

struct ArgMaxType {
    using ArgsType = ArgMaxArgs;        // using implement kernel args
    using PatchType = ArgMaxPatchArgs;  // using patch args
    using RetType = void;
    using PImplType = void (*)(ArgsType);
};

static ArgMaxType::PImplType ArgMaxAlgos[] = {
    tecoKernelArgmaxFT16,
    // more branches
};

static const char *ArgMaxDiscription[] = {
    "tecoKernelArgmaxFT16",
    // more branches
};

struct ArgMaxOp : public BaseOp<ArgMaxOp, ArgMaxType> {
 public:
    using ArgsType = typename ArgMaxType::ArgsType;    // using implement kernel args
    using PatchType = typename ArgMaxType::PatchType;  // using dispatch args
    using RetType = typename ArgMaxType::RetType;
    using PImplType = typename ArgMaxType::PImplType;

    static const char *name() { return "arg_max"; }

    Status findImpl(const PatchType *args) {
        ArgMaxBranch branch = findArgMaxBranch(args);
        if (branch == ArgMaxBranch::ARG_MAX_END) {
            ERROR("arg_max branch is not exit!");
            return Status::NOT_IMPLEMENTED;
        }
        int index = static_cast<int>(branch);
        setInstance(ArgMaxAlgos[index], ArgMaxDiscription[index]);
        return Status::SUCCESS;
    }
};
}  // namespace ops
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_OPS_ARG_MAX_ARG_MAX_HPP_
