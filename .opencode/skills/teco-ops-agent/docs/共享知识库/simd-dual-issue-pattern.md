# SIMD 双发射软件流水模式（强制）

> 拍数依据：[SIMD使用手册-zh.md](SIMD使用手册-zh.md) 第十四章

## 指令拍数

| 指令 | 流水线 | 延迟 | 全流水 |
|------|--------|------|--------|
| VLDW (`simd_load`) | P1 | ≥5 拍 | ✅ |
| VFADDS (`av + pv`) | P0 | 5 拍 | ✅ |
| VSTW (`simd_store`) | P1 | ≥4 拍 | ✅ |
| P0+P1 双发射 | — | — | 每周期各 1 条 |

## 核心约束

1. **load→use 间距 ≥5 拍**：VLDW 结果 5 拍后才可用，提前用会停顿
2. **add→store 间距 ≥5 拍**：VFADDS 结果 5 拍后才可用，store 不能紧跟同一下标的 add
3. **av_X 和 pv_X 加载相差 1 拍**：只有 1 条 P1 流水线，同一下标的两个操作数 ready 时间差 1 拍，add 必须等晚的那个
4. **P1 是瓶颈**：accumulate 循环每 element 需要 1 load + 1 store = 2 条 P1 指令，但只有 1 条 P0（add），P1 利用率决定吞吐

## 三种方案逐周期对比

### 原始（1x 展开，禁止）

```
cycle 0:  load(av)   P1        ← av ready @5
cycle 1:  load(pv)   P1        ← pv ready @6
cycle 2-4: (停顿)              ← av 未就绪
cycle 5:  av+ pv P0            ← av@5✓ pv@6✗ → 停顿！
cycle 6:  av+ pv P0            ← result @11
cycle 7-10:(停顿)              ← result 未就绪
cycle 11: store(av) P1
```

**12 cycles / 16 floats = 0.75 拍/element**

### 4x 展开（过渡，不推荐）

```
cycle 0-7: 8× load (P1)       ← P0 全空闲
cycle 8-11: 4× add (P0)       ← 部分 pv 未就绪，有停顿
cycle 12-17: 4× store (P1)    ← P0 全空闲，store 等 add 结果
```

**~18 cycles / 64 floats = 0.28 拍/element**

### 8x 展开 + 软件流水（强制要求）

```
cycle 0-15: 16× load (P1), av/pv 交错   ← 全部 P1，P0 空闲（16c）
cycle 16-20: 5× add (P0)                 ← 填满 VFADDS 5 拍流水线（5c）
cycle 21-22: add ∥ store 双发（2c）      ← 软件流水稳态
cycle 23-28: store 排空（6c）            ← 最后 1 条 add + 6 条 store
```

**28 cycles / 128 floats = 0.22 拍/element**

## 代码模板

```c
/* 8x unroll + software pipeline
 *   Load 8 pairs (16c P1) → Prologue 5 adds (5c P0) →
 *   Steady: add[N]∥store[N-5] (2c) → Epilogue drain (6c) */
for (int i = 0; i < N; i += 128) {
    floatv16 av_0, av_1, av_2, av_3, av_4, av_5, av_6, av_7;
    floatv16 pv_0, pv_1, pv_2, pv_3, pv_4, pv_5, pv_6, pv_7;
    /* Load phase: 16× P1, av/pv interleaved */
    simd_load(av_0, acc + i + 0);    simd_load(pv_0, part + i + 0);
    simd_load(av_1, acc + i + 16);   simd_load(pv_1, part + i + 16);
    simd_load(av_2, acc + i + 32);   simd_load(pv_2, part + i + 32);
    simd_load(av_3, acc + i + 48);   simd_load(pv_3, part + i + 48);
    simd_load(av_4, acc + i + 64);   simd_load(pv_4, part + i + 64);
    simd_load(av_5, acc + i + 80);   simd_load(pv_5, part + i + 80);
    simd_load(av_6, acc + i + 96);   simd_load(pv_6, part + i + 96);
    simd_load(av_7, acc + i + 112);  simd_load(pv_7, part + i + 112);
    /* Prologue: 5 adds fill the 5c VFADDS pipe */
    av_0 = av_0 + pv_0;
    av_1 = av_1 + pv_1;
    av_2 = av_2 + pv_2;
    av_3 = av_3 + pv_3;
    av_4 = av_4 + pv_4;
    /* Steady state: add[N] ∥ store[N-5] dual-issue */
    av_5 = av_5 + pv_5;
    simd_store(av_0, acc + i + 0);
    av_6 = av_6 + pv_6;
    simd_store(av_1, acc + i + 16);
    /* Epilogue: drain remaining */
    av_7 = av_7 + pv_7;
    simd_store(av_2, acc + i + 32);
    simd_store(av_3, acc + i + 48);
    simd_store(av_4, acc + i + 64);
    simd_store(av_5, acc + i + 80);
    simd_store(av_6, acc + i + 96);
    simd_store(av_7, acc + i + 112);
}
```

## 不同运算类型的适配

| 运算 | 延迟 | Prologue | Steady 偏移 |
|------|------|----------|-------------|
| VFADDS/VFSUBS | 5 拍 | 5 条 add | add[N] ∥ store[N-5] |
| VFMULS | 5 拍 | 5 条 mul | mul[N] ∥ store[N-5] |
| VFMAS (FMA) | 5 拍 | 5 条 fma | fma[N] ∥ store[N-5] |
| VFCVTSH (转换) | 2 拍 | 2 条 cvt | cvt[N] ∥ store[N-2] |
| 整数 VADDW/VMULW | 3 拍 | 3 条 | add[N] ∥ store[N-3] |

**通用公式**：Prologue 条数 = 运算延迟拍数，Steady 状态 `op[N] ∥ store[N-延迟]`。