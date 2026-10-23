#ifndef ZOO_TECOAL_ACTIVATION_FORWARD_ACTIVATION_FORWARD_H_  // NOLINT
#define ZOO_TECOAL_ACTIVATION_FORWARD_ACTIVATION_FORWARD_H_

#include <tecoal.h>
#include "zoo/tecoal/executor.h"

namespace optest {

class ActivationForwardExecutor : public TecoalExecutor {
 public:
    ActivationForwardExecutor() {}
    ~ActivationForwardExecutor() {}

    void paramCheck();
    void paramParse();
    void paramGeneration();
    void compute();
    void cpuCompute();
    void gpuCompute();
    int64_t getTheoryOps() override;
    int64_t getTheoryIoSize() override;
    void destroy();

 private:
    tecoalActivationDescriptor_t activationDesc_;
    tecoalActivationMode_t mode_;
    float alpha_;
    tecoalTensorDescriptor_t xDesc_;
    void *x_;
    float beta_;
    tecoalTensorDescriptor_t yDesc_;
    void *y_;
    double coef_;
    tecoalAlgo_t algo_;
    tecoalNanPropagation_t nanopt_;
};
};  // namespace optest

#endif  // ZOO_TECOAL_ACTIVATION_FORWARD_ACTIVATION_FORWARD_H_  // NOLINT
