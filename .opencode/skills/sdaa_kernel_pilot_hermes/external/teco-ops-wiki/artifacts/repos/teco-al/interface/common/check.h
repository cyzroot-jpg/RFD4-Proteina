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

#ifndef INTERFACE_COMMON_CHECK_H_
#define INTERFACE_COMMON_CHECK_H_

#include <cstdio>
#include "interface/common/convert.h"
#include "interface/include/tecoal.h"

namespace tecoal {

#define checkUalStatus(a)                                                                   \
    do {                                                                                    \
        Status __status = a;                                                                \
        if (Status::SUCCESS != (__status)) {                                                \
            fprintf(stderr, "tecoal runtime error in line %d of file %s : %s \n", __LINE__, \
                    __FILE__, toStatusStr(__status));                                       \
            return __status;                                                                \
        }                                                                                   \
    } while (0);

#define checkUalStatusInTecoal(a)                                                            \
    do {                                                                                     \
        Status __status = a;                                                                 \
        if (Status::SUCCESS != (__status)) {                                                 \
            fprintf(stderr, "tecoual runtime error in line %d of file %s : %s \n", __LINE__, \
                    __FILE__, Convert::toStatusStr(__status));                               \
            return Convert::toStatus(__status);                                              \
        }                                                                                    \
    } while (0);

#define checkTecoalStatus(status)                                                   \
    do {                                                                            \
        tecoalStatus_t __errcode = status;                                          \
        if (__errcode != TECOAL_STATUS_SUCCESS) {                                   \
            fprintf(stderr, "TECOAL Error: %s\n", tecoalGetErrorString(__errcode)); \
            return __errcode;                                                       \
        }                                                                           \
    } while (0);

}  // namespace tecoal

#endif  // INTERFACE_COMMON_CHECK_H_
