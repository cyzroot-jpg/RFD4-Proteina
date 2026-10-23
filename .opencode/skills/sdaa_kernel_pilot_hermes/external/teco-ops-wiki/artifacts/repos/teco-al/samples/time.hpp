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

#ifndef SAMPLES_TIME_HPP_
#define SAMPLES_TIME_HPP_

#include <chrono>

struct TimeRecorder {
    using TimeStamp = std::chrono::high_resolution_clock::time_point;
    static TimeStamp now() { return std::chrono::high_resolution_clock::now(); }

    static int32_t nowMilliseconds() {
        return std::chrono::duration_cast<std::chrono::milliseconds>(now().time_since_epoch())
                   .count() %
               1000;
    }

    static int32_t nowMicroseconds() {
        return std::chrono::duration_cast<std::chrono::microseconds>(now().time_since_epoch())
                   .count() %
               1000000;
    }

    static long long duration(const TimeStamp &start, const TimeStamp &end) {
        return std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
    }
};

#endif  // SAMPLES_TIME_HPP_
