// MIT License
// 
// Copyright (c) 2024, Tecorigin Co., Ltd.
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
 
#ifndef DEVICE_DEVICE_H_  // NOLINT
#define DEVICE_DEVICE_H_

#include "device/sdaa/profiler.h"
#include "device/sdaa/memory.h"
#include "device/sdaa/helper.h"
#include "device/sdaa/common.h"
using namespace ::optest::sdaa;

#if USE_CUDA
#include "device/cuda/profiler.h"
#include "device/cuda/memory.h"
#include "device/cuda/common.h"
using namespace ::optest::cuda;

#define initLDM(stream) 0
#define calcHash(stream, in_data, size, out_hash) 0
#define checkHBM(stream, in_data, size, value, result) 0
#define initHBM() 0
#endif

namespace optest {
void scdaMalloc(void **p, size_t size);
bool scdaFree(void *p);
int scdaFreeCheck(scdaStream_t stream);
void scdaDestroy();

void showVersions();

namespace Profiler {
void start();
void end();
ProfilePerfInfo duration();
}  // namespace Profiler

}  // namespace optest

#endif  // DEVICE_DEVICE_H_  // NOLINT
