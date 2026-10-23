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

#include "zoo/tecoal/convert.h"
#include <string>
#include "common/tecoallog.h"
namespace optest {
namespace convert {
tecoalDataType_t toTecoalDataType(testpt::DataType dtype) {
    switch (dtype) {
        case testpt::DTYPE_HALF: return TECOAL_DATA_HALF;
        case testpt::DTYPE_FLOAT: return TECOAL_DATA_FLOAT;
        case testpt::DTYPE_INT8: return TECOAL_DATA_INT8;
        case testpt::DTYPE_INT16: return TECOAL_DATA_INT16;
        case testpt::DTYPE_INT32: return TECOAL_DATA_INT32;
        case testpt::DTYPE_INT64: return TECOAL_DATA_INT64;
        case testpt::DTYPE_UINT8: return TECOAL_DATA_UINT8;
        case testpt::DTYPE_BOOL: return TECOAL_DATA_BOOL;
        case testpt::DTYPE_DOUBLE: return TECOAL_DATA_DOUBLE;
        case testpt::DTYPE_BFLOAT16: return TECOAL_DATA_BFLOAT16;
        case testpt::DTYPE_UINT16:
        case testpt::DTYPE_UINT32:
        case testpt::DTYPE_UINT64:
            ALLOG(ERROR) << "Don't support this dtype. Not supported now";
            throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
        default:
            ALLOG(ERROR) << "Don't support this dtype.";
            throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    }
    return TECOAL_DATA_FLOAT;
}

tecoalTensorFormat_t toTecoalFormat(testpt::TensorLayout layout) {
    switch (layout) {
        case testpt::LAYOUT_NCHW: return TECOAL_TENSOR_NCHW;
        case testpt::LAYOUT_NHWC: return TECOAL_TENSOR_NHWC;
        case testpt::LAYOUT_CHWN: return TECOAL_TENSOR_CHWN;
        case testpt::LAYOUT_NWHC:
            return TECOAL_TENSOR_NWHC;
            ALLOG(ERROR) << "Don't support this layout. Not supported now";
            break;
        default:
            throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    }
    return TECOAL_TENSOR_NCHW;
}

tecoalMathType_t toTecoalMathType(testpt::MathType math_type){
    switch(math_type){
    case testpt::DEFAULT_MATH: return TECOAL_DEFAULT_MATH;
    case testpt::TENSOR_ACC_MATH: return TECOAL_TENSOR_ACC_MATH;
    case testpt::TENSOR_ACC_MATH_ALLOW_CONVERSION: return TECOAL_TENSOR_ACC_MATH_ALLOW_CONVERSION;
    default:
      ALLOG(ERROR) << "Don't support this conv_mode.";
      throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    }
    return TECOAL_DEFAULT_MATH;
}

tecoalAlgo_t toTecoalAlgo(testpt::Algo algo) {
    switch (algo) {
        case testpt::ALGO_0: return TECOAL_ALGO_0;
        case testpt::ALGO_1: return TECOAL_ALGO_1;
        case testpt::ALGO_2: return TECOAL_ALGO_2;
        case testpt::ALGO_3: return TECOAL_ALGO_3;
        case testpt::ALGO_4: return TECOAL_ALGO_4;
        case testpt::ALGO_5: return TECOAL_ALGO_5;
        case testpt::ALGO_6: return TECOAL_ALGO_6;
        case testpt::ALGO_7: return TECOAL_ALGO_7;
        case testpt::ALGO_8: return TECOAL_ALGO_8;
        case testpt::ALGO_9: return TECOAL_ALGO_9;
        case testpt::ALGO_10: return TECOAL_ALGO_10;
        case testpt::ALGO_11: return TECOAL_ALGO_11;
        case testpt::ALGO_12: return TECOAL_ALGO_12;
        case testpt::ALGO_13: return TECOAL_ALGO_13;
        case testpt::ALGO_14: return TECOAL_ALGO_14;
        case testpt::ALGO_15: return TECOAL_ALGO_15;
        case testpt::ALGO_16: return TECOAL_ALGO_16;
        case testpt::ALGO_17: return TECOAL_ALGO_17;
        case testpt::ALGO_18: return TECOAL_ALGO_18;
        case testpt::ALGO_19: return TECOAL_ALGO_19;
        case testpt::ALGO_20: return TECOAL_ALGO_20;
        case testpt::ALGO_21: return TECOAL_ALGO_21;
        case testpt::ALGO_22: return TECOAL_ALGO_22;
        case testpt::ALGO_23: return TECOAL_ALGO_23;
        case testpt::ALGO_24: return TECOAL_ALGO_24;
        case testpt::ALGO_25: return TECOAL_ALGO_25;
        case testpt::ALGO_26: return TECOAL_ALGO_26;
        case testpt::ALGO_27: return TECOAL_ALGO_27;
        case testpt::ALGO_28: return TECOAL_ALGO_28;
        case testpt::ALGO_29: return TECOAL_ALGO_29;
        case testpt::ALGO_30: return TECOAL_ALGO_30;
        case testpt::ALGO_31: return TECOAL_ALGO_31;
        case testpt::ALGO_32: return TECOAL_ALGO_32;
        case testpt::ALGO_33: return TECOAL_ALGO_33;
        case testpt::ALGO_34: return TECOAL_ALGO_34;
        case testpt::ALGO_35: return TECOAL_ALGO_35;
        case testpt::ALGO_36: return TECOAL_ALGO_36;
        case testpt::ALGO_37: return TECOAL_ALGO_37;
        case testpt::ALGO_38: return TECOAL_ALGO_38;
        case testpt::ALGO_39: return TECOAL_ALGO_39;
        case testpt::ALGO_40: return TECOAL_ALGO_40;
        case testpt::ALGO_41: return TECOAL_ALGO_41;
        case testpt::ALGO_42: return TECOAL_ALGO_42;
        case testpt::ALGO_43: return TECOAL_ALGO_43;
        case testpt::ALGO_44: return TECOAL_ALGO_44;
        case testpt::ALGO_45: return TECOAL_ALGO_45;
        case testpt::ALGO_46: return TECOAL_ALGO_46;
        case testpt::ALGO_47: return TECOAL_ALGO_47;
        case testpt::ALGO_48: return TECOAL_ALGO_48;
        case testpt::ALGO_49: return TECOAL_ALGO_49;
        case testpt::ALGO_50: return TECOAL_ALGO_50;
        case testpt::ALGO_51: return TECOAL_ALGO_51;
        case testpt::ALGO_52: return TECOAL_ALGO_52;
        case testpt::ALGO_53: return TECOAL_ALGO_53;
        case testpt::ALGO_54: return TECOAL_ALGO_54;
        case testpt::ALGO_55: return TECOAL_ALGO_55;
        case testpt::ALGO_56: return TECOAL_ALGO_56;
        case testpt::ALGO_57: return TECOAL_ALGO_57;
        case testpt::ALGO_58: return TECOAL_ALGO_58;
        case testpt::ALGO_59: return TECOAL_ALGO_59;
        case testpt::ALGO_60: return TECOAL_ALGO_60;
        case testpt::ALGO_61: return TECOAL_ALGO_61;
        case testpt::ALGO_62: return TECOAL_ALGO_62;
        case testpt::ALGO_63: return TECOAL_ALGO_63;
        case testpt::ALGO_64: return TECOAL_ALGO_64;
        case testpt::ALGO_65: return TECOAL_ALGO_65;
        case testpt::ALGO_66: return TECOAL_ALGO_66;
        case testpt::ALGO_67: return TECOAL_ALGO_67;
        case testpt::ALGO_68: return TECOAL_ALGO_68;
        case testpt::ALGO_69: return TECOAL_ALGO_69;
        case testpt::ALGO_70: return TECOAL_ALGO_70;
        case testpt::ALGO_71: return TECOAL_ALGO_71;
        case testpt::ALGO_72: return TECOAL_ALGO_72;
        case testpt::ALGO_73: return TECOAL_ALGO_73;
        case testpt::ALGO_74: return TECOAL_ALGO_74;
        case testpt::ALGO_75: return TECOAL_ALGO_75;
        case testpt::ALGO_76: return TECOAL_ALGO_76;
        case testpt::ALGO_77: return TECOAL_ALGO_77;
        case testpt::ALGO_78: return TECOAL_ALGO_78;
        case testpt::ALGO_79: return TECOAL_ALGO_79;
        case testpt::ALGO_80: return TECOAL_ALGO_80;
        case testpt::ALGO_81: return TECOAL_ALGO_81;
        case testpt::ALGO_82: return TECOAL_ALGO_82;
        case testpt::ALGO_83: return TECOAL_ALGO_83;
        case testpt::ALGO_84: return TECOAL_ALGO_84;
        case testpt::ALGO_85: return TECOAL_ALGO_85;
        case testpt::ALGO_86: return TECOAL_ALGO_86;
        case testpt::ALGO_87: return TECOAL_ALGO_87;
        case testpt::ALGO_88: return TECOAL_ALGO_88;
        case testpt::ALGO_89: return TECOAL_ALGO_89;
        case testpt::ALGO_90: return TECOAL_ALGO_90;
        case testpt::ALGO_91: return TECOAL_ALGO_91;
        case testpt::ALGO_92: return TECOAL_ALGO_92;
        case testpt::ALGO_93: return TECOAL_ALGO_93;
        case testpt::ALGO_94: return TECOAL_ALGO_94;
        case testpt::ALGO_95: return TECOAL_ALGO_95;
        case testpt::ALGO_96: return TECOAL_ALGO_96;
        case testpt::ALGO_97: return TECOAL_ALGO_97;
        case testpt::ALGO_98: return TECOAL_ALGO_98;
        case testpt::ALGO_99: return TECOAL_ALGO_99;
        case testpt::ALGO_100: return TECOAL_ALGO_100;
        case testpt::ALGO_101: return TECOAL_ALGO_101;
        case testpt::ALGO_102: return TECOAL_ALGO_102;
        case testpt::ALGO_103: return TECOAL_ALGO_103;
        case testpt::ALGO_104: return TECOAL_ALGO_104;
        case testpt::ALGO_105: return TECOAL_ALGO_105;
        case testpt::ALGO_106: return TECOAL_ALGO_106;
        case testpt::ALGO_107: return TECOAL_ALGO_107;
        case testpt::ALGO_108: return TECOAL_ALGO_108;
        case testpt::ALGO_109: return TECOAL_ALGO_109;
        case testpt::ALGO_110: return TECOAL_ALGO_110;
        default: {
            ALLOG(ERROR) << "Don't support this ALGO. Not supported now";
            throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
        }
    }
}

tecoalUniqueMode_t toTecoalUniqueMode(testpt::UniqueMode unique_mode) {
    switch (unique_mode) {
        case testpt::UNIQUE_NONE: return TECOAL_UNIQUE_NONE;
        case testpt::UNIQUE_NOT_NONE: return TECOAL_UNIQUE_NOT_NONE;
        default:
            ALLOG(ERROR) << "Don't support this conv_mode.";
            throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    }
    return TECOAL_UNIQUE_NONE;
}

tecoalUnaryOpsMode_t toTecoalUnaryOpsMode(testpt::UnaryOpsMode unary_ops_mode) {
    switch (unary_ops_mode) {
        case testpt::BATCH_MUL_A: return TECOAL_BATCH_MUL_A;
        case testpt::BATCH_ADD_A: return TECOAL_BATCH_ADD_A;
        default:
            ALLOG(ERROR) << "Don't support this conv_mode.";
            throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    }
    return TECOAL_BATCH_MUL_A;
}

tecoalScatterOutReductionMode_t toTecoalScatterOutReductionMode(
    testpt::ScatterOutReductionMode scatter_out_reduction_mode) {
    switch (scatter_out_reduction_mode) {
        case testpt::SCATTEROUT_REDUCTION_NONE: return TECOAL_SCATTEROUT_REDUCTION_NONE;
        case testpt::SCATTEROUT_REDUCTION_ADD: return TECOAL_SCATTEROUT_REDUCTION_ADD;
        case testpt::SCATTEROUT_REDUCTION_MULTIPLY: return TECOAL_SCATTEROUT_REDUCTION_MULTIPLY;
        default:
            ALLOG(ERROR) << "Don't support this conv_mode.";
            throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    }
    return TECOAL_SCATTEROUT_REDUCTION_NONE;
}

tecoalScatterOutInputType_t toTecoalScatterOutInputType(
    testpt::ScatterOutInputType scatter_out_input_type) {
    switch (scatter_out_input_type) {
        case testpt::SCATTEROUT_INPUT_SCALAR: return TECOAL_SCATTEROUT_INPUT_SCALAR;
        case testpt::SCATTEROUT_INPUT_ARRAY: return TECOAL_SCATTEROUT_INPUT_ARRAY;
        default:
            ALLOG(ERROR) << "Don't support this conv_mode.";
            throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    }
    return TECOAL_SCATTEROUT_INPUT_SCALAR;
}

tecoalActivationMode_t toTecoalActivationMode(testpt::ActivationMode activation_mode) {
    switch (activation_mode) {
        // case testpt::ACTIVATION_SIGMOID: return TECOAL_ACTIVATION_SIGMOID;
        // case testpt::ACTIVATION_RELU: return TECOAL_ACTIVATION_RELU;
        // case testpt::ACTIVATION_TANH: return TECOAL_ACTIVATION_TANH;
        // case testpt::ACTIVATION_CLIPPED_RELU: return TECOAL_ACTIVATION_CLIPPED_RELU;
        // case testpt::ACTIVATION_ELU: return TECOAL_ACTIVATION_ELU;
        // case testpt::ACTIVATION_IDENTITY: return TECOAL_ACTIVATION_IDENTITY;
        // case testpt::ACTIVATION_SIGMOID_TAB: return TECOAL_ACTIVATION_SIGMOID_TAB;
        // case testpt::ACTIVATION_ELU_TAB: return TECOAL_ACTIVATION_ELU_TAB;
        // case testpt::ACTIVATION_TANH_TAB: return TECOAL_ACTIVATION_TANH_TAB;
        // case testpt::ACTIVATION_GELU: return TECOAL_ACTIVATION_GELU;
        // case testpt::ACTIVATION_LEAKYRELU: return TECOAL_ACTIVATION_LEAKYRELU;
        // case testpt::ACTIVATION_SELU: return TECOAL_ACTIVATION_SELU;
        // case testpt::ACTIVATION_RELU6: return TECOAL_ACTIVATION_RELU6;
        case testpt::ACTIVATION_SILU: return TECOAL_ACTIVATION_SILU;
        // case testpt::ACTIVATION_GELU_APPROXIMATE: return TECOAL_ACTIVATION_GELU_APPROXIMATE;
        // case testpt::ACTIVATION_TANH_ACCURATE: return TECOAL_ACTIVATION_TANH_ACCURATE;
        // case testpt::ACTIVATION_GELU_ACCURATE: return TECOAL_ACTIVATION_GELU_ACCURATE;
        // case testpt::ACTIVATION_GELU_APPROXIMATE_ACCURATE: return
        // TECOAL_ACTIVATION_GELU_APPROXIMATE_ACCURATE; case testpt::ACTIVATION_SIGMOID_PRECISION:
        // return TECOAL_ACTIVATION_SIGMOID_PRECISION; case testpt::ACTIVATION_SILU_TAB: return
        // TECOAL_ACTIVATION_SILU_TAB; case testpt::ACTIVATION_GELU_TAB: return
        // TECOAL_ACTIVATION_GELU_TAB; case testpt::ACTIVATION_ERF: return TECOAL_ACTIVATION_ERF;
        // case testpt::ACTIVATION_ERF_TAB: return TECOAL_ACTIVATION_ERF_TAB;
        // case testpt::ACTIVATION_MISH_INFERENCE: return TECOAL_ACTIVATION_MISH_INFERENCE;
        // case testpt::ACTIVATION_HARDSWISH: return TECOAL_ACTIVATION_HARDSWISH;
        // case testpt::ACTIVATION_HARDSIGMOID: return TECOAL_ACTIVATION_HARDSIGMOID;
        default:
            ALLOG(ERROR) << "Don't support this conv_mode.";
            throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    }
    return TECOAL_ACTIVATION_SILU;
}

tecoalNanPropagation_t toTecoalNanPropagation(testpt::NanPropagation nan_propagation) {
    switch (nan_propagation) {
        case testpt::NOT_PROPAGATE_NAN: return TECOAL_NOT_PROPAGATE_NAN;
        case testpt::PROPAGATE_NAN: return TECOAL_PROPAGATE_NAN;
        default:
            ALLOG(ERROR) << "Don't support this conv_mode.";
            throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    }
    return TECOAL_NOT_PROPAGATE_NAN;
}

tecoalConvolutionMode_t toTecoalConvolutionMode(testpt::ConvolutionMode convolution_mode){
    switch(convolution_mode){
        case testpt::CONVOLUTION: return TECOAL_CONVOLUTION;
        case testpt::CROSS_CORRELATION: return TECOAL_CROSS_CORRELATION;
        default:
        ALLOG(ERROR) << "Don't support this conv_mode.";
        throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    }
    return TECOAL_CONVOLUTION;
}

}  // namespace convert
}  // namespace optest
