离线推理
更新时间：2026-04-15 10:23:18
离线推理适用于一次性处理大量输入提示（prompts）的场景，通过批处理提高吞吐量。

本节主要介绍使用Teco-vLLM对大语言模型进行离线推理的流程和方法。

说明： 
Teco-vLLM的离线推理流程和方法与vLLM相同，关于vLLM离线推理的更多信息，可参考vLLM官方文档。

大语言模型分为生成式模型和池化模型，两类模型的离线推理流程整体相同，但推理代码和函数略有差异：

生成式模型的离线推理实例，可参考QwQ-32B离线推理。

池化模型（例如：嵌入模型、重排序模型）的离线推理实例，可参考Qwen3-Embedding-0.6B推理和Qwen3-Reranker-0.6B推理。

推理流程
运行Teco-vLLM离线推理的整体流程如下：



图1 离线推理流程

步骤一：初始化vLLM引擎
创建LLM类的新实例并指定运行模型，从而初始化vLLM引擎。

import os
os.environ["HF_ENDPOINT"]="https://hf-mirror.com"
os.environ["SDAA_VISIBLE_DEVICES"] = "0,1,2,3,4,5,6,7"

from vllm import LLM

llm = LLM(model="Qwen/QwQ-32B",
          gpu_memory_utilization=0.95,
          enforce_eager=False,
          max_num_seqs=128,
          max_model_len=8192,
          enable_prefix_caching=True,
          enable_chunked_prefill=False,
          tensor_parallel_size=8)
说明： 
离线推理API基于LLM类。关于LLM类的详细参数信息，请参考vLLM官网文档。

模型支持的张量并行大小（tensor_parallel_size），请参考模型支持列表。

设置运行的模型：

支持自动从HuggingFace或ModelScope下载模型权重，只需将model参数设为所需的模型名即可。

支持加载本地缓存的模型权重，只需将model参数设为本地缓存权重的路径即可。

步骤二：指定输入提示
指定多个输入提示。推理引擎将基于输入提示提供相应的输出结果。

# Sample prompts.
prompts = [
    "Hello, my name is",
    "The president of the United States is",
    "The capital of France is",
    "The future of AI is",
    "解释一下温故而知新的意思",
    "explain the meaning of 'rain cats and dogs'",
]
步骤三：定义采样参数
参考以下代码，创建采样参数。通过调整采样参数，控制生成文本的质量和风格。

from vllm import SamplingParams
sampling_params = SamplingParams(temperature=0.0,
                                 max_tokens=256,
                                 min_tokens=2,
                                 top_p=1.0,
                                 top_k=-1)
说明： 
关于SamplingParams类的详细信息，请参考vLLM官方文档。

步骤四：执行推理
使用llm.generate方法执行推理，生成推理结果。

outputs = llm.generate(prompts, sampling_params)
步骤五：打印推理结果
参考以下代码，打印出推理结果。

for output in outputs:
    prompt = output.prompt
    generated_text = output.outputs[0].text
    print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
完整示例
import os
os.environ["HF_ENDPOINT"]="https://hf-mirror.com"
os.environ["SDAA_VISIBLE_DEVICES"] = "0,1,2,3,4,5,6,7"

from vllm import LLM, SamplingParams
prompts = [
        "Hello, my name is",
        "The president of the United States is",
        "The capital of France is",
        "The future of AI is",
        "解释一下温故而知新的意思",
        "explain the meaning of 'rain cats and dogs'",
    ]
# Sample prompts.
sampling_params = SamplingParams(temperature=0.0,
                                    max_tokens=256,
                                    min_tokens=2,
                                    top_p=1.0,
                                    top_k=-1)
def main():
    llm = LLM(model="Qwen/QwQ-32B",
            gpu_memory_utilization=0.95,
            enforce_eager=False,
            max_num_seqs=128,
            max_model_len=8192,
            enable_prefix_caching=True,
            enable_chunked_prefill=False,
            tensor_parallel_size=8)
    outputs = llm.generate(prompts, sampling_params)
    for output in outputs:
        prompt = output.prompt
        generated_text = output.outputs[0].text
        print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
if __name__ == '__main__':
    main()