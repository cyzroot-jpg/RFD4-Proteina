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

#include "interface/include/builtin_type.h"
#include "interface/common/check.h"
#include "ual/ops/gemm/gemm.hpp"
#include "interface/common/marco.h"

using tecoal::ual::args::GEMMArgs;
using tecoal::ual::args::GEMMPatchArgs;
using tecoal::ual::ops::GEMMOp;
using tecoal::Convert;

tecoalStatus_t TECOALWINAPI tecoalHgemm(tecoalHandle_t handle, tecoalOperation_t transa,
                                        tecoalOperation_t transb, int m, int n, int k, float alpha,
                                        const void *A, int lda, const void *B, int ldb, float beta,
                                        void *C, int ldc, tecoalAlgo_t algo) {
    // Initialize and fill the structure with tensor operation arguments
    GEMMArgs args;
    args.m = m;
    args.n = n;
    args.k = k;
    args.lda = lda;
    args.ldb = ldb;
    args.ldc = ldc;
    args.alpha = alpha;
    args.beta = beta;
    args.batch = 1;
    args.A = A;
    args.B = B;
    args.C = C;
    args.Atype = UALDataType::UAL_DTYPE_HALF;
    args.Btype = UALDataType::UAL_DTYPE_HALF;
    args.Ctype = UALDataType::UAL_DTYPE_HALF;

    // Initialize patch arguments structure for additional configurations
    GEMMPatchArgs patch_args;
    patch_args.gemm_args = &args;
    patch_args.transa = Convert::toUALOperation(transa);
    patch_args.transb = Convert::toUALOperation(transb);
    patch_args.algo = Convert::toUalAlgoType(algo);

    // Execute GEMM operation
    RUN_OP(GEMMOp, args, patch_args, handle);
    return TECOAL_STATUS_SUCCESS;
}
