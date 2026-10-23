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

#ifndef UAL_OPS_CONV_FORWARD_CONV_FORWARD_HPP_
#define UAL_OPS_CONV_FORWARD_CONV_FORWARD_HPP_

#include "ual/kernel/conv_forward/conv_forward.h"
#include "ual/com/log.h"
#include "ual/args/conv_args.h"
#include "ual/ops/base_op.hpp"
#include "ual/ops/conv_forward/find_conv_forward.h"

using tecoal::ual::args::ConvFwdArgs;
using tecoal::ual::args::ConvFwdPatchArgs;
using namespace tecoal::ual::kernel;

namespace tecoal {
namespace ual {
namespace ops {

enum ConvType : uint16_t {};

struct ConvFType {
    using ArgsType = ConvFwdArgs;
    using PatchType = ConvFwdPatchArgs;
    using RetType = void;
    using PImplType = void (*)(ArgsType);
    using AlgoType = ConvType;
};

static ConvFType::PImplType ConvFwdAlgos[] = {
    // Single-core implementation of forward convolution
    tecoKernelConvFwdFT16SingleThread,

    // Multi-core implementation of forward convolution
    tecoKernelConvFwdFT16MultiThreads,

    // Utilizes DMA for efficient data transfer
    tecoKernelConvFwdFT16DMA,

    // Employs SIMD instructions for FP16 convolution
    tecoKernelConvFwdFT16SIMD,

    // Specialized SDAAC matmul API for FP16 convolution
    tecoKernelConvFwdFT16Matmul,

    // Broadcast technique to enhance data reuse and reduce memory accesses
    tecoKernelConvFwdFT16Broadcast,

    // Double buffering technique, allowing overlapping of computation and data transfer
    tecoKernelConvFwdFT16DoubleBuffer,

    // Baseline for competition
    tecoKernelConvFwdNodilationBaseline,
};

static const char *convFwdDiscription[] = {
    "tecoKernelConvFwdFT16SingleThread", "tecoKernelConvFwdFT16MultiThreads",
    "tecoKernelConvFwdFT16DMA",          "tecoKernelConvFwdFT16SIMD",
    "tecoKernelConvFwdFT16Matmul",       "tecoKernelConvFwdFT16Broadcast",
    "tecoKernelConvFwdFT16DoubleBuffer", "tecoKernelConvFwdNodilationBaseline"};

struct ConvFwdOp : public BaseOp<ConvFwdOp, ConvFType> {
 public:
    using ArgsType = typename ConvFType::ArgsType;
    using PatchType = typename ConvFType::PatchType;
    using RetType = typename ConvFType::RetType;
    using PImplType = typename ConvFType::PImplType;
    using AlgoType = typename ConvFType::AlgoType;

    static const char *name() { return "Conv forward"; }

    Status getWorkspace(const PatchType *args, size_t *size) {
        *size = findConvForwardWorkspace(args);
        return Status::SUCCESS;
    }

    Status findImpl(const PatchType *args) {
        ConvFwdBranch branch = findConvForwardBranch(args);
        if (branch == ConvFwdBranch::CONV_FWD_END) {
            ERROR("conv_forward branch is not exit!");
            return Status::NOT_IMPLEMENTED;
        }
        int index = static_cast<int>(branch);
        setInstance(ConvFwdAlgos[index], convFwdDiscription[index]);
        return Status::SUCCESS;
    }
};
}  // namespace ops
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_OPS_CONV_FORWARD_CONV_FORWARD_HPP_
