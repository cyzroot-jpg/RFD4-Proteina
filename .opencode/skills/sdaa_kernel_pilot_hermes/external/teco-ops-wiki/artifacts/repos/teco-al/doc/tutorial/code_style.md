# Teco-AL编程规范

## 规范原则
Teco-AL仓库为C++代码仓库，采用C++11标准，统一使用[《Google C++ 风格》](https://zh-google-styleguide.readthedocs.io/en/latest/google-cpp-styleguide/contents.html)进行编码，用户可以点击链接，查阅google规范详情。

## 规范工具
用户在提交代码前，需要通过以下工具，对自己的代码进行自动化检查与处理。
|名称|说明|类别|
|---|---|---|
|cpplint|[pre_commit](../../tools/pre-commit)脚本在用户每次`git commit`前，会自动进行cpplint检查。|自动触发执行|
|format2google|[format2google](../../tools/format2google)脚本提供了自动规整代码的功能。例如在`teco-al`目录下，执行`./tools/format2google ./ual/kernel/add_tensor/add_tensor_ft16.scpp`命令，表示对`./ual/kernel/add_tensor/add_tensor_ft16.scpp`文件进行自动格式化操作。|用户手动执行|



