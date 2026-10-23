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

#ifndef UAL_OPS_UNARY_OPS_UNARY_OPS_HPP_
#define UAL_OPS_UNARY_OPS_UNARY_OPS_HPP_

#include "ual/kernel/unary_ops/unary_ops.h"
#include "ual/com/log.h"
#include "ual/args/unary_ops_args.h"
#include "ual/com/def.h"
#include "ual/ops/base_op.hpp"
#include "ual/ops/unary_ops/find_unary_ops.h"

using tecoal::ual::args::UnaryOpsArgs;
using tecoal::ual::args::UnaryOpsPatchArgs;
using namespace tecoal::ual::common;
using namespace tecoal::ual::kernel;

namespace tecoal {
namespace ual {
namespace ops {

struct UnaryOpsType {
    using ArgsType = UnaryOpsArgs;        // using implement slave args
    using PatchType = UnaryOpsPatchArgs;  // using dispatch args
    using RetType = void;
    using PImplType = void (*)(ArgsType);
};

static UnaryOpsType::PImplType UnaryOpsAlgos[] = {
    tecoKernelUnaryOpsWithAlphaFT32,
    // more branches
};

static const char *UnaryOpsDiscription[] = {
    "tecoKernelUnaryOpsWithAlphaFT32",
    // more branches
};

struct UnaryOpsOp : public BaseOp<UnaryOpsOp, UnaryOpsType> {
 public:
    using ArgsType = typename UnaryOpsType::ArgsType;    // using implement kernel args
    using PatchType = typename UnaryOpsType::PatchType;  // using dispatch args
    using RetType = typename UnaryOpsType::RetType;
    using PImplType = typename UnaryOpsType::PImplType;

    static const char *name() { return "UnaryOps"; }

    Status findImpl(const PatchType *args) {
        UnaryOpsBranch branch = findUnaryOpsBranch(args);
        if (branch == UnaryOpsBranch::UNARY_OPS_END) {
            ERROR("unary_ops branch is not exit!");
            return Status::NOT_IMPLEMENTED;
        }
        int index = static_cast<int>(branch);
        setInstance(UnaryOpsAlgos[index], UnaryOpsDiscription[index]);
        return Status::SUCCESS;
    }
};
}  // namespace ops
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_OPS_UNARY_OPS_UNARY_OPS_HPP_
