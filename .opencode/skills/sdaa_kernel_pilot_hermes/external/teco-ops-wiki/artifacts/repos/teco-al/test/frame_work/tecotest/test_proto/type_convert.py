# -*- coding: UTF-8 -*-

import re
import os

curr_path = os.path.dirname(os.path.abspath(__file__))

name_mode = "enum\s+(\w+)\s*{"
value_mode = "(\w+)\s*="
proto_file = [os.path.join(curr_path, "tecoal.proto")]
for path in os.listdir(os.path.join(curr_path, "tecoal")):
  if path.endswith("proto"):
    proto_file.append(os.path.join(os.path.join(curr_path,"tecoal"), path))
print(proto_file)

funcs = []
values =  []
def parse():
    lines = []
    for pro in proto_file:
        with open(pro) as f:
            lines.extend(f.readlines())

    flag = 0
    for line in lines:
        line = line.strip()
        if line.startswith("enum"):
            value = []
            flag = 1
            func_obj = re.search(name_mode, line.strip())
            if not func_obj:
                flag = 0
                continue
            funcs.append(func_obj.group(1))
        elif flag==1 and line.startswith("}"):
            values.append(value)
            flag = 0 
        elif flag==1:
            value_obj = re.search(value_mode, line.strip())
            if not value_obj:
                continue
            value.append(value_obj.group(1))

    assert len(funcs)==len(values), "error"


def convertWord(word):
    return re.sub( '(?<!^)(?=[A-Z])', '_', word).lower()

out_path = os.path.join(curr_path, "../zoo/tecoal")
out_file_h = os.path.join(out_path, "convert.h")
out_file_cpp = os.path.join(out_path, "convert.cpp")

h_header = """
#ifndef ZOO_DNN_CONVERT_H_  // NOLINT
#define ZOO_DNN_CONVERT_H_
#include "test_proto/optest.pb.h"
#include "zoo/tecozoo.h"
namespace optest {
namespace convert {
"""

h_dtype_layout = """
tecoalDataType_t toTecoalDataType(testpt::DataType dtype);
tecoalTensorFormat_t toTecoalFormat(testpt::TensorLayout layout);
"""


h_tail = """
}  // convert

}  // optest
#endif  // ZOO_DNN_CONVERT_H_  // NOLINT

"""


cpp_header = """
#include "zoo/tecoal/convert.h"
#include <string>
#include "common/cnlog.h"
namespace optest {
namespace convert {
"""

cpp_dtype_layout = """
tecoalDataType_t toTecoalDataType(testpt::DataType dtype) {
  switch (dtype) {
    case testpt::DTYPE_HALF:
      return TECOAL_DATA_HALF;
    case testpt::DTYPE_FLOAT:
      return TECOAL_DATA_FLOAT;
    case testpt::DTYPE_INT8:
      return TECOAL_DATA_INT8;
    case testpt::DTYPE_INT16:
      return TECOAL_DATA_INT16;
    case testpt::DTYPE_INT32:
      return TECOAL_DATA_INT32;
    case testpt::DTYPE_INT64:
      return TECOAL_DATA_INT64;
    case testpt::DTYPE_UINT8:
      return TECOAL_DATA_UINT8;
    case testpt::DTYPE_BOOL:
      return TECOAL_DATA_BOOL;
    case testpt::DTYPE_DOUBLE:
      return TECOAL_DATA_DOUBLE;
    case testpt::DTYPE_BFLOAT16:
      return TECOAL_DATA_BFLOAT16;
    case testpt::DTYPE_UINT16:
    case testpt::DTYPE_UINT32:
    case testpt::DTYPE_UINT64:
      ALLOG(ERROR) << "Don't support this dtype. Not supported now";
      throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
    default:
      ALLOG(ERROR) << "Don't support this dtype.";
      throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
  }
  return TECOAL_DATA_FLOAT;
}

tecoalTensorFormat_t toTecoalFormat(testpt::TensorLayout layout) {
  switch (layout) {
    case testpt::LAYOUT_NCHW:
      return TECOAL_TENSOR_NCHW;
    case testpt::LAYOUT_NHWC:
      return TECOAL_TENSOR_NHWC;
    case testpt::LAYOUT_CHWN:
      return TECOAL_TENSOR_CHWN;
    case testpt::LAYOUT_NWHC:
      return TECOAL_TENSOR_NWHC;
    case testpt::LAYOUT_ARRAY:
    case testpt::LAYOUT_HWCN:
    case testpt::LAYOUT_NDHWC:
      return TECOAL_TENSOR_NDHWC;
    case testpt::LAYOUT_NCDHW:
    case testpt::LAYOUT_CDHWN:
      return TECOAL_TENSOR_CDHWN;
    case testpt::LAYOUT_TNC:
    case testpt::LAYOUT_NTC:
    case testpt::LAYOUT_NLC:
    case testpt::LAYOUT_NC:
      ALLOG(ERROR) << "Don't support this layout. Not supported now";
      break;
    default:
      throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));
  }
  return TECOAL_TENSOR_NCHW;
}

"""

cpp_tail = """
}  // convert
}  // optest
    
"""

# enum IndicesType{
#     INIT_32BIT_INDICES = 0; // TECOAL_32BIT_INDICES
#     INIT_64BIT_INDICES = 1;
#     INIT_16BIT_INDICES = 2;
#     INIT_8BIT_INDICES = 3;
# } 


def tofile():
    h_file = open(out_file_h, "w")
    h_file.write(h_header)

    h_file.write(h_dtype_layout)

    for func in funcs:
        h_file.write("tecoal{}_t toDnn{}(testpt::{} {});\n".format(func, func, func, convertWord(func)))
    
    h_file.write(h_tail)
    h_file.close()


    cpp_file = open(out_file_cpp, "w")
    cpp_file.write(cpp_header)

    cpp_file.write(cpp_dtype_layout)

    for i in range(0, len(funcs)):
        func = funcs[i]
        value = values[i]
        cpp_file.write("tecoal{}_t toDnn{}(testpt::{} {}){{\n".format(func, func, func, convertWord(func)))
        cpp_file.write("  switch({}){{\n".format(convertWord(func)))
        for j in range(0, len(value)):
            if func == "IndicesType":
                cpp_file.write("    case testpt::{}: return TECOAL_{};\n".format(value[j], value[j][5:]))
            else:
                cpp_file.write("    case testpt::{}: return TECOAL_{};\n".format(value[j], value[j]))
        cpp_file.write("    default:\n")
        cpp_file.write("""      ALLOG(ERROR) << "Don't support this conv_mode.";\n""")
        cpp_file.write("""      throw std::invalid_argument(std::string(__FILE__) + " +" + std::to_string(__LINE__));\n""")
        cpp_file.write("  }\n")
        if func == "IndicesType":
            cpp_file.write("  return TECOAL_{};\n".format(value[0][5:]))
        else:
            cpp_file.write("  return TECOAL_{};\n".format(value[0]))
        cpp_file.write("}\n")
        cpp_file.write("\n")
    
    cpp_file.write(cpp_tail)
    cpp_file.close()

if __name__ == "__main__":
    parse()
    tofile()
