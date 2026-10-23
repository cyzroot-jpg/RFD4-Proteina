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

#ifndef ZOO_TECOAL_CONVERT_H_  // NOLINT
#define ZOO_TECOAL_CONVERT_H_
#include "test_proto/optest.pb.h"
#include "zoo/tecozoo.h"
namespace optest {
namespace convert {

tecoalDataType_t toTecoalDataType(testpt::DataType dtype);
tecoalTensorFormat_t toTecoalFormat(testpt::TensorLayout layout);
tecoalAlgo_t toTecoalAlgo(testpt::Algo algo);
tecoalUniqueMode_t toTecoalUniqueMode(testpt::UniqueMode unique_mode);
tecoalUnaryOpsMode_t toTecoalUnaryOpsMode(testpt::UnaryOpsMode unary_ops_mode);
tecoalScatterOutReductionMode_t toTecoalScatterOutReductionMode(
    testpt::ScatterOutReductionMode scatter_out_reduction_mode);
tecoalScatterOutInputType_t toTecoalScatterOutInputType(
    testpt::ScatterOutInputType scatter_out_input_type);
tecoalActivationMode_t toTecoalActivationMode(testpt::ActivationMode activation_mode);
tecoalNanPropagation_t toTecoalNanPropagation(testpt::NanPropagation nan_propagation);
tecoalConvolutionMode_t toTecoalConvolutionMode(testpt::ConvolutionMode convolution_mode);
tecoalMathType_t toTecoalMathType(testpt::MathType math_type);

}  // namespace convert

}  // namespace optest
#endif  // ZOO_TECOAL_CONVERT_H_  // NOLINT
