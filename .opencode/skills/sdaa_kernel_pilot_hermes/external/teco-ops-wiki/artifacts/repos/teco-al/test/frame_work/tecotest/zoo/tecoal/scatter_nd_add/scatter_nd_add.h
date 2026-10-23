#ifndef ZOO_TECOAL_SCATTER_ND_ADD_SCATTER_ND_ADD_H_  // NOLINT
#define ZOO_TECOAL_SCATTER_ND_ADD_SCATTER_ND_ADD_H_

#include <tecoal.h>
#include "zoo/tecoal/executor.h"

namespace optest {

class ScatterNdAddExecutor : public TecoalExecutor {
 public:
    ScatterNdAddExecutor() {}
    ~ScatterNdAddExecutor() {}

    void paramCheck();
    void paramParse();
    void paramGeneration();
    void compute();
    void cpuCompute();
    void gpuCompute();
    int64_t getTheoryOps() override;
    int64_t getTheoryIoSize() override;

 private:
    tecoalTensorDescriptor_t xDesc_;
    void *x_;
    tecoalTensorDescriptor_t indexDesc_;
    void *index_;
    tecoalTensorDescriptor_t updatesDesc_;
    void *updates_;
    tecoalTensorDescriptor_t outDesc_;
    void *out_;
    tecoalAlgo_t algo_;
};
};  // namespace optest

#endif  // ZOO_TECOAL_SCATTER_ND_ADD_SCATTER_ND_ADD_H_  // NOLINT
