#ifndef ZOO_TECOAL_ACTIVATION_BACKWARD_ACTIVATION_BACKWARD_H_  // NOLINT
#define ZOO_TECOAL_ACTIVATION_BACKWARD_ACTIVATION_BACKWARD_H_

#include <tecoal.h>
#include "zoo/tecoal/executor.h"

namespace optest {

class ActivationBackwardExecutor : public TecoalExecutor {
 public:
    ActivationBackwardExecutor() {}
    ~ActivationBackwardExecutor() {}

    void paramCheck();
    void paramParse();
    void paramGeneration();
    void compute();
    void cpuCompute();
    void gpuCompute();
    int64_t getTheoryOps() override;
    int64_t getTheoryIoSize() override;
    void forward();
    void destroy();

 private:
    tecoalActivationDescriptor_t activationDesc_;
    tecoalActivationMode_t mode_;
    float alpha_;
    tecoalTensorDescriptor_t yDesc_;
    void *y_;
    tecoalTensorDescriptor_t dyDesc_;
    void *dy_;
    tecoalTensorDescriptor_t xDesc_;
    void *x_;
    float beta_;
    tecoalTensorDescriptor_t dxDesc_;
    void *dx_;
    double coef_;
    tecoalAlgo_t algo_;
    tecoalNanPropagation_t nanopt_;
};
};  // namespace optest

#endif  // ZOO_TECOAL_ACTIVATION_BACKWARD_ACTIVATION_BACKWARD_H_  // NOLINT
