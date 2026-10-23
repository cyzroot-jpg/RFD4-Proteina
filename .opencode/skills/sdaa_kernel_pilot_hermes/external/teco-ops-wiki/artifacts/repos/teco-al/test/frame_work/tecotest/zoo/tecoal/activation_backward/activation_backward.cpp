#include "zoo/tecoal/activation_backward/activation_backward.h"
#include <stdio.h>
#include <tecoal.h>
#include <iostream>
#include <string>
#include "zoo/tecoal/convert.h"

namespace optest {

void ActivationBackwardExecutor::destroy() {
    checktecoal(tecoalDestroyActivationDescriptor(activationDesc_));
}

void ActivationBackwardExecutor::paramCheck() {
    if (parser_->inputs().size() != 4) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }

    if (parser_->outputs().size() != 0) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }
}

void ActivationBackwardExecutor::paramParse() {
    auto activation_backward_param =
        parser_->getProtoNode()->tecoal_param().activation_backward_param();
    auto activation_desc_param =
        parser_->getProtoNode()->tecoal_param().activation_backward_param().act_desc_param();
    alpha_ = activation_backward_param.alpha();
    beta_ = activation_backward_param.beta();
    mode_ = convert::toTecoalActivationMode(activation_desc_param.mode());
    nanopt_ = convert::toTecoalNanPropagation(activation_desc_param.relu_nanopt());
    coef_ = activation_desc_param.coef();
    algo_ = convert::toTecoalAlgo(activation_backward_param.algo());
}

void ActivationBackwardExecutor::paramGeneration() {
    yDesc_ = getInputDesc<tecoalTensorDescriptor_t>(0);
    y_ = dev_input[0];
    dyDesc_ = getInputDesc<tecoalTensorDescriptor_t>(1);
    dy_ = dev_input[1];
    xDesc_ = getInputDesc<tecoalTensorDescriptor_t>(2);
    x_ = dev_input[2];
    dxDesc_ = getInputDesc<tecoalTensorDescriptor_t>(3);
    dx_ = dev_input[3];

    checktecoal(tecoalCreateActivationDescriptor(&activationDesc_));
    checktecoal(tecoalSetActivationDescriptor(activationDesc_, mode_, nanopt_, coef_));
}

void ActivationBackwardExecutor::forward() {
    if (!hasInputData()) {
        float alpha = 1.0;
        float beta = 0.0;
        checktecoal(tecoalActivationForward(handle_, activationDesc_, &alpha, xDesc_, x_, &beta,
                                              yDesc_, y_, algo_));
    }
}

void ActivationBackwardExecutor::compute() {
    checktecoal(tecoalActivationBackward(handle_, activationDesc_, &alpha_, yDesc_, y_, dyDesc_,
                                           dy_, xDesc_, x_, &beta_, dxDesc_, dx_, algo_));
}

int64_t ActivationBackwardExecutor::getTheoryOps() {
    int64_t theory_ops = parser_->input(0)->shape_count;
    return theory_ops;
}

int64_t ActivationBackwardExecutor::getTheoryIoSize() {
    size_t total_size = 0;
    MetaTensor *ts = parser_->input(0);
    total_size = ts->size_in_bytes;
    // if (mode_ == tecoal_ACTIVATION_IDENTITY) {
    //     total_size *= 2;
    // } else {
    //     total_size *= 3;
    // }
    total_size *= 3;

    if (fabs(beta_) > 1e-5) {
        total_size += ts->size_in_bytes;
    }

    return total_size;
}

void ActivationBackwardExecutor::cpuCompute() { pythonComputeCPU("cpu"); }

void ActivationBackwardExecutor::gpuCompute() { pythonComputeGPU("cuda"); }

}  // namespace optest
