#ifndef ZOO_TECOAL_INDEX_PUT_INDEX_PUT_H_  // NOLINT
#define ZOO_TECOAL_INDEX_PUT_INDEX_PUT_H_

#include "zoo/tecoal/executor.h"

namespace optest {

class IndexPutExecutor : public TecoalExecutor {
 public:
    IndexPutExecutor() {}
    ~IndexPutExecutor() {}

    void paramCheck();
    void paramParse();
    void paramGeneration();
    void compute();
    void cpuCompute();
    int64_t getTheoryOps() override;
    void destroy();
    int64_t getTheoryIoSize();

 private:
    int IndexPutNum_;
    tecoalTensorDescriptor_t *indicesDesc_;
    void **indices_;
    tecoalTensorDescriptor_t inputDesc_;
    void *input_;
    tecoalTensorDescriptor_t outputDesc_;
    void *output_;
    tecoalTensorDescriptor_t valueDesc_;
    void *value_;
    bool accumulate_;
    tecoalAlgo_t algo_;
};

}  // namespace optest

#endif  // ZOO_TECOAL_INDEX_PUT_INDEX_PUT_H_  // NOLINT
