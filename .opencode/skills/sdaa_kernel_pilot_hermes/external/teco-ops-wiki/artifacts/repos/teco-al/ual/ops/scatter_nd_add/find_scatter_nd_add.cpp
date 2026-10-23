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

#include "ual/ops/scatter_nd_add/find_scatter_nd_add.h"
#include "ual/com/convert.hpp"

using tecoal::ual::args::ScatterNdAddArgs;
using tecoal::ual::args::ScatterNdAddPatchArgs;

namespace tecoal {
namespace ual {
namespace ops {

// Define a function to determine the best algorithm branch based on given arguments.
ScatterNdAddBranch findScatterNdAddBranch(const ScatterNdAddPatchArgs *arg) {
    if (arg->x_data_type == UALDataType::UAL_DTYPE_FLOAT) {
        if (arg->algo == UALAlgoType::UAL_ALGO_0) {
            return ScatterNdAddBranch::SCATTER_ND_ADD_INDEX_INT32_FLOAT;
        }
    } else if (arg->x_data_type == UALDataType::UAL_DTYPE_HALF) {
        if (arg->algo == UALAlgoType::UAL_ALGO_0) {
            return ScatterNdAddBranch::SCATTER_ND_ADD_INDEX_INT32_HALF;
        }
    } else if (arg->x_data_type == UALDataType::UAL_DTYPE_INT32) {
        if (arg->algo == UALAlgoType::UAL_ALGO_0) {
            return ScatterNdAddBranch::SCATTER_ND_ADD_INDEX_INT32_INT32;
        }
    } else if (arg->x_data_type == UALDataType::UAL_DTYPE_DOUBLE) {
        if (arg->algo == UALAlgoType::UAL_ALGO_0) {
            return ScatterNdAddBranch::SCATTER_ND_ADD_INDEX_INT32_DOUBLE;
        }
    } else if (arg->x_data_type == UALDataType::UAL_DTYPE_INT64) {
        if (arg->algo == UALAlgoType::UAL_ALGO_0) {
            return ScatterNdAddBranch::SCATTER_ND_ADD_INDEX_INT32_INT64;
        }
    }

    // If none of the above conditions are met, indicating no specialized branch was found.
    return ScatterNdAddBranch::SCATTER_ND_ADD_END;
}

}  // namespace ops
}  // namespace ual
}  // namespace tecoal
