// BSD 3- Clause License Copyright (c) 2024, Tecorigin Co., Ltd. All rights
// reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// Neither the name of the copyright holder nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY,OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)  ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
// OF SUCH DAMAGE.

#include <stdexcept>
#include "ual/com/def.h"
#include "interface/common/convert.h"

using namespace tecoal::ual::common;

namespace tecoal {
tecoalStatus_t Convert::toStatus(const Status status) {
    switch (status) {
        case Status::SUCCESS: return tecoalStatus_t::TECOAL_STATUS_SUCCESS;
        case Status::BAD_PARAMETER: return tecoalStatus_t::TECOAL_STATUS_BAD_PARAM;
        case Status::NOT_INITIALIZED: return tecoalStatus_t::TECOAL_STATUS_NOT_INITIALIZED;
        case Status::NOT_SUPPORTED: return tecoalStatus_t::TECOAL_STATUS_NOT_SUPPORTED;
        case Status::NO_IMPLEMENTATION: return tecoalStatus_t::TECOAL_STATUS_INTERNAL_ERROR;
        default: return tecoalStatus_t::TECOAL_STATUS_INTERNAL_ERROR;
    }
}

const char *Convert::toStatusStr(const Status status) {
    switch (status) {
        case Status::SUCCESS: return ("STATUS_SUCCESS");
        case Status::BAD_PARAMETER: return ("STATUS_BAD_PARAMENTR");
        case Status::NOT_INITIALIZED: return ("STATUS_NOT_INITIALOZED");
        case Status::NOT_SUPPORTED: return ("STATUS_NOT_SUPPORT");
        case Status::NO_IMPLEMENTATION: return ("STATUS_NO_IMPLEMENTATION");
        default: return ("status err");
    }
}

const char *Convert::toDataTypeStr(const tecoalDataType_t dataType) {
    switch (dataType) {
        case tecoalDataType_t::TECOAL_DATA_FLOAT: return ("TECOAL_DATA_FLOAT");
        case tecoalDataType_t::TECOAL_DATA_HALF: return ("TECOAL_DATA_HALF");
        case tecoalDataType_t::TECOAL_DATA_INT8: return ("TECOAL_DATA_INT8");
        case tecoalDataType_t::TECOAL_DATA_INT16: return ("TECOAL_DATA_INT16");
        case tecoalDataType_t::TECOAL_DATA_INT32: return ("TECOAL_DATA_INT32");
        default: return ("dataType err");
    }
}

UALDataType Convert::toUALDataType(const tecoalDataType_t data_type) {
    switch (data_type) {
        case tecoalDataType_t::TECOAL_DATA_INT8: return UALDataType::UAL_DTYPE_INT8;
        case tecoalDataType_t::TECOAL_DATA_INT16: return UALDataType::UAL_DTYPE_INT16;
        case tecoalDataType_t::TECOAL_DATA_INT32: return UALDataType::UAL_DTYPE_INT32;
        case tecoalDataType_t::TECOAL_DATA_INT64: return UALDataType::UAL_DTYPE_INT64;
        case tecoalDataType_t::TECOAL_DATA_FLOAT: return UALDataType::UAL_DTYPE_FLOAT;
        case tecoalDataType_t::TECOAL_DATA_HALF: return UALDataType::UAL_DTYPE_HALF;
        case tecoalDataType_t::TECOAL_DATA_DOUBLE: return UALDataType::UAL_DTYPE_DOUBLE;
        case tecoalDataType_t::TECOAL_DATA_BOOL: return UALDataType::UAL_DTYPE_BOOL;
        case tecoalDataType_t::TECOAL_DATA_UINT8: return UALDataType::UAL_DTYPE_UINT8;
        case tecoalDataType_t::TECOAL_DATA_BFLOAT16: return UALDataType::UAL_DTYPE_BFLOAT16;
        default: {
            throw std::runtime_error("tecoalDataType_t convert to UALDataType failed!");
        };
    }
}

UALOperation Convert::toUALOperation(const tecoalOperation_t trans_type) {
    switch (trans_type) {
        case TECOAL_OP_N: return UALOperation::UAL_OP_N;
        case TECOAL_OP_T: return UALOperation::UAL_OP_T;
        case TECOAL_OP_C: return UALOperation::UAL_OP_C;
        default: {
            throw std::runtime_error("tecoalOperation_t convert to UALOperation failed!");
        };
    }
}

UALAlgoType Convert::toUalAlgoType(const tecoalAlgo_t algo) {
    switch (algo) {
        case TECOAL_ALGO_0: return UALAlgoType::UAL_ALGO_0;
        case TECOAL_ALGO_1: return UALAlgoType::UAL_ALGO_1;
        case TECOAL_ALGO_2: return UALAlgoType::UAL_ALGO_2;
        case TECOAL_ALGO_3: return UALAlgoType::UAL_ALGO_3;
        case TECOAL_ALGO_4: return UALAlgoType::UAL_ALGO_4;
        case TECOAL_ALGO_5: return UALAlgoType::UAL_ALGO_5;
        case TECOAL_ALGO_6: return UALAlgoType::UAL_ALGO_6;
        case TECOAL_ALGO_7: return UALAlgoType::UAL_ALGO_7;
        case TECOAL_ALGO_8: return UALAlgoType::UAL_ALGO_8;
        case TECOAL_ALGO_9: return UALAlgoType::UAL_ALGO_9;
        case TECOAL_ALGO_10: return UALAlgoType::UAL_ALGO_10;
        case TECOAL_ALGO_11: return UALAlgoType::UAL_ALGO_11;
        case TECOAL_ALGO_12: return UALAlgoType::UAL_ALGO_12;
        case TECOAL_ALGO_13: return UALAlgoType::UAL_ALGO_13;
        case TECOAL_ALGO_14: return UALAlgoType::UAL_ALGO_14;
        case TECOAL_ALGO_15: return UALAlgoType::UAL_ALGO_15;
        case TECOAL_ALGO_16: return UALAlgoType::UAL_ALGO_16;
        case TECOAL_ALGO_17: return UALAlgoType::UAL_ALGO_17;
        case TECOAL_ALGO_18: return UALAlgoType::UAL_ALGO_18;
        case TECOAL_ALGO_19: return UALAlgoType::UAL_ALGO_19;
        case TECOAL_ALGO_20: return UALAlgoType::UAL_ALGO_20;
        case TECOAL_ALGO_21: return UALAlgoType::UAL_ALGO_21;
        case TECOAL_ALGO_22: return UALAlgoType::UAL_ALGO_22;
        case TECOAL_ALGO_23: return UALAlgoType::UAL_ALGO_23;
        case TECOAL_ALGO_24: return UALAlgoType::UAL_ALGO_24;
        case TECOAL_ALGO_25: return UALAlgoType::UAL_ALGO_25;
        case TECOAL_ALGO_26: return UALAlgoType::UAL_ALGO_26;
        case TECOAL_ALGO_27: return UALAlgoType::UAL_ALGO_27;
        case TECOAL_ALGO_28: return UALAlgoType::UAL_ALGO_28;
        case TECOAL_ALGO_29: return UALAlgoType::UAL_ALGO_29;
        case TECOAL_ALGO_30: return UALAlgoType::UAL_ALGO_30;
        case TECOAL_ALGO_31: return UALAlgoType::UAL_ALGO_31;
        case TECOAL_ALGO_32: return UALAlgoType::UAL_ALGO_32;
        case TECOAL_ALGO_33: return UALAlgoType::UAL_ALGO_33;
        case TECOAL_ALGO_34: return UALAlgoType::UAL_ALGO_34;
        case TECOAL_ALGO_35: return UALAlgoType::UAL_ALGO_35;
        case TECOAL_ALGO_36: return UALAlgoType::UAL_ALGO_36;
        case TECOAL_ALGO_37: return UALAlgoType::UAL_ALGO_37;
        case TECOAL_ALGO_38: return UALAlgoType::UAL_ALGO_38;
        case TECOAL_ALGO_39: return UALAlgoType::UAL_ALGO_39;
        case TECOAL_ALGO_40: return UALAlgoType::UAL_ALGO_40;
        case TECOAL_ALGO_41: return UALAlgoType::UAL_ALGO_41;
        case TECOAL_ALGO_42: return UALAlgoType::UAL_ALGO_42;
        case TECOAL_ALGO_43: return UALAlgoType::UAL_ALGO_43;
        case TECOAL_ALGO_44: return UALAlgoType::UAL_ALGO_44;
        case TECOAL_ALGO_45: return UALAlgoType::UAL_ALGO_45;
        case TECOAL_ALGO_46: return UALAlgoType::UAL_ALGO_46;
        case TECOAL_ALGO_47: return UALAlgoType::UAL_ALGO_47;
        case TECOAL_ALGO_48: return UALAlgoType::UAL_ALGO_48;
        case TECOAL_ALGO_49: return UALAlgoType::UAL_ALGO_49;
        case TECOAL_ALGO_50: return UALAlgoType::UAL_ALGO_50;
        case TECOAL_ALGO_51: return UALAlgoType::UAL_ALGO_51;
        case TECOAL_ALGO_52: return UALAlgoType::UAL_ALGO_52;
        case TECOAL_ALGO_53: return UALAlgoType::UAL_ALGO_53;
        case TECOAL_ALGO_54: return UALAlgoType::UAL_ALGO_54;
        case TECOAL_ALGO_55: return UALAlgoType::UAL_ALGO_55;
        case TECOAL_ALGO_56: return UALAlgoType::UAL_ALGO_56;
        case TECOAL_ALGO_57: return UALAlgoType::UAL_ALGO_57;
        case TECOAL_ALGO_58: return UALAlgoType::UAL_ALGO_58;
        case TECOAL_ALGO_59: return UALAlgoType::UAL_ALGO_59;
        case TECOAL_ALGO_60: return UALAlgoType::UAL_ALGO_60;
        case TECOAL_ALGO_61: return UALAlgoType::UAL_ALGO_61;
        case TECOAL_ALGO_62: return UALAlgoType::UAL_ALGO_62;
        case TECOAL_ALGO_63: return UALAlgoType::UAL_ALGO_63;
        case TECOAL_ALGO_64: return UALAlgoType::UAL_ALGO_64;
        case TECOAL_ALGO_65: return UALAlgoType::UAL_ALGO_65;
        case TECOAL_ALGO_66: return UALAlgoType::UAL_ALGO_66;
        case TECOAL_ALGO_67: return UALAlgoType::UAL_ALGO_67;
        case TECOAL_ALGO_68: return UALAlgoType::UAL_ALGO_68;
        case TECOAL_ALGO_69: return UALAlgoType::UAL_ALGO_69;
        case TECOAL_ALGO_70: return UALAlgoType::UAL_ALGO_70;
        case TECOAL_ALGO_71: return UALAlgoType::UAL_ALGO_71;
        case TECOAL_ALGO_72: return UALAlgoType::UAL_ALGO_72;
        case TECOAL_ALGO_73: return UALAlgoType::UAL_ALGO_73;
        case TECOAL_ALGO_74: return UALAlgoType::UAL_ALGO_74;
        case TECOAL_ALGO_75: return UALAlgoType::UAL_ALGO_75;
        case TECOAL_ALGO_76: return UALAlgoType::UAL_ALGO_76;
        case TECOAL_ALGO_77: return UALAlgoType::UAL_ALGO_77;
        case TECOAL_ALGO_78: return UALAlgoType::UAL_ALGO_78;
        case TECOAL_ALGO_79: return UALAlgoType::UAL_ALGO_79;
        case TECOAL_ALGO_80: return UALAlgoType::UAL_ALGO_80;
        case TECOAL_ALGO_81: return UALAlgoType::UAL_ALGO_81;
        case TECOAL_ALGO_82: return UALAlgoType::UAL_ALGO_82;
        case TECOAL_ALGO_83: return UALAlgoType::UAL_ALGO_83;
        case TECOAL_ALGO_84: return UALAlgoType::UAL_ALGO_84;
        case TECOAL_ALGO_85: return UALAlgoType::UAL_ALGO_85;
        case TECOAL_ALGO_86: return UALAlgoType::UAL_ALGO_86;
        case TECOAL_ALGO_87: return UALAlgoType::UAL_ALGO_87;
        case TECOAL_ALGO_88: return UALAlgoType::UAL_ALGO_88;
        case TECOAL_ALGO_89: return UALAlgoType::UAL_ALGO_89;
        case TECOAL_ALGO_90: return UALAlgoType::UAL_ALGO_90;
        case TECOAL_ALGO_91: return UALAlgoType::UAL_ALGO_91;
        case TECOAL_ALGO_92: return UALAlgoType::UAL_ALGO_92;
        case TECOAL_ALGO_93: return UALAlgoType::UAL_ALGO_93;
        case TECOAL_ALGO_94: return UALAlgoType::UAL_ALGO_94;
        case TECOAL_ALGO_95: return UALAlgoType::UAL_ALGO_95;
        case TECOAL_ALGO_96: return UALAlgoType::UAL_ALGO_96;
        case TECOAL_ALGO_97: return UALAlgoType::UAL_ALGO_97;
        case TECOAL_ALGO_98: return UALAlgoType::UAL_ALGO_98;
        case TECOAL_ALGO_99: return UALAlgoType::UAL_ALGO_99;
        case TECOAL_ALGO_100: return UALAlgoType::UAL_ALGO_100;
        case TECOAL_ALGO_101: return UALAlgoType::UAL_ALGO_101;
        case TECOAL_ALGO_102: return UALAlgoType::UAL_ALGO_102;
        case TECOAL_ALGO_103: return UALAlgoType::UAL_ALGO_103;
        case TECOAL_ALGO_104: return UALAlgoType::UAL_ALGO_104;
        case TECOAL_ALGO_105: return UALAlgoType::UAL_ALGO_105;
        case TECOAL_ALGO_106: return UALAlgoType::UAL_ALGO_106;
        case TECOAL_ALGO_107: return UALAlgoType::UAL_ALGO_107;
        case TECOAL_ALGO_108: return UALAlgoType::UAL_ALGO_108;
        case TECOAL_ALGO_109: return UALAlgoType::UAL_ALGO_109;
        case TECOAL_ALGO_110: return UALAlgoType::UAL_ALGO_110;
        default: {
            throw std::runtime_error("tecoalAlgo_t convert to UALAlgoType failed!");
        }
    }
}

UALUnaryOpsMode Convert::toUALUnaryOpsMode(const tecoalUnaryOpsMode_t mode) {
    switch (mode) {
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_LOG: return UALUnaryOpsMode::UAL_BATCH_LOG;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_EXP: return UALUnaryOpsMode::UAL_BATCH_EXP;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_SQRT: return UALUnaryOpsMode::UAL_BATCH_SQRT;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_RSQRT: return UALUnaryOpsMode::UAL_BATCH_RSQRT;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_SQUARE: return UALUnaryOpsMode::UAL_BATCH_SQUARE;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_SIN: return UALUnaryOpsMode::UAL_BATCH_SIN;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_COS: return UALUnaryOpsMode::UAL_BATCH_COS;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_TANH: return UALUnaryOpsMode::UAL_BATCH_TANH;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_CEIL: return UALUnaryOpsMode::UAL_BATCH_CEIL;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_FLOOR: return UALUnaryOpsMode::UAL_BATCH_FLOOR;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_FABS: return UALUnaryOpsMode::UAL_BATCH_FABS;
        case tecoalUnaryOpsMode_t::TECOAL_BATCH_ADD_A: return UALUnaryOpsMode::UAL_BATCH_ADD_A;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_SUB_A: return UALUnaryOpsMode::UAL_BATCH_SUB_A;
        case tecoalUnaryOpsMode_t::TECOAL_BATCH_MUL_A: return UALUnaryOpsMode::UAL_BATCH_MUL_A;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_DIV_A: return UALUnaryOpsMode::UAL_BATCH_DIV_A;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_RDIV: return UALUnaryOpsMode::UAL_BATCH_RDIV;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_POW: return UALUnaryOpsMode::UAL_BATCH_POW;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_S2H: return UALUnaryOpsMode::UAL_BATCH_S2H;
        // case tecoalUnaryOpsMode_t::TECOAL_BATCH_H2S: return UALUnaryOpsMode::UAL_BATCH_H2S;
        default: {
            throw std::runtime_error(
                "tecoalUnaryOpsMode_t convert to UALUnaryOpsMode failed, not exist tecoalUnaryOpsMode_t enum type!");  // NOLINT
        }
    }
}

unsigned int Convert::toDescDataTypeSize(const tecoalDataType_t data_type) {
    switch (data_type) {
        case tecoalDataType_t::TECOAL_DATA_INT8:
        case tecoalDataType_t::TECOAL_DATA_UINT8:
        case tecoalDataType_t::TECOAL_DATA_BOOL: {
            return sizeof(char);
        } break;
        case tecoalDataType_t::TECOAL_DATA_BFLOAT16:
        case tecoalDataType_t::TECOAL_DATA_HALF:
        case tecoalDataType_t::TECOAL_DATA_INT16: {
            return 2 * sizeof(char);
        } break;
        case tecoalDataType_t::TECOAL_DATA_FLOAT:
        case tecoalDataType_t::TECOAL_DATA_INT32: {
            return 4 * sizeof(char);
        } break;
        case tecoalDataType_t::TECOAL_DATA_INT64:
        case tecoalDataType_t::TECOAL_DATA_DOUBLE: {
            return 8 * sizeof(char);
        } break;
        default: {
            throw std::runtime_error("not exist tecoalDataType_t enum type!");
        } break;
    }
}
}  // namespace tecoal
