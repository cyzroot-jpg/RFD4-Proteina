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

#include "ual/ops/gemm/find_gemm.h"
#include "ual/com/convert.hpp"

using tecoal::ual::args::GEMMArgs;
using tecoal::ual::args::GEMMPatchArgs;

namespace tecoal {
namespace ual {
namespace ops {

#define MaxHM 512  // 128*4
#define MinHM 64   // 16*4
#define MaxHK 256  // 256*8
#define MinHK 32   // 32*8
#define MaxHN 512  // 64*8
#define MinHN 256  // 32*8

struct PaddingData {
    int bM;
    int bN;
    int bK;
    int Mend;
    int Nend;
    int Kend;
    bool compa;
    bool compb;
    bool compc;
};

static inline void getGEMMBlockHgemmN512(const int M, const int N, const int K, const int maxM,
                                         const int minM, const int maxN, const int minN,
                                         const int maxK, const int minK, int *bM, int *bN,
                                         int *bK) {
    int im, ik, in;
    for (ik = maxK; ik > minK; ik -= minK) {
        if (K % ik == 0) break;
    }
    *bK = ik;

    for (in = maxN; in > minN; in -= minN) {
        if (N % in == 0) break;
    }
    *bN = in;

    for (im = maxM; im > minM; im -= minM) {
        if (M % im == 0) break;
    }
    *bM = im;
    if (*bN == 512 && *bM > 256) *bM = 256;  // 64*4
}

static inline PaddingData paddingStrategy(const GEMMPatchArgs *arg) {
    const GEMMArgs *gemmArgs = arg->gemm_args;
    int bM, bN, bK;
    int M = gemmArgs->m;
    int N = gemmArgs->n;
    int K = gemmArgs->k;
    int lda = gemmArgs->lda;
    int ldb = gemmArgs->ldb;
    int ldc = gemmArgs->ldc;

    getGEMMBlockHgemmN512(M, N, K, MaxHM, MinHM, MaxHN, MinHN, MaxHK, MinHK, &bM, &bN, &bK);

    if (bM < 256) bM = 256;
    int Mend = ((M + bM - 1) / bM) * bM;
    int Nend = ((N + bN - 1) / bN) * bN;
    int Kend = ((K + bK - 1) / bK) * bK;

    int flag_M = (Mend > M);
    int flag_N = (Nend > N) || (ldb > N) || (ldc > N);
    int flag_K = (Kend > K) || (lda > K);

    bool compa = flag_M || flag_K;
    bool compb = flag_K || flag_N;
    bool compc = flag_M || flag_N;

    return {bM, bN, bK, Mend, Nend, Kend, compa, compb, compc};
}

size_t findGEMMWorksapceSize(const GEMMPatchArgs *arg) { return 0; }

// Define a function to find the best GEMM branch based on given arguments.
int findGEMMBranch(const GEMMPatchArgs *arg) {
    // Determine padding requirements for the operation.
    PaddingData pad = paddingStrategy(arg);

    // Convert the algorithm type from the arguments to an index for internal use.
    int algo = common::convertAlgoToIndex(arg->algo);

    // Extract transpose operations for matrices A and B from the arguments.
    UALOperation transa = arg->transa;
    UALOperation transb = arg->transb;

    // Pointer to the GEMM operation arguments.
    const GEMMArgs *gemmArgs = arg->gemm_args;

    // Data types for matrices A, B, and C.
    UALDataType Atype = gemmArgs->Atype;
    UALDataType Btype = gemmArgs->Btype;
    UALDataType Ctype = gemmArgs->Ctype;

    // Scaling factors for the matrix multiplication and addition.
    float alpha = gemmArgs->alpha;
    float beta = gemmArgs->beta;

    // Dimensions of the matrices involved in the GEMM operation.
    int M = gemmArgs->m;
    int N = gemmArgs->n;
    int K = gemmArgs->k;

    // Check if matrices A and B are of half-precision type and operations on A and B are not
    // transposed.
    if (Atype == UALDataType::UAL_DTYPE_HALF && Btype == UALDataType::UAL_DTYPE_HALF &&
        transa == UALOperation::UAL_OP_N && transb == UALOperation::UAL_OP_N) {
        // Further conditions for optimization: dimensions are multiples of 256 and scaling factors
        // are close to default values (1 for alpha, 0 for beta).
        if (M % 256 == 0 && N % 256 == 0 && K % 256 == 0 && fabs(alpha - 1) <= 1e-6 &&
            fabs(beta) <= 1e-6) {
            // Ensure no padding compensation is needed for matrices A, B, and C to use this
            // optimization.
            if (!pad.compa && !pad.compb && !pad.compc) {
                // Update block dimensions based on padding strategy.
                arg->gemm_args->bM = pad.bM;
                arg->gemm_args->bN = pad.bN;
                arg->gemm_args->bK = pad.bK;
                // Return the algorithm index if all conditions are met for this optimized branch.
                return algo;
            }
        }
    }
    // Return -1 if no suitable optimized branch was found for the GEMM operation.
    return -1;
}

}  // namespace ops
}  // namespace ual
}  // namespace tecoal
