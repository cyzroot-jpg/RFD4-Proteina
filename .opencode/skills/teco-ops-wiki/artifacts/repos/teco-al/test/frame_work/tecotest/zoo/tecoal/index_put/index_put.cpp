#include "zoo/tecoal/index_put/index_put.h"
#include <stdio.h>
#include <iostream>
#include <string>
#include "zoo/tecoal/convert.h"
namespace optest {

void IndexPutExecutor::destroy() {
    free(indicesDesc_);
    scdaFree(indices_);
}

void IndexPutExecutor::paramCheck() {
    if (parser_->inputs().size() < 3) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }

    if (parser_->outputs().size() > 1) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }
}

void IndexPutExecutor::paramParse() {
    if (parser_->getProtoNode()->has_tecoal_param()) {
        auto index_put_param = parser_->getProtoNode()->tecoal_param().index_put_param();
        accumulate_ = index_put_param.accumulate();
        IndexPutNum_ = index_put_param.indexputnum();
        algo_ = convert::toTecoalAlgo(index_put_param.algo());
    } else {
        accumulate_ = true;
        IndexPutNum_ = parser_->inputs().size() - 2;
    }
}

void IndexPutExecutor::paramGeneration() {
    // [index, value, input,] [output]
    int value_no = IndexPutNum_ + 0;
    int input_no = IndexPutNum_ + 1;

    int indices_list_size = IndexPutNum_ * sizeof(void *);
    indicesDesc_ = (tecoalTensorDescriptor_t *)malloc(indices_list_size);
    void **host_indices = (void **)malloc(indices_list_size);
    scdaMalloc((void **)&indices_, indices_list_size);

    for (int i = 0; i < IndexPutNum_; i++) {
        indicesDesc_[i] = getInputDesc<tecoalTensorDescriptor_t>(i);
        host_indices[i] = dev_input[i];
    }
    scdaMemcpy(indices_, host_indices, indices_list_size, MemcpyHostToDevice);
    free(host_indices);

    valueDesc_ = getInputDesc<tecoalTensorDescriptor_t>(value_no);
    value_ = dev_input[value_no];

    outputDesc_ = getInputDesc<tecoalTensorDescriptor_t>(input_no);
    output_ = dev_input[input_no];
}

void IndexPutExecutor::compute() {
    checktecoal(tecoalIndexPut(handle_, IndexPutNum_, accumulate_, indicesDesc_, indices_,
                               valueDesc_, value_, outputDesc_, output_, outputDesc_, output_,
                               algo_));
}

int64_t IndexPutExecutor::getTheoryOps() {
    int64_t theory_ops = parser_->input(0)->shape_count;
    return theory_ops;
}

int64_t IndexPutExecutor::getTheoryIoSize() {
    // all indices + value
    int64_t total_size = parser_->input(0)->size_in_bytes * IndexPutNum_ +
                         parser_->input(IndexPutNum_)->size_in_bytes;

    if (parser_->input(0)->dtype == testpt::DTYPE_INT64) {
        // + output
        total_size += parser_->input(IndexPutNum_ + 1)->size_in_bytes;
    } else if (parser_->input(0)->dtype == testpt::DTYPE_BOOL) {
        int64_t count = 0;
        bool *indices = (bool *)(host_input[0]);
        for (size_t i = 0; i < parser_->input(0)->shape_count; i++) {
            if (indices[i]) count++;
        }
        // output
        total_size += parser_->input(IndexPutNum_ + 1)->size_in_bytes /
                      parser_->input(IndexPutNum_ + 1)->shape[0] * count;
    }
    return total_size;
}

void IndexPutExecutor::cpuCompute() { pythonComputeCPU("cpu"); }

}  // namespace optest
