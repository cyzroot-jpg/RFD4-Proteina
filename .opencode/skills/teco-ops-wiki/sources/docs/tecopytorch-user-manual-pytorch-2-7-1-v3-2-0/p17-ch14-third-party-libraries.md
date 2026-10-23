---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p17
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第17部分 (ch14-third-party-libraries)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "20191-20541"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, third-party-libraries, compatibility]
---

# TecoPyTorch 用户手册 v3.2.0（第17部分）

> 原文行范围：`20191-20541`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

14. 第三方库支持列表
本文介绍TecoPyTorch框架支持的第三方库。在模型迁移时，如果原始模型中包含这些三方库的算子，您可以按照下
面的说明，在TecoPyTorch中使用这些算子。

                                               版本
 库名称          介绍                                        适配说明
                                               要求

                                                        当前太初AI加速卡已适配torchvision库，
                                                        并提供了适配后的wheel安装包。
              torchvision是PyTorch生态系统中的一                关于torchvision的安装，请参考安装指
              个官方库，专门为计算机视觉任务设                          南。
 torchvisi
              计。它提供了一系列高效的工具、预训                2.0.2
 on
              练模型和数据集，帮助开发者快速构建                            说明：
              和训练视觉相关的深度学习模型。
                                                           不支持torchvision中的自定义算
                                                           子。


                                                        当前太初AI加速卡已适配torchaudio库，
                                                        并提供了适配后的wheel安装包。
              torchaudio是PyTorch生态系统中的一
              个官方库，专门用于处理音频数据和构                         关于torchaudio的安装，请参考安装指
              建音频相关的机器学习模型。它提供了                         南。
 torchaud     高效的音频处理工具、预处理的音频转
                                               0.15.0      说明：
 io           换函数，以及常用音频数据集的便捷加
              载接口，与PyTorch的张量计算和神经
                                                           不支持torchaudio中的自定义算
              网络模块无缝集成，支持GPU加速和自
                                                           子。
              动求导。



                                               4.17.0   当前太初AI加速卡已原生支持
              Transformers是HuggingFace的核心               Transformers库。
 Transfor                                      及以
              套件，提供了便于快速下载和使用预训
 mers                                          上版       关于Transformer的安装和使用，请参考
              练模型的API。
                                               本        Transformer官网说明。

              Accelerate是Hugging Face开发的
                                                        当前太初AI加速卡已原生支持Accelerate
              Python库，旨在简化深度学习模型在多
 Accelera                                      最新       库。
              设备上的分布式训练和推理。它为开发
 te                                            版本       关于Accelerate的安装和使用，请参考
              者提供了一个高效且易用的接口，帮助
                                                        Accelerate官网说明。
              快速部署和优化模型。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                           306

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                             第三方库支持列表




                                               版本
 库名称          介绍                                        适配说明
                                               要求

              DeepSpeed是一款专注于提升深度学习                     当前太初AI加速卡已原生支持DeepSpeed
              模型训练与推理效率的软件库。它基于                         库。
 DeepSpe                                       最新
              PyTorch等主流深度学习框架，提供了
 ed                                            版本       关于DeepSpeed的安装和使用，请参考
              一系列先进的技术，例如：ZeRO优化
                                                        DeepSpeed官网说明。
              器、混合精度训练和通信优化等。

                                                        当前太初AI加速卡适配了LLaMA-Factory
                                                        的部分功能。
              LLaMA-Factory是一个大型语言模型
              （LLM）训练与微调平台。它使开发者和                          关于LLaMA-Factory的安装和使用，
 LLaMA-                                        最新          请参考LLaMA-Factory官方文档。
              研究者无需深入了解底层复杂的代码，
 Factory                                       版本
              即可在本地或云端对上百种预训练模型                            关于太初AI加速卡适配的LLaMA-
              进行高效微调。                                      Factory功能说明，请参考
                                                           tecorign_thirdparty_llm。


              TRL（Transformers Reinforcement
                                                        当前太初AI加速卡适配了TRL的部分功能。
              Learning）是一个基于HuggingFace
              Transformers的开源库，专注于将强化                      关于TRL的安装和使用，请参考
                                               最新          LLaMA-Factory官方文档。
 TRL          学习技术应用于自然语言处理（NLP）任
                                               版本
              务中。它特别适用于训练语言模型以优                            关于太初AI加速卡适配的TRL具体请参
              化特定目标，例如：人类反馈、奖励信                            考tecorign_thirdparty_llm。
              号等。

                                                        当前太初AI加速卡已适配PyTorch
              PyTorch Lightning是基于PyTorch的轻
 PyTorch                                                Lightning框架，关于该框架在太初AI加速
              量级高级框架，旨在通过结构化设计和                2.5.0
 Lightning                                              卡上的安装和使用，请参考lightning-
              代码解耦提升深度学习开发效率。
                                                        Teco。

              MMEngine是一个基于PyTorch框架训
                                                        当前太初AI加速卡已适配MMEngine库，
 MMEngin      练深度学习模型的基础库。它是所有
                                               0.10.4   关于该框架在太初AI加速卡上的安装和使
 e            OpenMMLab代码库的训练引擎，支持
                                                        用，请参考mmengine_sdaa。
              各种研究领域的数百种算法。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                              307

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                       第三方库支持列表




                                               版本
 库名称          介绍                                       适配说明
                                               要求

                                                       当前太初AI加速卡已原生支持MMPreTrain
                                                       库，关于该库的安装和使用，请参考
                                                       MMPreTrain官网说明。


              MMPreTrain是一个基于PyTorch框架的        1.2.0       提示：
 MMPreTr
              开源预训练工具库。它是OpenMMLab             及以
 ain                                                       在太初AI加速卡上使用
              工程的一部分。                          上版
                                                           MMPretrain，需要安装适配太初
                                                           AI加速卡的MMEngine库。具体安
                                                           装方法，请参考
                                                           mmengine_sdaa。


                                                       当前太初AI加速卡已原生支持
                                                       MMDetection库，关于该库的安装和使
                                                       用，请参考MMDetection官网说明。

                                               3.3.0       提示：
              MMDetection是一个基于PyTorch框架
 MMDetec                                       及以
              的开源对象检测工具箱。它是
 tion                                          上版          在太初AI加速卡上使用
              OpenMMLab项目的一部分。
                                               本           MMDetection，需要安装适配太
                                                           初AI加速卡的MMEngine库。具体
                                                           安装方法，请参考
                                                           mmengine_sdaa。


                                                       当前太初AI加速卡已原生支持MMCV库，
                                                       关于该库的安装和使用，请参考MMCV官
                                               2.2.0   网说明。
              MMCV是计算机视觉研究的基础库。它               及以
 MMCV                                                      提示：
              是OpenMMLab项目的一部分。                上版
                                               本
                                                           当前太初AI加速卡只支持MMCV
                                                           库中的CPU算子。


              MIM是OpenMMLab的包管理工具和统            0.3.9
              一入口，它能够自动安装OpenMMLab             及以      当前太初AI加速卡已原生支持MIM库，关于
 MIM
              项目的依赖包，并提供统一的启动和模                上版      其安装和使用，请参考MIM官网说明。
              型访问入口。                           本




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                         308

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                            第三方库支持列表




                                               版本
 库名称          介绍                                        适配说明
                                               要求

              Diffusers是HuggingFace开源的一个
              专注于生成模型的Python库，旨在简化
              扩散模型（Diffusion Models）和其他                 当前太初AI加速卡已原生支持Diffusers
                                               最新
 Diffusers    生成式模型的训练、推理和部署流程。                         库，关于该库的安装和使用，请参考
                                               版本
              它提供了一套模块化、灵活且高性能的                         Diffusers官网说明。
              工具，支持生成图像、音频、3D对象等
              多种模态内容。

              timm是一个包含SOTA计算机视觉模
              型、算子、实用程序、优化器、调度                          当前太初AI加速卡已适配timm库，并提供
              器、数据加载器、增强和训练/评估脚本                        了适配后的wheel安装包。
 timm                                          1.0.15
              的库。开发者基于该库，可以方便地复                         关于timm的安装和使用，请参考
              现和使用ImageNet等数据集上的模                       tecorigin_timm。
              型。

              torchmetrics是一个开源的PyTorch原
              生的函数和度量模块的集合，用于实现                         当前太初AI加速卡已适配torchmetrics
 torchmet     模型性能评估。基于该库，开发者可以                         库，并提供了适配后的wheel安装包。
                                               1.8.0
 rics         实现常见的指标，如：准确性、召回                          关于torchmetrics的安装和使用，请参考
              率、精度、AUROC等，或者创建自定义                       tecorigin_torchmetrics。
              的指标。

                                                        当前太初AI加速卡已适配kornia库，并提
              kornia是一个基于PyTorch的可微分计
                                                        供了适配后的wheel安装包。
 kornia       算机视觉库，提供了丰富的图像处理和                0.8.1
              几何视觉算法。                                   关于kornia的安装和使用，请参考
                                                        tecorigin_kornia。

              ultralytics是一个专注于计算机视觉任务
              的Python库，旨在简化训练、评估和部                      当前太初AI加速卡已适配ultralytics库，并
 ultralytic   署视觉模型的过程。该库提供了一系列                8.3.10   提供了适配后的wheel安装包。
 s            主流的视觉模型，例如：YOLOv5、               0        关于ultralytics的安装和使用，请参考
              YOLOv4、YOLOv3、EfficientDet和               tecorigin_ultralytics。
              PP-YOLO等。

                                                        当前太初AI加速卡已适配segmentation-
 segment      segmentation-models-pytorch是              models-pytorch库，并提供了适配后的
 ation-       一个基于PyTorch的图像分割模型库，                      wheel安装包。
                                               0.5.0
 models-      提供了多种预训练的语义分割模型（如                         关于segmentation-models-pytorch的
 pytorch      U-Net、FPN、PSPNet 等）。                      安装和使用，请参考
                                                        tecorigin_segmentation_models。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                             309

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                             第三方库支持列表




                                               版本
 库名称          介绍                                       适配说明
                                               要求

                                                       当前太初AI加速卡已适配sentence-
              sentence-transformers是一个基于               transformers库，并提供了适配后的
 sentence
              PyTorch和Transformers的库，用于句               wheel安装包。
 -
              子和文本嵌入，支持多种语言和任务，                4.2.0
 transfor                                              关于sentence-transformers的安装和使
              如：文本相似性、语义搜索、释义挖掘
 mers                                                  用，请参考
              等。
                                                       tecorigin_sentence_transformers。


              fastai是一个建立在PyTorch上的高级深                 当前太初AI加速卡已适配fastai库，并提供
              度学习库，其核心目标是让深度学习变                        了适配后的wheel安装包。
 fastai                                        2.8.1
              得更易用、更高效，同时又兼顾灵活                         关于fastai的安装和使用，请参考
              性。                                       tecorigin_fastai。

                                                       当前太初AI加速卡已适配torchdiffeq库，
              torchdiffeq是一个基于PyTorch的库，               并提供了适配后的wheel安装包。
 torchdiff
              用于求解常微分方程（ODEs）的数值               0.2.5
 eq                                                    关于torchdiffeq的安装和使用，请参考
              解。
                                                       tecorigin_torchdiffeq。

              ignite是PyTorch社区发布的一个高级封                 当前太初AI加速卡已适配ignite库，并提供
              装库，旨在帮助开发者更快、更简洁地                        了适配后的wheel安装包。
 ignite       编写可复用的代码，进行深度学习实                 0.6.0
              验。它提供了一套灵活的抽象，用于构                        关于ignite的安装和使用，请参考
              建和管理训练和验证循环。                             tecorigin_pytorch_ignite。


              torchsde是由Google Research开发              当前太初AI加速卡已适配torchsde库，并
              的一个开源Python库，旨在为随机微分                     提供了适配后的wheel安装包。
 torchsde                                      0.2.6
              方程（SDE）提供高效、可扩展的求解                       关于torchsde的安装和使用，请参考
              器。                                       tecorigin_torchsde。

              FastChat是一个用于训练、评估以及部
              署大模型的开源框架，支持Vicuna、                      当前太初AI加速卡已适配FastChat库，并
              LongChat等多种语言模型。FastChat         0.2.3   提供了适配后的wheel安装包。
 FastChat
              提供了模型的训练评估代码和分布式服                6       关于FastChat的安装和使用，请参考
              务系统，包含Web界面以及兼容                          tecorigin_fastchat。
              OpenAI的RESTful API。

              Evaluate是一个评估机器学习模型和数                    当前太初AI加速卡已适配Evaluate库，并
              据集的工具库，由HuggingFace开发。                   提供了适配后的wheel安装包。
 Evaluate     该库提供了数十种涵盖自然语言处理和                0.4.5
              计算机视觉等领域的常用评估指标和方                        关于Evaluate的安装和使用，请参考
                                                       tecorigin_evaluate。
              法。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                              310

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                       第三方库支持列表




                                               版本
 库名称          介绍                                       适配说明
                                               要求

              OpenCLIP是一个开源的CLIP模型实现                   当前太初AI加速卡已适配OpenCLIP库，并
              库。CLIP是由OpenAI提出的一种多模态                   提供了适配后的wheel安装包。
 OpenCLI                                       2.32.
              预训练模型，可以通过自然语言理解图
 P                                             0       关于OpenCLIP的安装和使用，请参考
              像。OpenCLIP项目旨在提供CLIP的开源
                                                       tecorigin_open_clip。
              复现，并在此基础上进行改进和扩展。

              Datasets是一个用于加载和处理各种自                    当前太初AI加速卡已适配Datasets库，并
              然语言处理任务的数据集库，由                           提供了适配后的wheel安装包。
 Datasets     HuggingFace开发。该库提供了统一的           4.0.0
              API接口，可以方便地访问多个数据集，                      关于Datasets的安装和使用，请参考
                                                       tecorigin_datasets。
              并且支持自定义数据集。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                         311

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      常见问题
