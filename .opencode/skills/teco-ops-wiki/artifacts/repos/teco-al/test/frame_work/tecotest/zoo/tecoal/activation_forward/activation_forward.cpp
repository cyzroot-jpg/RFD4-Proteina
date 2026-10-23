#include "zoo/tecoal/activation_forward/activation_forward.h"
#include <stdio.h>
#include <tecoal.h>
#include <iostream>
#include <string>
#include "zoo/tecoal/convert.h"
namespace optest {

void ActivationForwardExecutor::destroy() {
    checktecoal(tecoalDestroyActivationDescriptor(activationDesc_));
}

void ActivationForwardExecutor::paramCheck() {
    if (parser_->inputs().size() != 2) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }

    if (parser_->outputs().size() != 0) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }
}

void ActivationForwardExecutor::paramParse() {
    auto activation_forward_param = parser_->getProtoNode()->tecoal_param().activation_forward_param();
    auto activation_desc_param =
        parser_->getProtoNode()->tecoal_param().activation_forward_param().act_desc_param();
    alpha_ = activation_forward_param.alpha();
    beta_ = activation_forward_param.beta();
    mode_ = convert::toTecoalActivationMode(activation_desc_param.mode());
    nanopt_ = convert::toTecoalNanPropagation(activation_desc_param.relu_nanopt());
    coef_ = activation_desc_param.coef();
    algo_ = convert::toTecoalAlgo(activation_forward_param.algo());
}

void ActivationForwardExecutor::paramGeneration() {
    xDesc_ = getInputDesc<tecoalTensorDescriptor_t>(0);
    x_ = dev_input[0];
    yDesc_ = getInputDesc<tecoalTensorDescriptor_t>(1);
    y_ = dev_input[1];

    checktecoal(tecoalCreateActivationDescriptor(&activationDesc_));
    checktecoal(tecoalSetActivationDescriptor(activationDesc_, mode_, nanopt_, coef_));
}

void ActivationForwardExecutor::compute() {
    checktecoal(tecoalActivationForward(handle_, activationDesc_, &alpha_, xDesc_, x_, &beta_,
                                          yDesc_, y_, algo_));
}

int64_t ActivationForwardExecutor::getTheoryOps() {
    int64_t theory_ops = parser_->input(0)->shape_count;
    return theory_ops;
}

int64_t ActivationForwardExecutor::getTheoryIoSize() { return getIoSizeWithBeta(beta_); }

void ActivationForwardExecutor::cpuCompute() { pythonComputeCPU("cpu"); }

void ActivationForwardExecutor::gpuCompute() { pythonComputeGPU("cuda"); }

}  // namespace optest
