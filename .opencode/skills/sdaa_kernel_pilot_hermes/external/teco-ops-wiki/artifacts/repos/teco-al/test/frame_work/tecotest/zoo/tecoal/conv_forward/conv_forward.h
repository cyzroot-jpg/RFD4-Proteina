#ifndef ZOO_TECOAL_CONV_FORWARD_CONV_FORWARD_H_  // NOLINT
#define ZOO_TECOAL_CONV_FORWARD_CONV_FORWARD_H_

#include <tecoal.h>
#include "zoo/tecoal/executor.h"

namespace optest {

class ConvForwardExecutor : public TecoalExecutor {
 public:
    ConvForwardExecutor() {}
    ~ConvForwardExecutor() {}

    void paramCheck();
    void paramParse();
    void paramGeneration();
    void compute();
    void cpuCompute();
    void gpuCompute();
    int64_t getTheoryOps() override;
    int64_t getTheoryIoSize() override;
    void getWorkspaceSize();
    void destroy();

 private:
    float alpha_;
    tecoalTensorDescriptor_t xDesc_;
    void *x_;
    tecoalFilterDescriptor_t wDesc_;
    void *w_;
    float beta_;
    tecoalTensorDescriptor_t yDesc_;
    void *y_;
    tecoalConvolutionDescriptor_t convDesc_;
    // tecoalConvolutionFwdAlgo_t fwd_algo_;
    tecoalAlgo_t algo_;

    struct ConvolutionDescParam {
        int conv_dims = 2;
        int stride_h, stride_w;
        int padding_h, padding_w;
        int dilation_h, dilation_w;
        int pad_3d[3] = {1, 1, 1};
        int stride_3d[3] = {1, 1, 1};
        int dila_3d[3] = {1, 1, 1};
        int groups;
        tecoalConvolutionMode_t mode;
        tecoalDataType_t data_type;
        tecoalMathType_t math_type;
    };
    ConvolutionDescParam conv_desc_param_;
};
};  // namespace optest

#endif  // ZOO_TECOAL_CONV_FORWARD_CONV_FORWARD_H_  // NOLINT
