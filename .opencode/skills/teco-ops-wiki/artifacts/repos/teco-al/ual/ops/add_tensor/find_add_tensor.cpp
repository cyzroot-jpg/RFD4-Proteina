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

#include "ual/ops/add_tensor/find_add_tensor.h"
#include "ual/com/convert.hpp"

using tecoal::ual::args::AddTensorArgs;
using tecoal::ual::args::AddTensorPatchArgs;

namespace tecoal {
namespace ual {
namespace ops {

// Define a function to determine the best algorithm branch for adding tensors based on given
// arguments.
int findAddTensorBranch(const AddTensorPatchArgs *arg) {
    // Convert the algorithm type from the arguments to an index for internal use.
    int algo = common::convertAlgoToIndex(arg->algo);

    // Check if the product of 'n' and 'hw' dimensions for tensors A and C are equal.
    if (arg->atargs->a_n_num * arg->atargs->a_hw_num ==
        arg->atargs->c_n_num * arg->atargs->c_hw_num) {
        // If the data type is half-precision floating-point (FP16),
        // and the total number of elements (n * hw * c) in tensor A is even,
        if (arg->data_type == UALDataType::UAL_DTYPE_HALF &&
            (arg->atargs->a_n_num * arg->atargs->a_hw_num * arg->atargs->a_c_num) % 2 == 0) {
            // An optimal kernel for half-precision addition is selected.
            return algo;
        }
    }
    // If none of the above conditions are met, return -1 indicating no specialized branch was
    // found.
    return -1;
}

}  // namespace ops
}  // namespace ual
}  // namespace tecoal
