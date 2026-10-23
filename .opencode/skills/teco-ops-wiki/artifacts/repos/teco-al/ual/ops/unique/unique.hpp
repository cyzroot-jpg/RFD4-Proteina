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

#ifndef UAL_OPS_UNIQUE_UNIQUE_HPP_
#define UAL_OPS_UNIQUE_UNIQUE_HPP_

#include "ual/kernel/unique/unique.h"
#include "ual/com/log.h"
#include "ual/args/unique_args.h"
#include "ual/com/def.h"
#include "ual/ops/base_op.hpp"
#include "ual/ops/unique/find_unique.h"

using tecoal::ual::args::UniqueArgs;
using tecoal::ual::args::UniquePatchArgs;
using namespace tecoal::ual::common;
using namespace tecoal::ual::kernel;

namespace tecoal {
namespace ual {
namespace ops {

struct UniqueType {
    using ArgsType = UniqueArgs;        // using implement slave args
    using PatchType = UniquePatchArgs;  // using dispatch args
    using RetType = void;
    using PImplType = void (*)(ArgsType);
};

static UniqueType::PImplType UniqueAlgos[] = {
    tecoKernelUniqueSortedInt64,
    // more branches
};

static const char *UniqueDiscription[] = {
    "tecoKernelUniqueSortedInt64",
    // more branches
};

struct UniqueOp : public BaseOp<UniqueOp, UniqueType> {
 public:
    using ArgsType = typename UniqueType::ArgsType;    // using implement kernel args
    using PatchType = typename UniqueType::PatchType;  // using dispatch args
    using RetType = typename UniqueType::RetType;
    using PImplType = typename UniqueType::PImplType;

    static const char *name() { return "Unique"; }

    Status findImpl(const PatchType *args) {
        UniqueBranch branch = findUniqueBranch(args);
        if (branch == UniqueBranch::UNIQUE_END) {
            ERROR("unique branch is not exit!");
            return Status::NOT_IMPLEMENTED;
        }
        int index = static_cast<int>(branch);
        setInstance(UniqueAlgos[index], UniqueDiscription[index]);
        return Status::SUCCESS;
    }
};
}  // namespace ops
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_OPS_UNIQUE_UNIQUE_HPP_
