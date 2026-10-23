#include "zoo/tecoal/logical_not_tensor/logical_not_tensor.h"
#include <stdio.h>
#include <tecoal.h>
#include <iostream>
#include <string>
#include "zoo/tecoal/convert.h"

namespace optest {

void LogicalNotTensorExecutor::paramCheck() {
    if (parser_->inputs().size() != 1) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }

    if (parser_->outputs().size() != 1) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }
}

void LogicalNotTensorExecutor::paramParse() {
    auto logical_not_tensor_param =
        parser_->getProtoNode()->tecoal_param().logical_not_tensor_param();
    algo_ = convert::toTecoalAlgo(logical_not_tensor_param.algo());
}

void LogicalNotTensorExecutor::paramGeneration() {
    aDesc_ = getInputDesc<tecoalTensorDescriptor_t>(0);
    A_ = dev_input[0];
    cDesc_ = getOutputDesc<tecoalTensorDescriptor_t>(0);
    C_ = dev_output[0];
}

void LogicalNotTensorExecutor::compute() {
    checktecoal((tecoalLogicalNotTensor(handle_, aDesc_, A_, cDesc_, C_, algo_)));
}

int64_t LogicalNotTensorExecutor::getTheoryOps() {
    int64_t theory_ops = parser_->input(0)->shape_count;
    return theory_ops;
}

int64_t LogicalNotTensorExecutor::getTheoryIoSize() { return getIoSize(); }

void LogicalNotTensorExecutor::cpuCompute() { pythonComputeCPU("cpu"); }

}  // namespace optest
