// MIT License
// 
// Copyright (c) 2024, Tecorigin Co., Ltd.
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
 
#include <stdio.h>
#include <string.h>
// #include "swdnn.h"
// #include "swdnnCommonFunc.h"
#include "tecoal.pb.h"
// #include "optest.pb.h"

static void setTranspose_info(optestpt::TransposeParam *trans) {
  // swdnnHandle_t swdnnHandle;
  // checkSWDNN( swdnnCreate(&swdnnHandle) );

  float ALPHA = 1.0;
  float BETA = 1.1;
  // trans->handle = swdnnHandle;
  trans->alpha() == ALPHA;
  trans->beta() == BETA;
}

void printf_Transpose_info(optestpt::TransposeParam *trans) {
  printf("alpha:--%f--\n", trans->alpha());
  printf("beta:--%f--\n", trans->beta());
}

int main() {
  optestpt::TransposeParam *trans;
  // TransposeParam trans;
  setTranspose_info(trans);
  printf_Transpose_info(trans);
  return 0;
}
