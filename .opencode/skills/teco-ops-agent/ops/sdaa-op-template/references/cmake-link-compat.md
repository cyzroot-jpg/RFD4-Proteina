# CMake / 链接兼容（cmake 4.x）

`swdnn_test_ops` 在 **CMake 4.x** 上需以下基线修复（子模块已含，脚手架文档供新建/同步参考）。

## 1. 最低版本

```cmake
cmake_minimum_required(VERSION 3.5)
```

CMake 4.x 已移除对 `< 3.5` 的兼容。

## 2. CMP0210（链接标志）

CMake 4 默认 NEW 策略可能吞掉 `CMAKE_CXX_LINK_FLAGS` 中的 `--sdaa-link`。

```cmake
if(POLICY CMP0210)
    cmake_policy(SET CMP0210 OLD)
endif()
```

## 3. 目标级 LINK_FLAGS

`.swcu.o` 需 tecocc 链接器识别：

```cmake
set_target_properties(${PROJECT_NAME} PROPERTIES
    LINKER_LANGUAGE CXX
    LINK_FLAGS "${TEST_CXX_FLAGS} --sdaa-link -shared -fuse-ld=lld")
```

否则报错类似：`file format not recognized`（针对 `.swcu.o`）。

## 4. 与 scope_cmake_op 的关系

`scope_cmake_op.py` 在 scope 时会自动调用 `cmake_baseline.py`（可用 `--no-cmake-baseline` 跳过）。

`torch_verify.py` 在未 scope 时也会在构建前跑 baseline。

`--restore` 会恢复 **scope 前** 的 `CMakeLists.txt` 备份；若备份较旧，restore 后请再执行：

```bash
python3 ops/sdaa-op-template/scripts/cmake_baseline.py --demo-root ./swdnn_test_ops
```

## 5. 独立 build 目录

```bash
BUILD_DIR=build_my_op ./run.sh my_op
```

避免旧 `build/` 中损坏的兄弟目标干扰增量编译。

## 6. 运行期库路径

```bash
LD_LIBRARY_PATH=build:$LD_LIBRARY_PATH build/test/my_op
```

`torch_verify.py --run` 会自动设置 `LD_LIBRARY_PATH`。
