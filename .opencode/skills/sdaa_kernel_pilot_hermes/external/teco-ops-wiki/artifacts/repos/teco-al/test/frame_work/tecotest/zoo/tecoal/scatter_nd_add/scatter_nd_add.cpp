#include "zoo/tecoal/scatter_nd_add/scatter_nd_add.h"
#include <stdio.h>
#include <tecoal.h>
#include <iostream>
#include <string>
#include "zoo/tecoal/convert.h"

namespace optest {

void ScatterNdAddExecutor::paramCheck() {
    if (parser_->inputs().size() != 3) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }

    if (parser_->outputs().size() != 1) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }
}

void ScatterNdAddExecutor::paramParse() {
    auto scatter_nd_add_param = parser_->getProtoNode()->tecoal_param().scatter_nd_add_param();
    algo_ = convert::toTecoalAlgo(scatter_nd_add_param.algo());
}

void ScatterNdAddExecutor::paramGeneration() {
    xDesc_ = getInputDesc<tecoalTensorDescriptor_t>(0);
    x_ = dev_input[0];
    indexDesc_ = getInputDesc<tecoalTensorDescriptor_t>(1);
    index_ = dev_input[1];
    updatesDesc_ = getInputDesc<tecoalTensorDescriptor_t>(2);
    updates_ = dev_input[2];
    outDesc_ = getOutputDesc<tecoalTensorDescriptor_t>(0);
    out_ = dev_output[0];
}

void ScatterNdAddExecutor::compute() {
    checktecoal(tecoalScatterNdAdd(handle_, xDesc_, x_, indexDesc_, index_, updatesDesc_,
                                     updates_, outDesc_, out_, algo_));
}

int64_t ScatterNdAddExecutor::getTheoryOps() {
    int64_t theory_ops = parser_->input(0)->shape_count;
    return theory_ops;
}
int64_t ScatterNdAddExecutor::getTheoryIoSize() { return getIoSize(); }

void ScatterNdAddExecutor::cpuCompute() { pythonComputeCPU("cpu"); }
void ScatterNdAddExecutor::gpuCompute() { pythonComputeGPU("cuda"); }

}  // namespace optest
