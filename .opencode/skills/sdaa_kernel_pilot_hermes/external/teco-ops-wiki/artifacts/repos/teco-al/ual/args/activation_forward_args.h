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

#ifndef UAL_ARGS_ACTIVATION_FORWARD_ARGS_H_
#define UAL_ARGS_ACTIVATION_FORWARD_ARGS_H_

#include "ual/com/def.h"

using namespace tecoal::ual::common;

namespace tecoal {
namespace ual {
namespace args {

typedef struct ActivationFwdArgs {
    int spe_num;
    int spa_num;

    int data_num;
    int mode;
    double coef;
    const void *x;
    void *y;
    void *table_a;
    void *table_b;

    float alpha;
    float beta;
} ActivationFwdArgs;

typedef struct ActivationFwdPatchArgs {
    ActivationFwdArgs *afarg;
    UALDataType data_type;
    void *tab_A;
    void *tab_B;
    UALAlgoType algo;
} ActivationFwdPatchArgs;

}  // namespace args
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_ARGS_ACTIVATION_FORWARD_ARGS_H_
