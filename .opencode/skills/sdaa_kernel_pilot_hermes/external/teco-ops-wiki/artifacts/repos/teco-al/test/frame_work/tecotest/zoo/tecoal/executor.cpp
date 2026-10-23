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
 
#include <string>
#include "zoo/tecoal/convert.h"
#include "zoo/tecoal/executor.h"

namespace optest {
// namespace dnn{
TecoalExecutor::TecoalExecutor() { tecoalCreate(&handle_); }

TecoalExecutor::~TecoalExecutor() { tecoalDestroy(handle_); }

void TecoalExecutor::setContext() {
    if (exe_context_ == nullptr) {
        ALLOG(ERROR) << "exe_context_ is nullptr";
        throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    } else {
        checktecoal(tecoalSetStream(handle_, exe_context_->stream));
    }
}

void TecoalExecutor::getNCHW(std::vector<int> shape, tecoalTensorFormat_t format, int *N, int *C,
                          int *H, int *W) {
    switch (format) {
        case TECOAL_TENSOR_NCHW: {
            *N = shape[0];
            *C = shape[1];
            *H = shape[2];
            *W = shape[3];
            break;
        }
        case TECOAL_TENSOR_NHWC: {
            *N = shape[0];
            *H = shape[1];
            *W = shape[2];
            *C = shape[3];
            break;
        }
        case TECOAL_TENSOR_CHWN: {
            *C = shape[0];
            *H = shape[1];
            *W = shape[2];
            *N = shape[3];
            break;
        }
        case TECOAL_TENSOR_NWHC: {
            *N = shape[0];
            *W = shape[1];
            *H = shape[2];
            *C = shape[3];
            break;
        }
        default:
            ALLOG(ERROR) << "Don't support this layout.";
            throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    }
}

tecoalFilterDescriptor_t TecoalExecutor::createFilterDesc(MetaTensor *mt) {
    if (unlikely((mt->null()))) {
        ALLOG(WARNING) << "TecoalExecutor: skip creating filter " << mt->name << ", set it as nullptr.";
        // if don't have this tensor, set it as nullptr;
        // push an desc as nullptr, and is_output marked as false.
        return nullptr;
    }

    tecoalFilterDescriptor_t desc = nullptr;
    tecoalDataType_t dataType = convert::toTecoalDataType(mt->dtype);
    tecoalTensorFormat_t format = convert::toTecoalFormat(mt->layout);
    checktecoal(tecoalCreateFilterDescriptor(&desc));
    if (mt->shape.size() == 4 && mt->layout != testpt::LAYOUT_ARRAY) {
        int M = 1, C = 1, R = 1, S = 1;
        getNCHW(mt->shape, format, &M, &C, &R, &S);
        checktecoal(tecoalSetFilter4dDescriptor(desc, dataType, format, M, C, R, S));
    } else {
        // checktecoal(tecoalSetFilterNdDescriptor(desc, dataType, format, mt->shape.size(),
        //                                           mt->shape.data()));
    }
    return desc;
}

tecoalTensorDescriptor_t TecoalExecutor::createTensorDesc(MetaTensor *mt) {
    if (unlikely((mt->null()))) {
        ALLOG(WARNING) << "TecoalExecutor: skip creating tensor " << mt->name << ", set it as nullptr.";
        // if don't have this tensor, set it as nullptr;
        // push an desc as nullptr, and is_output marked as false.
        return nullptr;
    }

    tecoalTensorDescriptor_t desc = nullptr;
    tecoalDataType_t dataType = convert::toTecoalDataType(mt->dtype);

    checktecoal(tecoalCreateTensorDescriptor(&desc));
    if (mt->shape.size() == 4 && mt->layout != testpt::LAYOUT_ARRAY) {
        tecoalTensorFormat_t format = convert::toTecoalFormat(mt->layout);
        int N = 1, C = 1, H = 1, W = 1;
        getNCHW(mt->shape, format, &N, &C, &H, &W);
        checktecoal(tecoalSetTensor4dDescriptor(desc, format, dataType, N, C, H, W));
    } else {
        checktecoal(tecoalSetTensorNdDescriptor(desc, dataType, mt->shape.size(),
                                                  mt->shape.data(), mt->stride.data()))
    }

    return desc;
}

void TecoalExecutor::createDesc() {
    for (size_t i = 0; i < parser_->inputs().size(); ++i) {
        MetaTensor *mt = parser_->input(i);
        switch (mt->ttype) {
            case testpt::TENSOR: input_desc_.push_back((void *)createTensorDesc(mt)); break;
            case testpt::FILTER: input_desc_.push_back((void *)createFilterDesc(mt)); break;
            case testpt::VALID: input_desc_.push_back(nullptr); break;
            default:
                ALLOG(ERROR) << "Don't support this ttype.";
                throw std::invalid_argument(std::string(__FILE__) + " +" +
                                            std::to_string(__LINE__));
        }
    }

    for (size_t i = 0; i < parser_->outputs().size(); ++i) {
        MetaTensor *mt = parser_->output(i);
        switch (mt->ttype) {
            case testpt::TENSOR: output_desc_.push_back(createTensorDesc(mt)); break;
            case testpt::FILTER: output_desc_.push_back(createFilterDesc(mt)); break;
            case testpt::VALID: output_desc_.push_back(nullptr); break;
            default:
                ALLOG(ERROR) << "Don't support this ttype.";
                throw std::invalid_argument(std::string(__FILE__) + " +" +
                                            std::to_string(__LINE__));
        }
    }
}

void TecoalExecutor::destroyDesc() {
    for (size_t i = 0; i < parser_->inputs().size(); ++i) {
        MetaTensor *mt = parser_->input(i);
        switch (mt->ttype) {
            case testpt::TENSOR:
                checktecoal(
                    tecoalDestroyTensorDescriptor((tecoalTensorDescriptor_t)input_desc_[i]));
                break;
            case testpt::FILTER:
                checktecoal(
                    tecoalDestroyFilterDescriptor((tecoalFilterDescriptor_t)input_desc_[i]));
                break;
            case testpt::VALID: break;
            default:
                ALLOG(ERROR) << "Don't support this ttype.";
                throw std::invalid_argument(std::string(__FILE__) + " +" +
                                            std::to_string(__LINE__));
        }
        input_desc_[i] = nullptr;
    }

    for (size_t i = 0; i < parser_->outputs().size(); ++i) {
        MetaTensor *mt = parser_->output(i);
        switch (mt->ttype) {
            case testpt::TENSOR:
                checktecoal(
                    tecoalDestroyTensorDescriptor((tecoalTensorDescriptor_t)output_desc_[i]));
                break;
            case testpt::FILTER:
                checktecoal(
                    tecoalDestroyFilterDescriptor((tecoalFilterDescriptor_t)output_desc_[i]));
                break;
            case testpt::VALID: break;
            default:
                ALLOG(ERROR) << "Don't support this ttype.";
                throw std::invalid_argument(std::string(__FILE__) + " +" +
                                            std::to_string(__LINE__));
        }
        output_desc_[i] = nullptr;
    }
}

void TecoalExecutor::workspaceMalloc() {
    if (parser_->getProtoNode()->has_workspace()) {
        workSpaceSizeInBytes_ = parser_->workspace()->total_count;
    } else {
        getWorkspaceSize();
    }
    ALLOG(VLOG) << "workspace_size = " << workSpaceSizeInBytes_;
    if (workSpaceSizeInBytes_ != 0) scdaMalloc(&workSpace_, workSpaceSizeInBytes_);

    if (parser_->getProtoNode()->has_reservespace()) {
        reserveSpaceSizeInBytes_ = parser_->reservespace()->total_count;
    } else {
        getReservespaceSize();
    }
    if (reserveSpaceSizeInBytes_ != 0) scdaMalloc(&reserveSpace_, reserveSpaceSizeInBytes_);
}

void TecoalExecutor::workspaceFree() {
    if (workSpaceSizeInBytes_ != 0) {
        if (!scdaFree(workSpace_)) {
            ALLOG(ERROR) << "workspace memory out of bounds!!!\n";
            ADD_FAILURE() << "workspace memory out of bounds!!!\n";
            eva_res_.status = TECOTEST_STATUS_MEMORY_OUT_ERROR1;
        }
    }
    if (reserveSpaceSizeInBytes_ != 0) {
        if (!scdaFree(reserveSpace_)) {
            ALLOG(ERROR) << "reservespace memory out of bounds!!!\n";
            ADD_FAILURE() << "reservespace memory out of bounds!!!\n";
            eva_res_.status = TECOTEST_STATUS_MEMORY_OUT_ERROR1;
        }
    }
}

// }
}  // namespace optest
