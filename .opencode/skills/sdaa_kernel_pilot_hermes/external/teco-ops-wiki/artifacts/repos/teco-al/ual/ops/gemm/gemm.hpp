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

#ifndef UAL_OPS_GEMM_GEMM_HPP_
#define UAL_OPS_GEMM_GEMM_HPP_

#include "ual/kernel/gemm/gemm.h"
#include "ual/com/log.h"
#include "ual/args/gemm_args.h"
#include "ual/com/def.h"
#include "ual/ops/base_op.hpp"
#include "ual/ops/gemm/find_gemm.h"

using tecoal::ual::args::GEMMArgs;
using tecoal::ual::args::GEMMPatchArgs;
using namespace tecoal::ual::common;
using namespace tecoal::ual::kernel;

namespace tecoal {
namespace ual {
namespace ops {

struct GEMMType {
    using ArgsType = GEMMArgs;        // using implement kernel args
    using PatchType = GEMMPatchArgs;  // using patch args
    using RetType = void;
    using PImplType = void (*)(ArgsType);
};

// Array of pointers to different implementations of the GEMM operation,
// ordered by increasing performance optimization.
static GEMMType::PImplType GEMMAlgos[] = {
    // Basic GEMM implementation optimized for single core usage
    tecoKernelGemmFT16SingleThread,

    // Enhanced GEMM implementation for multi-core processors, leveraging parallelism.
    tecoKernelGemmFT16MultiThreads,

    // GEMM implementation utilizing Direct Memory Access (DMA) for faster data transfer
    tecoKernelGemmFT16DMA,

    // SIMD (Single Instruction, Multiple Data) optimized GEMM, leveraging vector processing
    // capabilities for higher throughput.
    tecoKernelGemmFT16SIMD,

    // Advanced GEMM implementation using SDAAC matmul API
    tecoKernelGemmFT16Matmul,

    // Optimizes GEMM by employing broadcast mechanisms to efficiently distribute data across
    // processing units.
    tecoKernelGemmFT16Broadcast,

    // Implements double buffering in GEMM operations, allowing for computation and data transfer to
    // overlap
    tecoKernelGemmFT16DoubleBuffer,
};

static const char *GEMMDiscription[] = {
    "tecoKernelGemmFT16SingleThread", "tecoKernelGemmFT16MultiThreads",
    "tecoKernelGemmFT16DMA",          "tecoKernelGemmFT16SIMD",
    "tecoKernelGemmFT16Matmul",       "tecoKernelGemmFT16Broadcast",
    "tecoKernelGemmFT16DoubleBuffer"};

struct GEMMOp : public BaseOp<GEMMOp, GEMMType> {
 public:
    using ArgsType = typename GEMMType::ArgsType;    // using implement kernel args
    using PatchType = typename GEMMType::PatchType;  // using dispatch args
    using RetType = typename GEMMType::RetType;
    using PImplType = typename GEMMType::PImplType;

    static const char *name() { return "gemm"; }

    Status findImpl(const PatchType *args) {
        int index = findGEMMBranch(args);
        if (index == -1) {
            ERROR("gemm branch is not exit!");
            return Status::NOT_IMPLEMENTED;
        }
        setInstance(GEMMAlgos[index], GEMMDiscription[index]);
        return Status::SUCCESS;
    }
};
}  // namespace ops
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_OPS_GEMM_GEMM_HPP_
