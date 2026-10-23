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

#ifndef INTERFACE_COMMON_CONVERT_H_
#define INTERFACE_COMMON_CONVERT_H_

#include "interface/include/tecoal.h"
#include "ual/com/def.h"

using namespace tecoal::ual::common;

namespace tecoal {
class Convert {
 public:
    static tecoalStatus_t toStatus(const Status status);
    static const char *toStatusStr(const Status status);
    static const char *toDataTypeStr(const tecoalDataType_t dataType);
    static UALDataType toUALDataType(const tecoalDataType_t data_type);
    static UALOperation toUALOperation(const tecoalOperation_t trans_type);
    static UALAlgoType toUalAlgoType(const tecoalAlgo_t algo);
    static unsigned int toDescDataTypeSize(const tecoalDataType_t data_type);
    // unary ops
    static UALUnaryOpsMode toUALUnaryOpsMode(const tecoalUnaryOpsMode_t mode);
};
}  // namespace tecoal

#endif  // INTERFACE_COMMON_CONVERT_H_
