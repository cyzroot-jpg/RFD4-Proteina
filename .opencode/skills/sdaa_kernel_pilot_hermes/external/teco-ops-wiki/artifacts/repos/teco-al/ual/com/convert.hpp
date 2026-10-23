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

#ifndef UAL_COM_CONVERT_HPP_
#define UAL_COM_CONVERT_HPP_

#include <stdexcept>
#include "ual/com/def.h"

namespace tecoal {
namespace ual {
namespace common {

static int inline convertAlgoToIndex(UALAlgoType type) {
    switch (type) {
        case UALAlgoType::UAL_ALGO_0: return 0;
        case UALAlgoType::UAL_ALGO_1: return 1;
        case UALAlgoType::UAL_ALGO_2: return 2;
        case UALAlgoType::UAL_ALGO_3: return 3;
        case UALAlgoType::UAL_ALGO_4: return 4;
        case UALAlgoType::UAL_ALGO_5: return 5;
        case UALAlgoType::UAL_ALGO_6: return 6;
        case UALAlgoType::UAL_ALGO_7: return 7;
        case UALAlgoType::UAL_ALGO_8: return 8;
        case UALAlgoType::UAL_ALGO_9: return 9;
        case UALAlgoType::UAL_ALGO_10: return 10;
        case UALAlgoType::UAL_ALGO_11: return 11;
        case UALAlgoType::UAL_ALGO_12: return 12;
        case UALAlgoType::UAL_ALGO_13: return 13;
        case UALAlgoType::UAL_ALGO_14: return 14;
        case UALAlgoType::UAL_ALGO_15: return 15;
        case UALAlgoType::UAL_ALGO_16: return 16;
        case UALAlgoType::UAL_ALGO_17: return 17;
        case UALAlgoType::UAL_ALGO_18: return 18;
        case UALAlgoType::UAL_ALGO_19: return 19;
        case UALAlgoType::UAL_ALGO_20: return 20;
        case UALAlgoType::UAL_ALGO_21: return 21;
        case UALAlgoType::UAL_ALGO_22: return 22;
        case UALAlgoType::UAL_ALGO_23: return 23;
        case UALAlgoType::UAL_ALGO_24: return 24;
        case UALAlgoType::UAL_ALGO_25: return 25;
        case UALAlgoType::UAL_ALGO_26: return 26;
        case UALAlgoType::UAL_ALGO_27: return 27;
        case UALAlgoType::UAL_ALGO_28: return 28;
        case UALAlgoType::UAL_ALGO_29: return 29;
        case UALAlgoType::UAL_ALGO_30: return 30;
        case UALAlgoType::UAL_ALGO_31: return 31;
        case UALAlgoType::UAL_ALGO_32: return 32;
        case UALAlgoType::UAL_ALGO_33: return 33;
        case UALAlgoType::UAL_ALGO_34: return 34;
        case UALAlgoType::UAL_ALGO_35: return 35;
        case UALAlgoType::UAL_ALGO_36: return 36;
        case UALAlgoType::UAL_ALGO_37: return 37;
        case UALAlgoType::UAL_ALGO_38: return 38;
        case UALAlgoType::UAL_ALGO_39: return 39;
        case UALAlgoType::UAL_ALGO_40: return 40;
        case UALAlgoType::UAL_ALGO_41: return 41;
        case UALAlgoType::UAL_ALGO_42: return 42;
        case UALAlgoType::UAL_ALGO_43: return 43;
        case UALAlgoType::UAL_ALGO_44: return 44;
        case UALAlgoType::UAL_ALGO_45: return 45;
        case UALAlgoType::UAL_ALGO_46: return 46;
        case UALAlgoType::UAL_ALGO_47: return 47;
        case UALAlgoType::UAL_ALGO_48: return 48;
        case UALAlgoType::UAL_ALGO_49: return 49;
        case UALAlgoType::UAL_ALGO_50: return 50;
        case UALAlgoType::UAL_ALGO_51: return 51;
        case UALAlgoType::UAL_ALGO_52: return 52;
        case UALAlgoType::UAL_ALGO_53: return 53;
        case UALAlgoType::UAL_ALGO_54: return 54;
        case UALAlgoType::UAL_ALGO_55: return 55;
        case UALAlgoType::UAL_ALGO_56: return 56;
        case UALAlgoType::UAL_ALGO_57: return 57;
        case UALAlgoType::UAL_ALGO_58: return 58;
        case UALAlgoType::UAL_ALGO_59: return 59;
        case UALAlgoType::UAL_ALGO_60: return 60;
        case UALAlgoType::UAL_ALGO_61: return 61;
        case UALAlgoType::UAL_ALGO_62: return 62;
        case UALAlgoType::UAL_ALGO_63: return 63;
        case UALAlgoType::UAL_ALGO_64: return 64;
        case UALAlgoType::UAL_ALGO_65: return 65;
        case UALAlgoType::UAL_ALGO_66: return 66;
        case UALAlgoType::UAL_ALGO_67: return 67;
        case UALAlgoType::UAL_ALGO_68: return 68;
        case UALAlgoType::UAL_ALGO_69: return 69;
        case UALAlgoType::UAL_ALGO_70: return 70;
        case UALAlgoType::UAL_ALGO_71: return 71;
        case UALAlgoType::UAL_ALGO_72: return 72;
        case UALAlgoType::UAL_ALGO_73: return 73;
        case UALAlgoType::UAL_ALGO_74: return 74;
        case UALAlgoType::UAL_ALGO_75: return 75;
        case UALAlgoType::UAL_ALGO_76: return 76;
        case UALAlgoType::UAL_ALGO_77: return 77;
        case UALAlgoType::UAL_ALGO_78: return 78;
        case UALAlgoType::UAL_ALGO_79: return 79;
        case UALAlgoType::UAL_ALGO_80: return 80;
        case UALAlgoType::UAL_ALGO_81: return 81;
        case UALAlgoType::UAL_ALGO_82: return 82;
        case UALAlgoType::UAL_ALGO_83: return 83;
        case UALAlgoType::UAL_ALGO_84: return 84;
        case UALAlgoType::UAL_ALGO_85: return 85;
        case UALAlgoType::UAL_ALGO_86: return 86;
        case UALAlgoType::UAL_ALGO_87: return 87;
        case UALAlgoType::UAL_ALGO_88: return 88;
        case UALAlgoType::UAL_ALGO_89: return 89;
        case UALAlgoType::UAL_ALGO_90: return 90;
        case UALAlgoType::UAL_ALGO_91: return 91;
        case UALAlgoType::UAL_ALGO_92: return 92;
        case UALAlgoType::UAL_ALGO_93: return 93;
        case UALAlgoType::UAL_ALGO_94: return 94;
        case UALAlgoType::UAL_ALGO_95: return 95;
        case UALAlgoType::UAL_ALGO_96: return 96;
        case UALAlgoType::UAL_ALGO_97: return 97;
        case UALAlgoType::UAL_ALGO_98: return 98;
        case UALAlgoType::UAL_ALGO_99: return 99;
        case UALAlgoType::UAL_ALGO_100: return 100;
        case UALAlgoType::UAL_ALGO_101: return 101;
        case UALAlgoType::UAL_ALGO_102: return 102;
        case UALAlgoType::UAL_ALGO_103: return 103;
        case UALAlgoType::UAL_ALGO_104: return 104;
        case UALAlgoType::UAL_ALGO_105: return 105;
        case UALAlgoType::UAL_ALGO_106: return 106;
        case UALAlgoType::UAL_ALGO_107: return 107;
        case UALAlgoType::UAL_ALGO_108: return 108;
        case UALAlgoType::UAL_ALGO_109: return 109;
        case UALAlgoType::UAL_ALGO_110: return 110;
        default: {
            throw std::runtime_error("UALAlgoType is not exist!\n");
        }
    }
}

}  // namespace common
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_COM_CONVERT_HPP_
