# tecoalActivationForward设计文档


## 计算原理

对输入的张量x进行正向激活计算。

## 功能实现
### 接口设计

为了完成上述计算功能，可进行userAPI接口设计。

```c++
tecoalStatus_t TECOALWINAPI tecoalActivationForward(
    tecoalHandle_t                         handle,
    tecoalActivationDescriptor_t           activationDesc,
    const void                             *alpha,
    const tecoalTensorDescriptor_t         xDesc,
    const void                             *x,
    const void                             *beta,
    const tecoalTensorDescriptor_t         yDesc,
    void                                   *y,
    tecoalAlgo_t                           algo);
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|handle| 输入 | 主机端 | Teco-AL句柄。详见[《开发指南——核心概念——句柄》](../tutorial/dev_guide.md#句柄)章节的介绍。 |
|activationDesc| 输入 | 主机端 | 激活模式描述符。可以通过tecoalSetActivationDescriptor()中的tecoalActivationMode_t设置计算模式。 |
|alpha| 输入 | 主机端 | 指向缩放系数的指针，float32类型。 |
| xDesc  | 输入      | 主机端        | 数据x的描述符。详见[《开发指南——核心概念——描述符》](../tutorial/dev_guide.md#描述符)章节的介绍。                       |
| x      | 输入      | 设备端        | 指向xDesc描述的数据指针。                                            |
| beta   | 输入      | 主机端        | 指向缩放系数的指针，float32类型，与alpha一起用于融合先验结果并输出。 |
| yDesc  | 输入      | 主机端        | 数据y的描述符。详见[《开发指南——核心概念——描述符》](../tutorial/dev_guide.md#描述符)章节的介绍。                       |
| y      | 输入      | 设备端        | 指向yDesc描述的数据指针。                                            |
|algo| 输入 | 主机端 | 用于指定不同性能的实现算法，可选0~n整数。 |

针对`tecoalActivationMode_t`，不同取值含义如下：
|名称|说明|
|---|---|
|`TECOAL_ACTIVATION_SILU`|选择silu计算：$y=\frac{x}{1+e{^{-x}}} $ 并且 $dx=(1 + x * (1 - sigmoid(x))) * sigmoid(x) * dy$|


针对`algo`参数，不同取值含义如下：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelActivationForwardFT16|基础实现。|
|`TECOAL_ALGO_...`|赛题补充内容。|赛题补充内容。|
|`TECOAL_ALGO_n`|赛题补充内容。|赛题补充内容。|


### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。
|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| xDesc | float16 | Tensor4D | NHWC，NCHW，CHWN和NWHC |
| yDesc | float16 | Tensor4D | NHWC，NCHW，CHWN和NWHC |


## 性能优化

赛题补充内容：
1. 标明自己实现的具体计算分支
2. 优化设计说明
3. 性能自测数据（测例路径 + tecotest的硬件时间均值）


