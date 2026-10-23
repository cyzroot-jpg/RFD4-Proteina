#include "zoo/tecoal/conv_forward/conv_forward.h"
#include <stdio.h>
#include <tecoal.h>
#include <iostream>
#include <string>
#include "zoo/tecoal/convert.h"

namespace optest {

void ConvForwardExecutor::destroy() {
    tecoalDestroyConvolutionDescriptor(convDesc_);
}

void ConvForwardExecutor::paramCheck() {
    if (parser_->inputs().size() != 3) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }

    if (parser_->outputs().size() != 0) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }
}

void ConvForwardExecutor::paramParse() {
    auto convolution_param = parser_->getProtoNode()->tecoal_param().conv_forward_param();
    alpha_ = convolution_param.alpha();
    beta_ = convolution_param.beta();
    algo_ = convert::toTecoalAlgo(convolution_param.algo());


    auto conv_desc_param = convolution_param.conv_desc_param();
    if (3 == conv_desc_param.stride_array_size()) {
        conv_desc_param_.conv_dims = 3;
    } else {
        conv_desc_param_.conv_dims = 2;
    }
    if (2 == conv_desc_param_.conv_dims) {
        conv_desc_param_.stride_h = conv_desc_param.stride_h();
        conv_desc_param_.stride_w = conv_desc_param.stride_w();
        conv_desc_param_.padding_h = conv_desc_param.padding_h();
        conv_desc_param_.padding_w = conv_desc_param.padding_w();
        conv_desc_param_.dilation_h = conv_desc_param.dilation_h();
        conv_desc_param_.dilation_w = conv_desc_param.dilation_w();
    } else {
        for (int i = 0; i < conv_desc_param_.conv_dims; i++) {
            conv_desc_param_.stride_3d[i] = conv_desc_param.stride_array(i);
            conv_desc_param_.pad_3d[i] = conv_desc_param.pad_array(i);
            conv_desc_param_.dila_3d[i] = conv_desc_param.dilation_array(i);
        }
    }
    conv_desc_param_.groups = conv_desc_param.groups();
    conv_desc_param_.mode = convert::toTecoalConvolutionMode(conv_desc_param.mode());
    // conv_desc_param_.data_type = convert::toTecoalDataType(0);
    conv_desc_param_.data_type = convert::toTecoalDataType(conv_desc_param.conv_datatype());
    conv_desc_param_.math_type = convert::toTecoalMathType(conv_desc_param.math());
}

void ConvForwardExecutor::paramGeneration() {
    xDesc_ = getInputDesc<tecoalTensorDescriptor_t>(0);
    x_ = dev_input[0];
    wDesc_ = getInputDesc<tecoalFilterDescriptor_t>(1);
    w_ = dev_input[1];
    yDesc_ = getInputDesc<tecoalTensorDescriptor_t>(2);
    y_ = dev_input[2];


    checktecoal(tecoalCreateConvolutionDescriptor(&convDesc_));
    if (2 == conv_desc_param_.conv_dims) {
        checktecoal(tecoalSetConvolution2dDescriptor(
            convDesc_, conv_desc_param_.padding_h, conv_desc_param_.padding_w,
            conv_desc_param_.stride_h, conv_desc_param_.stride_w, conv_desc_param_.dilation_h,
            conv_desc_param_.dilation_w, conv_desc_param_.mode, conv_desc_param_.data_type));
    }
    // } else {
    //     checktecoal(tecoalSetConvolutionNdDescriptor(
    //         convDesc_, conv_desc_param_.conv_dims, conv_desc_param_.pad_3d,
    //         conv_desc_param_.stride_3d, conv_desc_param_.dila_3d, conv_desc_param_.mode,
    //         conv_desc_param_.data_type));
    // }

    // tecoalSetConvolutionMathType(convDesc_, conv_desc_param_.math_type);
    // if (conv_desc_param_.groups != 1)
    //     tecoalSetConvolutionGroupCount(convDesc_, conv_desc_param_.groups);
    // compute_w_ = w_;
}

void ConvForwardExecutor::getWorkspaceSize() {
    checktecoal(tecoalGetConvolutionForwardWorkspaceSize(
        handle_, xDesc_, wDesc_, convDesc_, yDesc_, algo_, &workSpaceSizeInBytes_));
}

void ConvForwardExecutor::compute() {
    checktecoal(tecoalConvolutionForward(handle_, &alpha_, xDesc_, x_, wDesc_, w_,
                                           convDesc_, algo_, workSpace_, workSpaceSizeInBytes_,
                                           &beta_, yDesc_, y_));
}

int64_t ConvForwardExecutor::getTheoryOps() {
    int N, C, H, W, M, E, F, R, S;
    int D = 1, V = 1, L = 1;
    getNCHW(parser_->input(0)->shape, convert::toTecoalFormat(parser_->input(0)->layout), &N, &C,
            &H, &W);
    getNCHW(parser_->input(2)->shape, convert::toTecoalFormat(parser_->input(2)->layout), &N, &M,
            &E, &F);
    getNCHW(parser_->input(1)->shape, convert::toTecoalFormat(parser_->input(1)->layout), &M, &C,
            &R, &S);

    return (int64_t)N * C * E * F * R * S * M * V * L * 2;
}

int64_t ConvForwardExecutor::getTheoryIoSize() { return getIoSizeWithBeta(beta_); }

void ConvForwardExecutor::cpuCompute() { pythonComputeCPU("cpu"); }

void ConvForwardExecutor::gpuCompute() { pythonComputeGPU("cuda"); }

}  // namespace optest
