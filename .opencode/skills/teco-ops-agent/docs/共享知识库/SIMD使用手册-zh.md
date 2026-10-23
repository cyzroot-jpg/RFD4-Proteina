# SDAA T1 SIMD 向量指令使用手册

> **适用平台**: 申威-AI (SW-AI) 处理器从核 / SDAA T1 SPE  
> **头文件**: `simd.h`
> **最后更新**: 2026-06-22  
> **整合来源**: simd.h 源码、申威-AI从核结构手册 v0.56、指令拍数与流水线派发表、SDAA T1 硬件架构文档

---

## 一、架构概述

### 1.1 SPE 微架构

SDAA T1 每个 SPE（从核）可按**双发射、双流水线的从核执行单元**理解，核心参数如下：

| 参数 | 值 |
|------|-----|
| 主频 | **2.5 GHz** |
| 执行模型 | **2译码-2发射-2写回**，P0/P1 双流水线 |
| 流水线 | **5级**: IF → ID → EX → MEM → WB |
| 流水线条数 | **2条**: P0（计算/ALU） + P1（访存/Load-Store） |
| 标量寄存器 | **r0~r31**, 各 64 bit |
| 向量寄存器 | **r32~r63**, 各 512 bit |
| LDM (本地数据存储) | **256 KB**, 伪双端口（Bank0 + Bank1 各 128KB） |
| 向量处理能力 | 每周期 **16×FP32** / **16×FP16** / **16×INT32** / **32×INT16** |

### 1.2 双发射模型

P0 和 P1 流水线**可以在同一周期并行发射**一条指令：

- **P0（计算管线）**: 整数/浮点向量运算、乘加、选择、整理、除法、平方根
- **P1（访存管线）**: LDM load/store、DMA/RMA、分支、同步

**关键优化原则**: 将 P0 计算指令和 P1 访存指令交错排布，利用双发射实现计算与访存重叠。

### 1.3 拍数使用口径

本文中的“拍数”是静态指令执行口径，只适合估算热点方向，不能单独证明真实性能瓶颈。实际 kernel 性能还会受寄存器依赖、双发射成功率、LDM Bank 冲突、DMA/RMA 等待、同步和 HBM 访存形态影响。

使用拍数时应遵守以下口径：

- P0/P1 拍数可用于判断计算或本地 LDM load/store 是否可能成为热点。
- DMA、RMA、主存访问、远程 LDM、同步和 ACE 的延迟不定，必须结合 profiler、cycle 计数、reply counter 或分段计时判断。
- 浮点除法和平方根共用执行子部件，且非完全流水；即使单条指令拍数已知，也要看热循环中的调用频率和依赖链。
- `simd.h` 中由 C 运算符实现的接口可能由编译器 lowering 成多条指令，不能只按表格里的同类硬件指令拍数估算。

---

## 二、向量数据类型

所有 SIMD 操作均基于以下向量类型，定义在 `simd.h` 中：

| 类型别名 | C 定义 | 宽度 | 元素数 | 元素类型 |
|----------|--------|------|--------|----------|
| `intv16` | `int __attribute__((ext_vector_type(16)))` | 512 bit | 16 | int32 |
| `uintv16` | `unsigned __attribute__((ext_vector_type(16)))` | 512 bit | 16 | uint32 |
| `shortv32` | `short __attribute__((ext_vector_type(32)))` | 512 bit | 32 | int16 |
| `ushortv32` | `unsigned short __attribute__((ext_vector_type(32)))` | 512 bit | 32 | uint16 |
| `floatv16` | `float __attribute__((ext_vector_type(16)))` | 512 bit | 16 | float32 |
| `halfv16` / `float16v16` | `_Float16 __attribute__((ext_vector_type(16)))` | 512 bit | 16 | float16 |

`halfv16` 在 C 类型层面是 16 个 FP16 lane，但仍映射到 T1 的 512-bit 向量寄存器文件。涉及 `VFLDH/VFSTH`、`VFCVTHS/VFCVTSH` 等指令时，硬件会在加载、转换或写回阶段进行扩展、截断或打包；不要简单按 `16 * 16 = 256 bit` 推断寄存器占用。

**命名约定**:
- 后缀 `h` (half): 对应 `shortv32` 或 `halfv16` 类型，元素为 16 位
- 后缀 `w` (word): 对应 `intv16` 或 `uintv16` 类型，元素为 32 位
- 后缀 `fs` (float single): 对应 `floatv16` 类型，FP32
- 后缀 `fh` (float half): 对应 `halfv16` 类型，FP16

---

## 三、寄存器文件

```
  0 ┌──────────────────────┐
    │  32×64 bit           │  r0 ~ r31: 通用标量寄存器
    │  标量寄存器           │
 31 └──────────────────────┘
    ┌──────────────────────────────────────────┐
 32 │                                          │
    │        32×512 bit 向量寄存器              │  r32 ~ r63: SIMD 向量寄存器
    │                                          │
 63 └──────────────────────────────────────────┘
```

- `r31` 恒为常数 0（读返回 0，写被忽略）
- 向量寄存器每周期可处理 16 个 FP32 / 16 个 INT32 / 32 个 INT16 元素

---

## 四、内存访问指令

### 4.1 对齐加载 (Aligned Load)

用于从 512-bit 对齐地址加载数据到向量寄存器。

| 函数 | 底层指令 | 说明 |
|------|----------|------|
| `simd_load(dst, src)` | `VLDW` | 对齐加载字向量/SP浮点向量（512bit） |
| `simd_load_widen(dst, src)` | — | 对齐加载并位宽扩展 |
| `simd_load_ext(dst, src)` | — | 对齐加载并扩展 |

**使用示例**:
```c
floatv16 v;
simd_load(v, ptr);   // 从对齐地址 ptr 加载 16 个 float
```

**硬件语义** (VLDW):
```
Vaddr ← {Rb + SEXT(disp)}
FOR i=0 TO 15:
    Vd[32*i+31 : 32*i] ← Memory[Vaddr + 4*i]
```
要求地址按 64 字节（512 bit）对齐，否则触发对齐异常。

### 4.2 非对齐加载 (Unaligned Load)

| 函数 | 底层指令 | 说明 |
|------|----------|------|
| `simd_load_u(dst, src)` | `VLDW_U` | 非对齐加载字向量 |
| `simd_loadu(dst, src)` | `VLDW_U` | 同上（变体） |
| `simd_load_u_ext(dst, src)` | — | 非对齐加载并扩展 |
| `simd_loadu_ext(dst, src)` | — | 同上 |
| `simd_loadu_widen(dst, src)` | — | 非对齐加载并位宽扩展 |

非对齐加载将地址强制对齐到 512-bit 边界后读取，然后通过 VCON 拼接得到正确数据。

工程建议：热循环主路径优先使用 64B 对齐的 `simd_load/simd_store`。`simd_loadu/simd_storeu` 主要作为非对齐边界、tail 或不规则地址的 fallback；如果手写 `VCON/simd_concat`，应把它视为更低层的显式拼接控制，不要再假定和 `simd_loadu` 的 codegen 完全相同。

### 4.3 对齐存储 (Aligned Store)

| 函数 | 底层指令 | 说明 |
|------|----------|------|
| `simd_store(src, dst)` | `VSTW` | 对齐存储字向量/SP浮点向量（512bit） |
| `simd_store_ext(src, dst)` | — | 对齐扩展存储 |
| `simd_store_narrow(src, dst)` | — | 对齐窄化存储 |

**硬件语义** (VSTW):
```
Vaddr ← {Rb + SEXT(disp)}
FOR i=0 TO 15:
    Memory[Vaddr + 4*i] ← Va[32*i+31 : 32*i]
```
要求地址按 64 字节对齐。

### 4.4 非对齐存储 (Unaligned Store)

| 函数 | 底层指令 | 说明 |
|------|----------|------|
| `simd_storeu(src, dst)` | `VSTW_U` | 非对齐存储字向量 |
| `simd_store_u(src, dst)` | `VSTW_U` | 同上（变体） |
| `simd_store_u_ext(src, dst)` | — | 非对齐扩展存储 |
| `simd_storeu_narrow(src, dst)` | — | 非对齐窄化存储 |

### 4.5 半精度/半字访存指令

| 函数 | 底层指令 | 说明 |
|------|----------|------|
| `VFLDH` | 0xd.0 | 装入 HP 浮点向量（16 个 FP16，扩展为 FP32 存入寄存器） |
| `VFSTH` | 0xd.1 | 存储 HP 浮点向量（16 个 FP32 寄存器元素截断为 FP16 存储） |
| `VLDH` | 0xd.4 | 装入 16 个半字整数，符号扩展为 32 位 |
| `VSTH` | 0xd.5 | 存储 16 个半字整数 |
| `VLDB` | 0xd.6 | 装入 32 个字节整数，符号扩展为 16 位 |
| `VSTB` | 0xd.7 | 存储 32 个字节整数 |

**注意**: VFLDH 装入时会将 HP 浮点的 5 位指数扩展为 8 位寄存器格式指数，尾数 0 扩展。VFSTH 存储时会忽略寄存器中 `<29:27>` 和 `<12:0>` 位。

### 4.6 访存指令拍数

| 指令 | 流水线 | 本地 LDM 拍数 | 主存/远程 LDM |
|------|--------|--------------|--------------|
| 标量 Load (LDW, LDL, FLDS 等) | P1 | ≥5 拍 | 延迟不定 |
| 标量 Store (STW, STL, FSTS 等) | P1 | ≥3 拍 | 延迟不定 |
| 向量 Load (VLDW, VLDH, VLDB 等) | P1 | ≥5 拍 | 延迟不定 |
| 向量 Store (VSTW, VSTH, VSTB 等) | P1 | ≥4 拍 | 延迟不定 |
| 非对齐向量 Load/Store | P1 | 同上 | 延迟不定 |

注意：上述拍数只覆盖本地 LDM 指令的静态下限。若地址指向主存、远程 LDM，或通过 DMA/RMA 间接搬运数据，延迟应按不定处理，并结合实际 wait 或 profiler 判断。

---

## 五、整数向量运算

### 5.1 算术运算

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vaddw(a, b)` | `VADDW` | `a + b` (16×int32) | P0 | 3 |
| `simd_vsubw(a, b)` | `VSUBW` | `a - b` (16×int32) | P0 | 3 |
| `simd_vmulw(a, b)` | `VMULW` | `a * b` (16×int32) | P0 | 3 |
| `simd_vdivw(a, b)` | — | `a / b` (16×int32) | P0 | 需看 lowering |
| `simd_modw(a, b)` | — | `a % b` (16×int32) | P0 | 需看 lowering |
| `simd_vaddh(a, b)` | `VADDH` | `a + b` (32×int16) | P0 | 3 |
| `simd_vsubh(a, b)` | `VSUBH` | `a - b` (32×int16) | P0 | 3 |
| `simd_vmulh(a, b)` | `VMULH` | `a * b` (32×int16) | P0 | 3 |
| `simd_vdivh(a, b)` | — | `a / b` (32×int16) | P0 | 需看 lowering |
| `simd_modh(a, b)` | — | `a % b` (32×int16) | P0 | 需看 lowering |

**硬件语义** (VADDW):
```
FOR i=0 TO 15:
    temp[32*i+31 : 32*i] ← Va[32*i+31 : 32*i] + Vb[32*i+31 : 32*i]
Vc ← temp
```
不产生整数算术异常。

注意：`simd_vdivw/simd_vdivh/simd_modw/simd_modh` 在 `simd.h` 中由 C `/`、`%` 运算符实现，不是指令拍数表中列出的独立向量除法硬件指令。性能分析时必须查看编译后的汇编或实际 cycle，不能按 `VADDW/VMULW` 的 3 拍类比。

### 5.2 整数乘加

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vmaw(a, b, c)` | `VMAW` | `a * b + c` (16×int32) | P0 | 3 |
| `simd_vnmaw(a, b, c)` | `VNMAW` | `-a * b + c` (16×int32) | P0 | 3 |
| `simd_vmah(a, b, c)` | `VMAH` | `a * b + c` (32×int16) | P0 | 3 |
| `simd_vnmah(a, b, c)` | `VNMAH` | `-a * b + c` (32×int16) | P0 | 3 |

### 5.3 整数比较

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vcmpeqw(a, b)` | `VCMPEQW` | `a == b` (16×int32) | P0 | 3 |
| `simd_vcmpnew(a, b)` | — | `a != b` (16×int32) | P0 | 3 |
| `simd_vcmpltw(a, b)` | `VCMPLTW` | `a < b` (16×int32) | P0 | 3 |
| `simd_vcmplew(a, b)` | `VCMPLEW` | `a <= b` (16×int32) | P0 | 3 |
| `simd_vcmpgtw(a, b)` | — | `a > b` (16×int32) | P0 | 3 |
| `simd_vcmpgew(a, b)` | — | `a >= b` (16×int32) | P0 | 3 |
| `simd_vcmpeqh(a, b)` | `VCMPEQH` | `a == b` (32×int16) | P0 | 3 |
| `simd_vcmpneh(a, b)` | — | `a != b` (32×int16) | P0 | 3 |
| `simd_vcmplth(a, b)` | `VCMPLTH` | `a < b` (32×int16) | P0 | 3 |
| `simd_vcmpleh(a, b)` | `VCMPLEH` | `a <= b` (32×int16) | P0 | 3 |
| `simd_vcmpgth(a, b)` | — | `a > b` (32×int16) | P0 | 3 |
| `simd_vcmpgeh(a, b)` | — | `a >= b` (32×int16) | P0 | 3 |

比较结果为全 1（真）或全 0（假），可直接用作后续 `simd_vseleqw` 等选择指令的掩码。

**标量立即数比较** (后缀 `i`):
| 函数 | 说明 |
|------|------|
| `simd_vcmpeqwi(a, const_int)` | 向量每个元素与标量比较 |
| `simd_vcmpltwi(a, const_int)` | 同上 |
| `simd_vcmplewi(a, const_int)` | 同上 |
| `simd_vcmpeqhi(a, const_short)` | 同上 |
| `simd_vcmplthi(a, const_short)` | 同上 |
| `simd_vcmplehi(a, const_short)` | 同上 |

### 5.4 整数位运算

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vandw(a, b)` | `VANDW` | `a & b` (按位与) | P0 | 3 |
| `simd_logic_andw(a, b)` | — | `a && b` (逻辑与) | P0 | 3 |
| `simd_vbicw(a, b)` | — | `a & ~b` (位清除) | P0 | 3 |
| `simd_vbisw(a, b)` | — | `a \| b` (按位或) | P0 | 3 |
| `simd_orw(a, b)` | — | `a \|\| b` (逻辑或) | P0 | 3 |
| `simd_vornotw(a, b)` | — | `a \| ~b` (或非) | P0 | 3 |
| `simd_vxorw(a, b)` | — | `a ^ b` (按位异或) | P0 | 3 |
| `simd_vnotw(a)` | — | `!a` (逻辑非) | P0 | 1 |
| `simd_bnotw(a)` | — | `~a` (按位非) | P0 | 1 |
| `simd_negw(a)` | — | `-a` (取负) | P0 | 3 |

半字版本 (`h` 后缀) 同理，操作数为 `shortv32`。

### 5.5 整数选择指令

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vseleqw(a, b, c)` | `VSELEQW` | `b == 0 ? a : c` (逐元素) | P0 | 1 |
| `simd_vselltw(a, b, c)` | `VSELLTW` | `b < 0 ? a : c` (逐元素) | P0 | 1 |
| `simd_vsellew(a, b, c)` | `VSELLEW` | `b <= 0 ? a : c` (逐元素) | P0 | 1 |
| `simd_vseleqh(...)` | `VSELEQH` | 同上 (shortv32) | P0 | 1 |
| `simd_vsellth(...)` | `VSELLTH` | 同上 (shortv32) | P0 | 1 |
| `simd_vselleh(...)` | `VSELLEH` | 同上 (shortv32) | P0 | 1 |

**硬件语义** (VSELEQW):
```
FOR i=0 TO 15:
    IF Vb[32*i+31 : 32*i] == 0:
        Vd[32*i+31 : 32*i] ← Va[32*i+31 : 32*i]
    ELSE:
        Vd[32*i+31 : 32*i] ← Vc[32*i+31 : 32*i]
```

---

## 六、浮点向量运算

### 6.1 FP32 算术运算

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vfadds(a, b)` | `VFADDS` | `a + b` (16×FP32) | P0 | **5** |
| `simd_vfsubs(a, b)` | `VFSUBS` | `a - b` (16×FP32) | P0 | **5** |
| `simd_vfmuls(a, b)` | `VFMULS` | `a * b` (16×FP32) | P0 | **5** |
| `simd_vfdivs(a, b)` | — | `a / b` (16×FP32) | P0 | 需看 lowering |

**硬件语义** (VFADDS):
```
FOR i=0 TO 15:
    temp[32*i+31 : 32*i] ← Va[32*i+31 : 32*i] + Vb[32*i+31 : 32*i]
Vc ← temp
```
异常: 无效操作、上溢、下溢、非精确结果、非规格化数异常。

### 6.2 FP16 算术运算

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vfaddh(a, b)` | — | `a + b` (16×FP16) | P0 | 5 |
| `simd_vfsubh(a, b)` | — | `a - b` (16×FP16) | P0 | 5 |
| `simd_vfmulh(a, b)` | — | `a * b` (16×FP16) | P0 | 5 |
| `simd_vfdivh(a, b)` | — | `a / b` (16×FP16) | P0 | 需看 lowering |

注意：`simd_vfdivs/simd_vfdivh` 在 `simd.h` 中也是 C `/` 运算符封装。若编译器 lowering 到标量或库函数路径，代价可能远高于普通向量加/乘；需要通过汇编和实测确认。标量 `FDIVS/FSQRTS` 约 19/18 拍且非完全流水，不能把普通向量 FP32 算术 5 拍直接套到除法上。

### 6.3 FP32 比较

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vfcmpeqs(a, b)` | `VFCMPEQS` | `a == b` | P0 | **5** |
| `simd_vfcmpnes(a, b)` | — | `a != b` | P0 | 5 |
| `simd_vfcmplts(a, b)` | `VFCMPLTS` | `a < b` | P0 | **5** |
| `simd_vfcmples(a, b)` | `VFCMPLES` | `a <= b` | P0 | **5** |
| `simd_fcmpgts(a, b)` | — | `a > b` | P0 | 5 |
| `simd_vfcmpges(a, b)` | — | `a >= b` | P0 | 5 |
| `simd_vfcmpuns(a, b)` | `VFCMPUNS` | 不可排序比较 (NaN检测) | P0 | **5** |
| `simd_vfcmpeqsi(a, const_float)` | — | 与标量比较 | P0 | 5 |

**硬件语义** (VFCMPEQS):
```
FOR i=0 TO 15:
    IF Va[32*i+31 : 32*i] == Vb[32*i+31 : 32*i]:
        Vc[32*i+31 : 32*i] ← 0xFFFFFFFF
    ELSE:
        Vc[32*i+31 : 32*i] ← 0x00000000
```
VFCMPUNS 用于检测 NaN：当任一操作数为 NaN 时返回真。

### 6.4 FP16 比较

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vfcmpeqh(a, b)` | — | `a == b` (16×FP16) | P0 | 5 |
| `simd_vfcmpneh(a, b)` | — | `a != b` (16×FP16) | P0 | 5 |
| `simd_vfcmplth(a, b)` | — | `a < b` (16×FP16) | P0 | 5 |
| `simd_vfcmpleh(a, b)` | — | `a <= b` (16×FP16) | P0 | 5 |
| `simd_fcmpgth(a, b)` | — | `a > b` (16×FP16) | P0 | 5 |
| `simd_vfcmpgeh(a, b)` | — | `a >= b` (16×FP16) | P0 | 5 |
| `simd_vfcmpunh(a, b)` | `VFCMPUNH` | NaN检测 (FP16) | P0 | 5 |
| `simd_vfcmpeqhi(a, const_half)` | — | 与标量比较 | P0 | 5 |

### 6.5 浮点符号拷贝

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vfcpyss(a, b)` | `VFCPYSS` | 拷贝 b 的符号位到 a | P0 | **1** |
| `simd_vfcpyses(a, b)` | `VFCPYSES` | 拷贝 b 的符号和指数到 a | P0 | **1** |
| `simd_vfcpysns(a, b)` | `VFCPYSNS` | 拷贝 b 的符号位取反到 a | P0 | **1** |
| `simd_vfcpysh(a, b)` | `VFCPYSH` | 同上 (FP16) | P0 | 1 |
| `simd_vfcpyseh(a, b)` | `VFCPYSEH` | 同上 (FP16) | P0 | 1 |
| `simd_vfcpysnh(a, b)` | `VFCPYSNH` | 同上 (FP16) | P0 | 1 |

### 6.6 浮点选择指令

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vfseleqs(a, b, c)` | `VFSELEQS` | `b == 0 ? a : c` (逐元素 FP32) | P0 | **1** |
| `simd_vfsellts(a, b, c)` | `VFSELLTS` | `b < 0 ? a : c` (逐元素 FP32) | P0 | **1** |
| `simd_vfselles(a, b, c)` | `VFSELLES` | `b <= 0 ? a : c` (逐元素 FP32) | P0 | **1** |
| `simd_vfseleqh(...)` | `VFSELEQH` | 同上 (FP16) | P0 | 1 |
| `simd_vfsellth(...)` | `VFSELLTH` | 同上 (FP16) | P0 | 1 |
| `simd_vfselleh(...)` | `VFSELLEH` | 同上 (FP16) | P0 | 1 |

**硬件语义** (VFSELEQS):
```
FOR i=0 TO 15:
    IF Vb[32*i+31 : 32*i] == 0:
        Vd[32*i+31 : 32*i] ← Va[32*i+31 : 32*i]
    ELSE:
        Vd[32*i+31 : 32*i] ← Vc[32*i+31 : 32*i]
```

### 6.7 浮点乘加融合 (FMA)

FMA 指令一次完成乘法和加法，中间结果不进行舍入，只对最终结果舍入，精度更高。

| 函数 | 底层指令 | 公式 | 精度 | 流水线 | 拍数 |
|------|----------|------|------|--------|------|
| `simd_vfmas(a, b, c)` | `VFMAS` | `a × b + c` | FP32 | P0 | **5** |
| `simd_vfmss(a, b, c)` | `VFMSS` | `a × b - c` | FP32 | P0 | **5** |
| `simd_vfnmas(a, b, c)` | `VFNMAS` | `-a × b + c` | FP32 | P0 | **5** |
| `simd_vfnmss(a, b, c)` | `VFNMSS` | `-a × b - c` | FP32 | P0 | **5** |
| `simd_vfmah(a, b, c)` | — | `a × b + c` | FP16 | P0 | 5 |
| `simd_vfmsh(a, b, c)` | — | `a × b - c` | FP16 | P0 | 5 |
| `simd_vfnmah(a, b, c)` | — | `-a × b + c` | FP16 | P0 | 5 |
| `simd_vfnmsh(a, b, c)` | — | `-a × b - c` | FP16 | P0 | 5 |

**硬件语义** (VFMAS):
```
FOR i=0 TO 15:
    temp[32*i+31 : 32*i] ← Va[32*i+31 : 32*i] × Vb[32*i+31 : 32*i] + Vc[32*i+31 : 32*i]
Vd ← temp
```
不对中间乘积进行舍入和溢出检查，只对最终结果进行舍入和检查。

### 6.8 浮点绝对值

| 函数 | 底层 builtin | 操作 | 流水线 | 拍数 |
|------|-------------|------|--------|------|
| `simd_private_vfabs(a)` | `__builtin_sw_slave_vfabs` | `|a|` (16×FP32) | P0 | 1 |

### 6.9 Private 浮点比较函数 (FP32)

以下 `private` 前缀函数使用硬件 builtin 直接实现，与 C 运算符版本（`simd_vfcmpeqs` 等）的区别在于**严格遵循硬件指令语义**（如 NaN 处理、非规格化数行为）。C 运算符版本由编译器映射为 `==`、`<=`、`<` 运算符，可能在某些边界情况与硬件语义不一致。对精度和一致性要求高的场景建议使用 private 版本。

| 函数 | 底层 builtin | 操作 | 流水线 | 拍数 |
|------|-------------|------|--------|------|
| `simd_private_vfcmpeqs(a, b)` | `__builtin_sw_slave_vfcmpeqs` | `a == b` (16×FP32, 硬件语义) | P0 | 5 |
| `simd_private_vfcmples(a, b)` | `__builtin_sw_slave_vfcmples` | `a <= b` (16×FP32, 硬件语义) | P0 | 5 |
| `simd_private_vfcmplts(a, b)` | `__builtin_sw_slave_vfcmplts` | `a < b` (16×FP32, 硬件语义) | P0 | 5 |

**与公开版本的对比**:

| 公开版本 | private 版本 | 实现方式 |
|----------|-------------|----------|
| `simd_vfcmpeqs(a, b)` | `simd_private_vfcmpeqs(a, b)` | C `==` vs `__builtin_sw_slave_vfcmpeqs` |
| `simd_vfcmples(a, b)` | `simd_private_vfcmples(a, b)` | C `<=` vs `__builtin_sw_slave_vfcmples` |
| `simd_vfcmplts(a, b)` | `simd_private_vfcmplts(a, b)` | C `<` vs `__builtin_sw_slave_vfcmplts` |

> **注意**: 公开版本 `simd_vfcmpeqs` 等函数在 `simd.h` 的 `#if 0` 预处理块中另有 builtin 版本定义，当前生效的是 C 运算符版本。FP16 比较没有对应的 private 版本。

### 6.10 浮点除法/平方根 (标量)

| 指令 | 操作 | 流水线 | 拍数 | 备注 |
|------|------|--------|------|------|
| `FDIVS` | FP32 标量除法 | P0 | ~19 | 除法/平方根共用执行子部件 |
| `FDIVD` | FP64 标量除法 | P0 | ~34 | 同上 |
| `FSQRTS` | FP32 标量平方根 | P0 | ~18 | 同上 |
| `FSQRTD` | FP64 标量平方根 | P0 | ~32 | 同上 |

**重要**: 除法和平方根共用同一个执行子部件，且**非完全流水**。存在除法/平方根指令时，后续依赖指令需要等待。部分流水场景下可提前 4 拍发射下一条。

---

## 七、类型转换指令

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vfcvtsh(a)` | `VFCVTSH` | FP32→FP16 (16 元素) | P0 | **2** |
| `simd_vfcvths(a)` | `VFCVTHS` | FP16→FP32 (16 元素) | P0 | **2** |
| `simd_pseudo_vfcvtsh(a)` | — | FP32→FP16 (伪转换，不处理非规格化数) | P0 | 2 |
| `simd_pseudo_vfcvths(a)` | — | FP16→FP32 (伪转换) | P0 | 2 |

**硬件语义** (VFCVTSH):
```
Vc[255:0] ← 将 Vb 中 16 个 FP32 元素转换为 FP16，存入 Vc 低 256 位
```
注意: FP16 转换可能丢失非规格化数精度。如果对精度敏感，建议使用 `pseudo` 版本或手动做 BF16 截断。

---

## 八、特殊整理指令

### 8.1 向量拼接 (VCON)

将两个向量按指定位移拼接成新向量。通常与不对界加载配合使用。

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vconw(va, vb, n)` | `VCONW` | 字向量拼接 (intv16) | P0 | **3** |
| `simd_vconh(va, vb, n)` | `VCONH` | 半字向量拼接 (shortv32) | P0 | **3** |
| `simd_vconfs(va, vb, n)` | — | SP浮点向量拼接 (floatv16) | P0 | 3 |
| `simd_vconfh(va, vb, n)` | — | HP浮点向量拼接 (halfv16) | P0 | 3 |

**参数**:
- `va`: 高段数据（不对界加载的高地址部分）
- `vb`: 低段数据（不对界加载的低地址部分）
- `n`: 不对界地址的低 6 位（忽略低 2 位用于字拼接，忽略低 1 位用于半字拼接）

**硬件语义** (VCONW):
```
Byte4_len ← Rc[5:0] >> 2    // 以 4 字节为单位
FOR i=0 TO 15:
    IF i < Byte4_len:
        Vd[32*(i+(16-Byte4_len))+31 : 32*(i+(16-Byte4_len))] ← Va[32*i+31 : 32*i]
    ELSE:
        Vd[32*(i-Byte4_len)+31 : 32*(i-Byte4_len)] ← Vb[32*i+31 : 32*i]
```

**使用示例**:
```c
// 手写非对齐加载拼接：先读取 64B 对齐的低/高段，再用 VCON 拼出目标窗口
intv16 low, high, result;
uintptr_t aligned_addr = addr & ~0x3FULL;
simd_load(low, (const int*)aligned_addr);          // 加载对齐低段
simd_load(high, (const int*)(aligned_addr + 64));  // 加载对齐高段
result = simd_vconw(high, low, (void*)(uintptr_t)(addr & 0x3F));  // 拼接
```

### 8.2 向量元素插入 (VINS)

将标量插入向量指定位置。

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vinsw(ra, va, n)` | `VINSW` | 插入 int 到 intv16 第 n 位 | P0 | **3** |
| `simd_vinsh(ra, va, n)` | `VINSH` | 插入 short 到 shortv32 第 n 位 | P0 | **3** |
| `simd_vinsfs(ra, va, n)` | `VFINSS` | 插入 float 到 floatv16 第 n 位 | P0 | **3** |
| `simd_vinshf(ra, va, n)` | — | 插入 _Float16 到 halfv16 第 n 位 | P0 | 3 |

**参数**:
- `ra`: 标量值（int/short/float/_Float16）
- `va`: 目标向量
- `n`: 插入位置索引（0-15 对应 intv16/floatv16/halfv16，0-31 对应 shortv32）

**硬件语义** (VINSW):
```
FOR i=0 TO 15:
    IF i == #c[3:0]:
        Vd[32*i+31 : 32*i] ← Ra[31:0]
    ELSE:
        Vd[32*i+31 : 32*i] ← Vb[32*i+31 : 32*i]
```

### 8.3 向量元素提取 (VEXT)

从向量指定位置提取标量。

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vextw(va, n)` | `VEXTW` | 提取 intv16 第 n 个 int | P0 | **3** |
| `simd_vexth(va, n)` | `VEXTH` | 提取 shortv32 第 n 个 short | P0 | **3** |
| `simd_vextfs(va, n)` | `VFEXTS` | 提取 floatv16 第 n 个 float | P0 | **3** |
| `simd_vextfh(va, n)` | `VFEXTH` | 提取 halfv16 第 n 个 _Float16 | P0 | 3 |

**参数**:
- `va`: 源向量
- `n`: 提取位置索引

**硬件语义** (VEXTW):
```
FOR i=0 TO 15:
    IF i == #c[3:0]:
        Rd[63:0] ← SEXT(Vb[32*i+31 : 32*i])   // 符号扩展到 64 位
```

### 8.4 标量广播 (VCPY)

将标量复制到向量的所有元素。

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vcpyw(val)` | `VCPYW` | 广播 int 到 intv16 所有元素 | P0 | **3** |
| `simd_vcpyh(val)` | `VCPYH` | 广播 short 到 shortv32 所有元素 | P0 | **3** |
| `simd_vcpyfs(val)` | `VFCPYS` | 广播 float 到 floatv16 所有元素 | P0 | **3** |
| `simd_vcpyfh(val)` | `VFCPYH` | 广播 _Float16 到 halfv16 所有元素 | P0 | 3 |

**硬件语义** (VCPYW):
```
FOR i=0 TO 15:
    Vd[32*i+31 : 32*i] ← Ra[31:0]
```

### 8.5 查找表/对数指令

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_vlog2xi` | `VLOG2X` | 以2为底的对数近似 | P0 | 1 |
| `simd_vlog2xi_i` | — | 同上 (立即数变体) | P0 | 1 |
| `simd_vlog3ri` | `VLOG3R` | 对数/指数运算 | P0 | 1 |

---

## 九、归约操作

| 函数 | 底层指令 | 返回类型 | 操作 | 流水线 | 拍数 |
|------|----------|----------|------|--------|------|
| `simd_reduc_plush(a)` | `REDUC_PLUS_V32HI` | `short` | 32×int16 求和 | P0 | 3 |
| `simd_reduc_plusw(a)` | `REDUC_PLUS_V16SI` | `int` | 16×int32 求和 | P0 | 3 |
| `simd_reduc_plusfh(a)` | `REDUC_PLUS_V16HF` | `_Float16` | 16×FP16 求和 | P0 | 5 |
| `simd_reduc_plusfs(a)` | `REDUC_PLUS_V16SF` | `float` | 16×FP32 求和 | P0 | 5 |

**使用示例**:
```c
floatv16 v = simd_set_floatv16(1.0f, 2.0f, ...);  // 16 个 float
float sum = simd_reduc_plusfs(v);                    // 标量求和结果
```

---

## 十、浮点最大/最小值

| 函数 | 底层指令 | 操作 | 流水线 | 拍数 |
|------|----------|------|--------|------|
| `simd_smaxs(a, b)` | — | 逐元素 FP32 max | P0 | 5 |
| `simd_smins(a, b)` | — | 逐元素 FP32 min | P0 | 5 |
| `simd_smaxh(a, b)` | — | 逐元素 FP16 max | P0 | 5 |
| `simd_sminh(a, b)` | — | 逐元素 FP16 min | P0 | 5 |

---

## 十一、泛型宏

`simd.h` 提供了基于 `_Generic` 的泛型宏，可根据操作数类型自动选择对应函数。**推荐在 C 代码中使用这些宏以简化代码**。

### 算术运算泛型

```c
#define simd_add(va, vb)   // → simd_vfadds / simd_vfaddh / simd_vaddw / simd_vaddh
#define simd_sub(va, vb)   // → simd_vfsubs / simd_vfsubh / simd_vsubw / simd_vsubh
#define simd_mul(va, vb)   // → simd_vfmuls / simd_vfmulh / simd_vmulw / simd_vmulh
#define simd_div(va, vb)   // → simd_vfdivs / simd_vfdivh / simd_vdivw / simd_vdivh
#define simd_rem(va, vb)   // → simd_modw / simd_modh
```

### 比较泛型

```c
#define simd_cmplt(va, vb)  // 小于
#define simd_cmple(va, vb)  // 小于等于
#define simd_cmpgt(va, vb)  // 大于
#define simd_cmpge(va, vb)  // 大于等于
#define simd_cmpeq(va, vb)  // 等于 (支持标量右操作数)
#define simd_cmpne(va, vb)  // 不等于
```

### 位运算泛型

```c
#define simd_band(va, vb)  // 按位与
#define simd_and(va, vb)   // 逻辑与
#define simd_bxor(va, vb)  // 按位异或
#define simd_bor(va, vb)   // 按位或
#define simd_or(va, vb)    // 逻辑或
#define simd_bnor(va, vb)  // 按位或非
```

### 单目运算泛型

```c
#define simd_not(va)   // 逻辑非
#define simd_bnot(va)  // 按位非
#define simd_neg(va)   // 取负
#define simd_redsum(va) // 归约求和
#define simd_max(va, vb) // 浮点最大值 (half/float)
#define simd_min(va, vb) // 浮点最小值 (half/float)
#define simd_isnan(va)   // NaN 检测
```

---

## 十二、向量构造与调试

### 12.1 向量构造

```c
// 用 16 个标量构造 intv16
intv16 simd_set_intv16(int K, int L, ..., int Z);

// 用 32 个标量构造 shortv32
shortv32 simd_set_shortv32(short a0, short a1, ..., short a31);

// 用 16 个标量构造 floatv16
floatv16 simd_set_floatv16(float K, float L, ..., float Z);

// 用 16 个标量构造 halfv16
float16v16 simd_set_float16v16(_Float16 K, ..., _Float16 Z);
```

### 12.2 调试打印

```c
simd_print_intv16(v);       // 十进制打印 intv16
simd_print_intv16_X(v);     // 十六进制打印 intv16
simd_print_floatv16(v);     // 科学计数法打印 floatv16
simd_print_floatv16_X(v);   // 十六进制打印 floatv16 (查看原始位)
simd_print_shortv32(v);     // 十进制打印 shortv32
simd_print_float16v16(v);   // 科学计数法打印 halfv16
```

---

## 十三、C++ 高层封装

当使用 C++ 编译器时，`simd.h` 提供了重载的简化接口：

| 函数 | 功能 | 支持类型 |
|------|------|----------|
| `simd_stretch(scalar)` | 标量广播到向量 | int, short, float, half |
| `simd_seleq(va, vb, vc)` | 按相等选择 | intv16, shortv32, floatv16, halfv16 |
| `simd_selle(va, vb, vc)` | 按 <= 选择 | 同上 |
| `simd_sellt(va, vb, vc)` | 按 < 选择 | 同上 |
| `simd_ins(ra, va, n)` | 标量插入向量 | short, int, half, float |
| `simd_concat(va, vb, n)` | 向量拼接 | intv16, shortv32, floatv16, halfv16 |
| `simd_cvt_f2h(va)` | FP32→FP16 | floatv16 → halfv16 |
| `simd_cvt_h2f(va)` | FP16→FP32 | halfv16 → floatv16 |
| `simd_copy_sign(va, vb)` | 拷贝符号位 | floatv16, halfv16 |
| `simd_fma(va, vb, vc)` | `a×b+c` | floatv16, halfv16 |
| `simd_fms(va, vb, vc)` | `a×b-c` | floatv16, halfv16 |
| `simd_fnma(va, vb, vc)` | `-a×b+c` | floatv16, halfv16 |
| `simd_fnms(va, vb, vc)` | `-a×b-c` | floatv16, halfv16 |
| `simd_set(a0..a15)` | 标量构造向量 | float, half, int, short |

---

## 十四、指令拍数速查表

### 14.1 P0 计算类指令

| 指令类别 | 指令示例 | 拍数 |
|----------|----------|------|
| 标量整数加减/比较/移位 | ADDW, SUBW, CMPEQ | **1** |
| 标量整数乘法 | MULW, UMULW | **5** |
| 标量整数选择 | SELEQ, SELLT, SELLE | **1** |
| 向量整数运算 | VADDW, VSUBW, VMULW, VADDH, VSUBH, VMULH | **3** |
| 向量整数比较 | VCMPEQW, VCMPLTW, VCMPLEW | **3** |
| 向量整数乘加 | VMAW, VNMAW, VMAH, VNMAH | **3** |
| 向量整数选择 | VSELEQW, VSELLTW, VSELLEW | **1** |
| 向量逻辑 | VLOG2X, VLOG3R | **1** |
| 向量整理 | VCONW, VCONH, VINSW, VEXTW, VCPYW | **3** |
| 标量浮点加减 | FADDS, FSUBS | **7** |
| **向量浮点加减** | VFADDS, VFSUBS | **5** |
| 标量浮点比较 | FCMPEQ, FCMPLE, FCMPLT | **7** |
| **向量浮点比较** | VFCMPEQS, VFCMPLES, VFCMPLTS | **5** |
| 标量浮点乘法 | FMULS | **7** |
| **向量浮点乘法** | VFMULS | **5** |
| 标量浮点乘加 | FMAS, FMSS, FNMAS, FNMSS | **7** |
| **向量浮点乘加** | VFMAS, VFMSS, VFNMAS, VFNMSS | **5** |
| 浮点除法/平方根 | FDIVS, FSQRTS | **~19/~18** |
| 浮点转换 | FCVTHS, FCVTSH, VFCVTSH, VFCVTHS | **2** |
| 符号拷贝 | FCPYS, VFCPYSS, VFCPYSES, VFCPYSNS | **1** |
| 浮点选择 | FSELEQ, VFSELEQS, VFSELLTS, VFSELLES | **1** |

### 14.2 P1 访存/控制类指令

| 指令类别 | 指令示例 | 拍数 |
|----------|----------|------|
| 标量 Load (本地 LDM) | LDW, LDL, FLDS | ≥5 |
| 标量 Store (本地 LDM) | STW, STL, FSTS | ≥3 |
| 向量 Load (本地 LDM) | VLDW, VLDH, VLDB | ≥5 |
| 向量 Store (本地 LDM) | VSTW, VSTH, VSTB | ≥4 |
| 主存/远程 LDM 访问 | — | 延迟不定 |
| 条件/无条件转移 | BEQ, BNE, BR, JMP | **1** |
| DMA/RMA | DMA, RMA | 不定 |
| 同步 | SYNR, SYNC, SYNP | 不定 |
| 存储栏栅 | MEMB | ≥1，执行结束前阻塞后续发射 |

---

## 十五、双发射优化指南

### 15.1 核心原理

P0（计算）和 P1（访存）可以**每个周期同时发射一条指令**。优化目标是将 load/store 和 compute 指令交错排布，让两条流水线同时饱和。

### 15.2 优化示例

**❌ 优化前** — Load 和 Compute 分离，流水线利用不充分：
```c
// 先全部 load — P1 忙，P0 空闲
simd_load(a0, ptr_a + 0);   // P1
simd_load(a1, ptr_a + 16);  // P1
simd_load(a2, ptr_a + 32);  // P1
simd_load(a3, ptr_a + 48);  // P1
simd_load(b0, ptr_b + 0);   // P1
simd_load(b1, ptr_b + 16);  // P1
simd_load(b2, ptr_b + 32);  // P1
simd_load(b3, ptr_b + 48);  // P1

// 再全部计算 — P0 忙，P1 空闲
a0 = simd_vfadds(a0, b0);    // P0
a1 = simd_vfadds(a1, b1);    // P0
a2 = simd_vfadds(a2, b2);    // P0
a3 = simd_vfadds(a3, b3);    // P0
// → 实测约 248 cycle
```

**✅ 优化后** — Load 和 Compute 交错，双发射饱和：
```c
simd_load(a0, ptr_a + 0);     // P1: load a0
simd_load(b0, ptr_b + 0);     // P1: load b0
simd_load(a1, ptr_a + 16);    // P1: load a1
c0 = simd_vfadds(a0, b0);     // P0: compute c0，可与后续独立 load 交错
simd_load(b1, ptr_b + 16);    // P1: load b1
simd_load(a2, ptr_a + 32);    // P1: load a2
c1 = simd_vfadds(a1, b1);     // P0: compute c1
simd_load(b2, ptr_b + 32);    // P1: load b2
simd_load(a3, ptr_a + 48);    // P1: load a3
c2 = simd_vfadds(a2, b2);     // P0: compute c2
simd_load(b3, ptr_b + 48);    // P1: load b3
c3 = simd_vfadds(a3, b3);     // P0: compute c3
// → 数据依赖被展开摊薄后，P0/P1 发射利用率更高
```

实际代码中应继续增加展开深度，确保 `load -> use` 之间有足够的独立指令间隔；否则虽然 P0/P1 可以双发射，仍可能因寄存器依赖等待而停顿。

### 15.3 优化策略

1. **交错排布**: 将独立计算指令插入 load 指令之间，让 P0 和 P1 同时工作
2. **预取**: 提前加载下一轮迭代的数据，用本轮计算掩盖下轮访存延迟
3. **双缓冲**: 在 LDM 中使用 ping-pong buffer，DMA 写入一个 buffer 时 SIMD 从另一个 buffer 读取
4. **LDM Bank 错开**: 将 DMA/RMA/ACE/SIMD 流量分配到 LDM 的 Bank0 和 Bank1 两个不同 Bank，避免端口竞争
5. **避免长拍阻塞**: `FSQRTS` (~18拍) 和 `FDIVS` (~19拍) 非完全流水，尽量减少在热循环中使用
6. **提高数据复用**: SIMD 寄存器为 512 bit，完全流水时对 LDM 的等效带宽需求可达到约 `512bit / 8 * 2.5GHz = 160GB/s`。如果每个元素只从 LDM 读取一次就写回，P1/LDM 很容易成为瓶颈；应尽量在寄存器或 LDM tile 内复用数据。

### 15.4 DMA staging 与 SIMD 的关系

SIMD 热循环通常只看到 LDM 内的 load/store，但整体性能还取决于 HBM 到 LDM 的 DMA staging。设计 tile 时应同时满足以下规则：

- DMA 性能路径按 128B 包考虑，地址和长度优先 128B 对齐、128B 整数倍。
- 32 个从核应从核组视角共同覆盖连续 HBM 地址，不要只追求单个从核局部连续。
- 传统 DMA 模式下，单从核单次搬运 8KB 到 16KB 通常更容易兼顾 Channel/Bank 展开和 Row 命中；双缓冲场景可优先测试 4KB/8KB。
- DMA 读写共用队列，连续 outstanding 请求总数最好不超过 11。
- DMA get 返回、DMA put 发出、RMA put/广播都可能占用从核到 Mesh 的一级连接；安排 SIMD 双缓冲时要把 DMA/RMA wait 放在能被计算掩盖的位置。

### 15.5 并发规则

| 操作组合 | 是否可并发 | 原因 |
|----------|-----------|------|
| P0 计算 + P1 访存 | ✅ 可并发 | 不同流水线 |
| ACE 计算 + SIMD 计算 | ✅ 可并发 | 不同硬件单元 |
| DMA GET + RMA PUT | ⚠️ 条件可并发 | 方向相反时通常可重叠；若 DMA get 返回和 RMA 下网/广播打到同一节点或同一路径，仍会拥塞 |
| DMA PUT + RMA PUT | ❌ 冲突 | 同向（上网方向） |
| ACE + SIMD 同时访问 LDM | ⚠️ 需 Bank 错开 | 共享 LDM 端口 |

---

## 十六、完整编程示例

### 16.1 向量加法 (带双发射优化)

```c
#include <simd.h>

__device__ void vector_add(floatv16* dst, const floatv16* src_a,
                           const floatv16* src_b, int n_vectors) {
    for (int i = 0; i < n_vectors; i += 2) {
        // 交错 load 和 compute
        floatv16 a0, a1, b0, b1;
        simd_load(a0, &src_a[i]);       // P1
        simd_load(a1, &src_a[i + 1]);   // P1
        simd_load(b0, &src_b[i]);       // P1
        a0 = simd_vfadds(a0, b0);       // P0: 与后续 load 并行
        simd_load(b1, &src_b[i + 1]);   // P1
        a1 = simd_vfadds(a1, b1);       // P0
        simd_store(a0, &dst[i]);        // P1
        simd_store(a1, &dst[i + 1]);    // P1
    }
}
```

### 16.2 FMA 实现 AXPY (a*x + y)

```c
__device__ void axpy(floatv16* y, const floatv16* x, float alpha, int n) {
    floatv16 valpha = simd_vcpyfs(alpha);  // 广播 alpha 到向量
    for (int i = 0; i < n; i++) {
        floatv16 vx, vy;
        simd_load(vx, &x[i]);              // P1
        simd_load(vy, &y[i]);              // P1
        vy = simd_vfmas(valpha, vx, vy);   // P0: alpha*x + y (单指令!)
        simd_store(vy, &y[i]);             // P1
    }
}
```

### 16.3 带掩码的条件计算

```c
__device__ void relu(floatv16* dst, const floatv16* src, int n) {
    floatv16 zero = simd_vcpyfs(0.0f);
    for (int i = 0; i < n; i++) {
        floatv16 v;
        simd_load(v, &src[i]);             // P1
        floatv16 mask = simd_vfcmplts(v, zero);  // P0: v < 0 ?
        v = simd_vfseleqs(v, mask, zero);  // P0: mask == 0 ? v : 0
        simd_store(v, &dst[i]);            // P1
    }
}
```

### 16.4 归约求和

```c
__device__ float vector_sum(const floatv16* src, int n_vectors) {
    floatv16 accum = simd_vcpyfs(0.0f);
    for (int i = 0; i < n_vectors; i++) {
        floatv16 v;
        simd_load(v, &src[i]);
        accum = simd_vfadds(accum, v);     // 逐向量累加
    }
    return simd_reduc_plusfs(accum);       // 最终归约到标量
}
```

### 16.5 非对齐加载 (使用 VCON 拼接)

```c
__device__ floatv16 unaligned_load(const float* ptr) {
    uintptr_t addr = (uintptr_t)ptr;
    uintptr_t aligned_addr = addr & ~0x3FULL;  // 对齐到 64 字节
    int offset = addr & 0x3F;                   // 偏移量

    floatv16 low, high;
    simd_load(low, (const float*)aligned_addr);          // 加载对齐低段
    simd_load(high, (const float*)(aligned_addr + 64));  // 加载对齐高段

    // 拼接
    return simd_vconfs(high, low, (void*)(uintptr_t)offset);
}
```

---

## 十七、常见陷阱与注意事项

1. **对齐要求**: `simd_load`/`simd_store` 要求地址 64 字节对齐，否则触发对齐异常。使用 `simd_loadu`/`simd_storeu` 处理非对齐地址。

2. **FP16 精度损失**: ACE 写回 FP16 时会截断非规格化数，可能有较大精度损失。对精度敏感的场景建议使用 FP32 写回或手动 BF16 方案。

3. **除法/平方根非完全流水**: `FSQRTS` (~18拍) 和 `FDIVS` (~19拍) 共用执行子部件，且非完全流水。不要在热循环中密集使用。

4. **DMA 粒度与队列深度**: DMA 接口可能允许 4B 粒度，但性能路径应按 128B 包组织，地址和长度优先 128B 对齐、128B 整数倍。DMA 读写共用队列，深度约 11；第 12 条并发请求可能导致发起延迟明显升高。

5. **LDM Bank 冲突**: LDM 分 Bank0 和 Bank1 各 128KB，SIMD、DMA、RMA、ACE 同时访问同一 Bank 时会竞争端口。应主动将不同流量错开到不同 Bank。

6. **比较结果用作掩码**: 比较指令返回的是全 1（真）或全 0（假），可直接传给 `simd_vseleqw` 等选择指令作为条件掩码。

7. **标量 r31 为 0**: 寄存器 r31 恒为常数 0，读返回 0，写被忽略。可用于快速获取零向量。

8. **FPCR 访问阻塞**: RFPCR/WFPCR 指令在之前所有浮点指令完成前不允许执行，在执行结束前也不允许后续浮点指令发射。

