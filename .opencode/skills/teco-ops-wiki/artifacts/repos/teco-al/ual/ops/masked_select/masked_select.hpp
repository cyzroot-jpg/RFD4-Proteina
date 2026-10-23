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

#ifndef UAL_OPS_MASKED_SELECT_MASKED_SELECT_HPP_
#define UAL_OPS_MASKED_SELECT_MASKED_SELECT_HPP_

#include "ual/kernel/masked_select/masked_select.h"
#include "ual/com/log.h"
#include "ual/args/masked_select_args.h"
#include "ual/com/def.h"
#include "ual/ops/base_op.hpp"
#include "ual/ops/masked_select/find_masked_select.h"

using tecoal::ual::args::MaskedSelectArgs;
using tecoal::ual::args::MaskedSelectPatchArgs;
using namespace tecoal::ual::common;
using namespace tecoal::ual::kernel;

namespace tecoal {
namespace ual {
namespace ops {

struct MaskedSelectType {
    using ArgsType = MaskedSelectArgs;        // using implement kernel args
    using PatchType = MaskedSelectPatchArgs;  // using patch args
    using RetType = void;
    using PImplType = void (*)(ArgsType);
};

static MaskedSelectType::PImplType MaskedSelectAlgos[] = {
    tecoKernelMaskedSelectNobroadcast<int32_t, uint8_t>,
    // more branches
};

static const char *MaskedSelectDiscription[] = {
    "tecoKernelMaskedSelectNobroadcast<int32_t, uint8_t>",
    // more branches
};

struct MaskedSelectOp : public BaseOp<MaskedSelectOp, MaskedSelectType> {
 public:
    using ArgsType = typename MaskedSelectType::ArgsType;    // using implement kernel args
    using PatchType = typename MaskedSelectType::PatchType;  // using dispatch args
    using RetType = typename MaskedSelectType::RetType;
    using PImplType = typename MaskedSelectType::PImplType;

    static const char *name() { return "masked_select"; }

    Status findImpl(const PatchType *args) {
        MaskedSelectBranch branch = findMaskedSelectBranch(args);
        if (branch == MaskedSelectBranch::MASKED_SELECT_END) {
            ERROR("masked_select branch is not exit!");
            return Status::NOT_IMPLEMENTED;
        }
        int index = static_cast<int>(branch);
        setInstance(MaskedSelectAlgos[index], MaskedSelectDiscription[index]);
        return Status::SUCCESS;
    }
};
}  // namespace ops
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_OPS_MASKED_SELECT_MASKED_SELECT_HPP_
