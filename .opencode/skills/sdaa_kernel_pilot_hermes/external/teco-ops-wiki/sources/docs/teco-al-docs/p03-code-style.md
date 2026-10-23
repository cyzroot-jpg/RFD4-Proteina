---
id: doc-teco-al-docs-p03
title: "Teco-AL 项目文档集 — 第p03部分 (doc/tutorial/code_style.md)"
type: source-doc-part
parent_doc: doc-teco-al-docs
product_version: "v1.0.0 / commit 17c5cd6"
source_file: "doc/tutorial/code_style.md"
raw_text: "sources/docs/raw-teco-al/tutorial/code_style.txt"
raw_line_range: "1-14"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-al, code-style, cpplint, google-style]
---

# Teco-AL 项目文档集（第p03部分：编程规范）

## 规范原则
Teco-AL仓库为C++代码仓库，采用C++11标准，统一使用《Google C++ 风格》进行编码。

## 规范工具
用户在提交代码前，需要通过以下工具，对自己的代码进行自动化检查与处理。
|名称|说明|类别|
|---|---|---|
|cpplint|`pre_commit`脚本在用户每次`git commit`前，会自动进行cpplint检查。|自动触发执行|
|format2google|`format2google`脚本提供了自动规整代码的功能。例如在`teco-al`目录下，执行`./tools/format2google ./ual/kernel/add_tensor/add_tensor_ft16.scpp`命令，表示对`./ual/kernel/add_tensor/add_tensor_ft16.scpp`文件进行自动格式化操作。|用户手动执行|
