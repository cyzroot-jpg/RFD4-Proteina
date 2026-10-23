#include "zoo/tecoal/masked_select/masked_select.h"
#include <stdio.h>
#include <tecoal.h>
#include <iostream>
#include <string>
#include "zoo/tecoal/convert.h"

namespace optest {

void MaskedSelectExecutor::paramCheck() {
    if (parser_->inputs().size() != 3) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }

    if (parser_->outputs().size() != 1) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }
}

void MaskedSelectExecutor::paramParse() {
    auto masked_select_param = parser_->getProtoNode()->tecoal_param().masked_select_param();
    algo_ = convert::toTecoalAlgo(masked_select_param.algo());
}

void MaskedSelectExecutor::paramGeneration() {
    inputDesc_ = getInputDesc<tecoalTensorDescriptor_t>(0);
    input_ = dev_input[0];
    maskDesc_ = getInputDesc<tecoalTensorDescriptor_t>(1);
    mask_ = dev_input[1];
    outputDesc_ = getInputDesc<tecoalTensorDescriptor_t>(2);
    output_ = dev_input[2];
    selectCount_ = dev_output[0];
}

void MaskedSelectExecutor::compute() {
    checktecoal(tecoalMaskedSelect(handle_, inputDesc_, input_, maskDesc_, mask_, outputDesc_,
                                     output_, selectCount_, algo_));
}

int64_t MaskedSelectExecutor::getTheoryOps() {
    int64_t theory_ops = parser_->input(0)->shape_count;
    return theory_ops;
}

int64_t MaskedSelectExecutor::getTheoryIoSize() { return getIoSize(); }

void MaskedSelectExecutor::cpuCompute() { pythonComputeCPU("cpu"); }

}  // namespace optest
