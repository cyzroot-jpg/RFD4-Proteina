#ifndef ZOO_TECOAL_LOGICAL_NOT_TENSOR_LOGICAL_NOT_TENSOR_H_  // NOLINT
#define ZOO_TECOAL_LOGICAL_NOT_TENSOR_LOGICAL_NOT_TENSOR_H_

#include <tecoal.h>
#include "zoo/tecoal/executor.h"

namespace optest {

class LogicalNotTensorExecutor : public TecoalExecutor {
 public:
    LogicalNotTensorExecutor() {}
    ~LogicalNotTensorExecutor() {}

    void paramCheck();
    void paramParse();
    void paramGeneration();
    void compute();
    void cpuCompute();
    int64_t getTheoryOps() override;
    int64_t getTheoryIoSize() override;

 private:
    tecoalTensorDescriptor_t aDesc_;
    void *A_;
    tecoalTensorDescriptor_t cDesc_;
    void *C_;
    tecoalAlgo_t algo_;
};
};  // namespace optest

#endif  // ZOO_TECOAL_LOGICAL_NOT_TENSOR_LOGICAL_NOT_TENSOR_H_  // NOLINT
