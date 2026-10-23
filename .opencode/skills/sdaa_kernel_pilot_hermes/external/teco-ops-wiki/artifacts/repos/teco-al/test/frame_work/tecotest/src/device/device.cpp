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
 
#include "device/device.h"
#include "common/context.h"
#include "device/sdaa/memory.h"
#include "device/sdaa/version.h"
#include "device/sdaa/profiler.h"
#include "device/sdaa/common.h"
using namespace ::optest::sdaa;

#if USE_CUDA
#include "device/cuda/memory.h"
#include "device/cuda/version.h"
#include "device/cuda/profiler.h"
#include "device/cuda/common.h"
using namespace ::optest::cuda;
#endif

namespace optest {

void scdaMalloc(void **p, size_t size) {
    if (Context::instance()->checkAllMemory()) {
        DeviceMemoryPool::instance()->deviceMalloc(p, size);
    } else {
        DeviceMemory::instance()->deviceMalloc(p, size);
    }
}
bool scdaFree(void *p) {
    if (Context::instance()->checkAllMemory()) {
        return DeviceMemoryPool::instance()->deviceFree(p);
    } else {
        return DeviceMemory::instance()->deviceFree(p);
    }
}
int scdaFreeCheck(scdaStream_t stream) {
    if (Context::instance()->checkAllMemory()) {
        return DeviceMemoryPool::instance()->check(stream);
    } else {
        return DeviceMemory::instance()->check(stream);
    }
}

void scdaDestroy() {
    if (Context::instance()->checkAllMemory()) {
        DeviceMemoryPool::instance()->destroy();
    } else {
        DeviceMemory::instance()->destroy();
    }
}

void showVersions() { printVersions(); }

namespace Profiler {
void start() { DeviceProfiler::instance()->start(); }
void end() { DeviceProfiler::instance()->end(); }
ProfilePerfInfo duration() { return DeviceProfiler::instance()->duration(); }
}  // namespace Profiler

}  // namespace optest
