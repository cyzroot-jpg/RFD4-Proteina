---
id: doc-teco-al-docs-p04
title: "Teco-AL 项目文档集 — 第p04部分 (doc/op_docs/doc_template.md)"
type: source-doc-part
parent_doc: doc-teco-al-docs
product_version: "v1.0.0 / commit 17c5cd6"
source_file: "doc/op_docs/doc_template.md"
raw_text: "sources/docs/raw-teco-al/op_docs/doc_template.txt"
raw_line_range: "1-40"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-al, op-docs, design-doc-template]
---

# Teco-AL 项目文档集（第p04部分：算子设计文档模板）

# Teco-AL算子设计文档模板

## 计算原理

*主要提供这些信息：功能描述、计算公式、公式中的参数解释、计算图示（可选）。*

## 功能实现
### 接口设计

*结合当前算子的实际计算需求，参考cuda、pytorch、paddlepaddle等接口，进行userAPI设计。*

```c++
// userAPI design result
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|param_1| 输入/输出|主机端/设备端| 参数功能描述。 |
|param_2| 输入/输出|主机端/设备端|参数功能描述。 |
|...| 输入/输出|主机端/设备端| 参数功能描述。 |
|param_n| 输入/输出|主机端/设备端| 参数功能描述。 |


### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。
|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| param_1 | 当前功能支持状况 | 当前功能支持状况 | 当前功能支持状况 |
| ... | 当前功能支持状况 | 当前功能支持状况 | 当前功能支持状况 |

## 性能优化

*建议包含以下内容：*
1. 标明自己实现的具体计算分支
2. 优化设计说明：通过伪代码、图示等办法，描述自己设计并实现的性能优化办法，如数据分块、广播操作、流水设计等
3. 性能自测数据（测例路径 + tecotest的硬件时间均值）
