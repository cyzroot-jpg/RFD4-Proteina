#ifndef ZOO_TECOAL_MASKED_SELECT_MASKED_SELECT_H_  // NOLINT
#define ZOO_TECOAL_MASKED_SELECT_MASKED_SELECT_H_

#include <tecoal.h>
#include "zoo/tecoal/executor.h"

namespace optest {

class MaskedSelectExecutor : public TecoalExecutor {
 public:
    MaskedSelectExecutor() {}
    ~MaskedSelectExecutor() {}

    void paramCheck();
    void paramParse();
    void paramGeneration();
    void compute();
    void cpuCompute();
    int64_t getTheoryOps() override;
    int64_t getTheoryIoSize() override;

 private:
    tecoalTensorDescriptor_t inputDesc_;
    void *input_;
    tecoalTensorDescriptor_t maskDesc_;
    void *mask_;
    tecoalTensorDescriptor_t outputDesc_;
    void *output_;
    void *selectCount_;
    tecoalAlgo_t algo_;
};
};  // namespace optest

#endif  // ZOO_TECOAL_MASKED_SELECT_MASKED_SELECT_H_  // NOLINT
