---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p03
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第3部分 (ch3-install-loongarch-hygon-phytium)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "2501-4395"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, install, conda, pip, docker, loongarch, hygon, phytium, aarch64]
---

# TecoPyTorch 用户手册 v3.2.0（第3部分）

> 原文行范围：`2501-4395`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

系统中已安装Python 3.11环境。

 操作步骤




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司      33

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




  1. 执行以下命令，创建Python虚拟环境。


         说明：

         使用 venv 创建虚拟环境时，将完整拷贝一份系统Python。拷贝的Python版本与系统Python一致且
         相互隔离。


       mkdir $PWD/myenv
       python -m venv myenv



 2. 执行以下命令，激活虚拟环境。


       source $PWD/myenv/bin/activate



 3. 执行以下命令，安装TecoPytorch所需环境依赖包。


       pip install astunparse numpy pyyaml cmake cffi typing_extensions future six




3.3.1.1.3.2 获取软件安装包
在安装TecoPyTorch前，需要获取目标软件安装包。

 操作步骤

执行以下命令，下载TecoPyTorch相关安装包至本地。

   下载PyTorch安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-spe-pypi-repo/loongnix23.1/torch-2.7.1-cp311-cp31
       1-linux_loongarch64.whl



   下载TecoPyTorch安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-spe-pypi-repo/loongnix23.1/torch_sdaa-3.2.0-cp311
       -cp311-linux_loongarch64.whl



   下载torchvision安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-spe-pypi-repo/loongnix23.1/torchvision-0.22.1-cp3
       11-cp311-linux_loongarch64.whl




 校验安装包

基于下载的软件安装包生成MD5码，并与安装包官方MD5码进行比较，确认下载安装包的完整性。


文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                                34

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                          安装指南




以TecoPyTorch安装包为例，生成安装包MD5的命令如下：

   md5sum torch_sdaa-3.2.0-cp311-cp311-linux_loongarch64.whl




 安装包MD5码

TecoPyTorch相关安装包的官方MD5码信息如下：


 安装包                               MD5码

 PyTorch安装包                        cefdb8db1f4db3df9432ab43928e6625

 TecoPyTorch安装包                    6c9621c1a9897ee07aadd05741031a48

 torchvision安装包                    449ee97cb8a21d6a9958d2494e1072b5



3.3.1.1.3.3 安装软件安装包
获取软件安装包后，可对其进行安装。

 前提条件

   您已成功获取PyTorch、TecoPytorch、torchvision和torchaudio的软件安装包，可参考获取软件安装包。

   您已成功创建并进入Python虚拟环境，可参考创建Python虚拟环境。

 操作步骤

执行以下命令，安装软件包。

  1. 安装PyTorch：


       pip install torch-2.7.1-cp311-cp311-linux_loongarch64.whl


 2. 安装TecoPytorch：


       pip install torch_sdaa-3.2.0-cp311-cp311-linux_loongarch64.whl



 3. 安装torchvision：


       pip install torchvision-0.22.1-cp311-cp311-linux_loongarch64.whl




 执行结果

执行以下命令，查看目标软件安装包是否成功安装。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                  35

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     安装指南




   pip list | grep torch   # 安装成功后，可以查询到软件安装包的信息




3.3.1.1.3.4 升/降级软件安装包
如果已安装的软件安装包不满足使用需求时，可对其进行升/降级。

 注意事项

TecoPyTorch采用先卸载再安装的方式进行升降级，您需要卸载已经安装的TecoPyTorch安装包、TecoDriver和
TecoToolKit包，再安装目标版本的TecoDriver、TecoToolKit及TecoPyTorch。


 前提条件

   您已成功获取目标TecoPyTorch版本对应的TecoDriver和TecoToolKit安装包。


          提示：

              请使用与目标TecoPyTorch版本相匹配的TecoDriver和TecoToolkit，不匹配版本可能存在兼容性
              问题，导致TecoPyTorch无法正常使用。
              请切换至目标版本的《TecoPyTorch用户手册》，在安装依赖中获取目标TecoPyTorch版本相匹配
              的TecoDriver和TecoToolkit版本信息。
              请参考目标版本的《环境安装手册》（详情请参考《环境安装手册》的概述章节）获取相应的
              TecoDriver和TecoToolkit安装包。


   您已成功获取目标版本的TecoPyTorch相关安装包。


          说明：

          各版本的《TecoPyTorch用户手册》在其安装指南中提供了相应版本的TecoPyTorch安装包获取方法，
          请参考目标版本的《TecoPyTorch用户手册》获取。

   您已进入Python虚拟环境，可参考创建Python虚拟环境。

 操作步骤

  1. 卸载已安装的TecoDriver和TecoToolkit。


          说明：

          请参考《环境安装手册》（详情请参考《环境安装手册》的安装包简介章节）获取TecoToolkit和
          TecoDriver的卸载方法。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                   36

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     安装指南




 2. 安装目标版本的TecoDriver和TecoToolKit。


          说明：

          请参考《环境安装手册》（详情请参考《环境安装手册》的安装包简介章节）获取TecoToolkit和
          TecoDriver的安装方法。


 3. 升/降级TecoPyTorch相关安装包。

     a. 执行以下命令，升/降级PyTorch安装包。


           pip install -U <pytorch-name>.whl --force-reinstall



        其中： pytorch-name 表示目标版本的PyTorch安装包的名称。

     b. 执行以下命令，升/降级TecoPyTorch安装包。


           pip install -U <torch_sdaa-name>.whl --force-reinstall



        其中： torch_sdaa-name 表示目标版本的TecoPyTorch安装包的名称。

     c. 执行以下命令，升/降级torchvision安装包。


           pip install -U <torchvision-name>.whl --force-reinstall



        其中： torchvision-name 表示目标版本的torchvision安装包的名称。

 执行结果

执行以下命令，查看目标软件安装包是否成功升/降级。

   pip list | grep torch   # 升/降级成功后，可以查询到软件安装包的信息




3.3.1.1.3.5 卸载软件安装包
如果不再需要已安装的软件安装包时，可将其卸载。

 前提条件

您已成功安装torch_sdaa，可参考安装软件安装包。

 操作步骤

执行以下命令，卸载目标软件安装包。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司             37

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                        安装指南




   卸载PyTorch：

       pip uninstall torch


   卸载TecoPyTorch：

       pip uninstall torch_sdaa



   卸载torchvision：

       pip uninstall torchvision




 执行结果

执行以下命令，确认目标软件安装包已成功卸载。

   pip list | grep torch     # 卸载成功后，无法查询到软件安装包




3.3.1.2 Docker
3.3.1.2.1 安装依赖
本文主要介绍通过Docker安装TecoPyTorch时的依赖。

 环境依赖

 分类                                说明

 CPU型号                             龙芯 3C6000

 操作系统                              Loongnix Server 23.1

 Docker                            需自行安装


 软件资源依赖

 分类                                说明

 固件                                无需安装，太初AI加速卡出厂前已安装。

                                   需在宿主机上手动安装v3.2.0版本的TecoDriver，可参考环境安装手册
 TecoDriver
                                   （详情请参考《环境安装手册》的Intel/AMD CPU（x86_64）章节）。


3.3.1.2.2 安装准备


文档版本：v3.2.0                         版权所有 © 太初(无锡)电子科技有限公司                     38

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




安装TecoPyTorch前，请检查当前机器上是否安装过相关的依赖资源，以及版本是否正确。若安装的版本不满足要
求，请按照安装依赖提供的方法，重新安装。本文主要介绍如何查看当前机器上相关资源的安装情况。

 固件

  1. 执行以下命令，配置系统环境。


       source /opt/tecoai/setvars.sh



 2. 执行以下命令，查看固件是否已安装。


       teco-smi --query-device firmware_version --format=csv




 TecoDriver

执行以下命令，查看TecoDriver安装包的版本信息。

   rpm -qa | grep tecodriver




3.3.1.2.3 安装步骤
3.3.1.2.3.1 获取Docker镜像
在Docker中使用TecoPytorch前，需要获取目标Docker镜像。

 前提条件

您已经成功安装Docker工具。

 操作步骤

执行以下命令，下载Docker镜像至本地。

   wget http://wb.tecorigin.com:8082/repository/teco-docker-tar-repo/release/loongnix-server/23.1/loongarc
   h64/3.2.0/pytorch-3.2.0-torch_sdaa3.2.0.tar




 校验Docker镜像包

基于下载的镜像包生成MD5码，并与镜像包官方MD5码进行比较，确认下载镜像包的完整性。

执行以下命令，生成MD5码：

   md5sum pytorch-3.2.0-torch_sdaa3.2.0.tar




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                                                 39

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




 镜像包MD5码

Docker镜像包的官方MD5码信息如下：


 Docker镜像包                         MD5码

 pytorch-3.2.0-
                                   cef1440cbac14952607eb8e5a49c0c9e
 torch_sdaa3.2.0.tar



3.3.1.2.3.2 构建Docker容器
在Docker镜像下载到本地后，需要构建一个Docker容器。

 前提条件

您已成功获取Docker镜像，可参考获取Docker镜像。

 操作步骤

  1. 执行以下命令，导入Docker镜像。


       docker load < pytorch-3.2.0-torch_sdaa3.2.0.tar


 2. 执行以下命令，查看镜像是否导入成功。如果导入成功，可以查询到镜像信息。


       docker images | grep torch_sdaa



 3. 执行以下命令，构建Docker容器。


       docker run -itd --name="tecopytorch_docker" --net=host --device=/dev/tcaicard0 --device=/dev/tcaica
       rd1 --device=/dev/tcaicard2 --device=/dev/tcaicard3 --cap-add SYS_PTRACE --cap-add SYS_ADMIN --shm-
       size 64g jfrog.tecorigin.net/tecotp-docker/release/loongnixserver23.1/loongarch64/pytorch:3.2.0-tor
       ch_sdaa3.2.0 /bin/bash



   其中：

          -itd ：在后台运行容器，并与物理机保持交互状态。

          --name="tecopytorch_docker" ：设置Docker容器的名称，本示例中设置的容器名称为
          tecopytprch_docker 。

          --net=host ：设置容器的网络模式为                  host ，容器将直接使用主机的网络接口。

          --device=/dev/tcaicard0 --device=/dev/tcaicard1 --device=/dev/tcaicard2 --
       device=/dev/tcaicard3 ：用于将物理机指定的SDAA计算设备（SPA）挂载到容器中，使容器能够访
       问这些设备。本示例中挂载的设备
       为 /dev/tcaicard0 、 /dev/tcaicard1 、 /dev/tcaicard2 、 /dev/tcaicard3 。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               40

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                             安装指南




              提示：

              请根据物理机上实际可用的SDAA计算设备及实际需求，设置挂载的设备数量。


          --cap-add SYS_PTRACE --cap-add SYS_ADMIN ：设置允许容器访问物理机的系统跟踪功能。


              提示：

              设置该参数可能会增加容器被攻击的风险，需谨慎使用。


          --shm-size ：设置容器共享内存大小，建议设置为64G及以上内存大小。

        jfrog.tecorigin.net/tecotp-docker/release/loongnixserver23.1/loongarch64/pytorch:3.2.0-
        torch_sdaa3.2.0：导入后的Docker镜像名称。

          /bin/bash ：容器启动后要运行的命令。


 执行结果

执行以下命令，查看Docker容器是否创建成功。如果构建成功，可以查询到容器信息。

   docker ps -a | grep tecopytorch_docker




3.3.1.2.3.3 进入Docker容器
在Docker容器构建完成后，需要进入Docker容器，便可以使用TecoPytorch。

 前提条件

您已成功构建Docker容器，可参考构建Docker容器。

 操作步骤

执行以下命令，进入名称为 tecopytorch_docker 的Docker容器。

   docker exec -it tecopytorch_docker /bin/bash




3.3.1.2.3.4 验证TecoPytorch
本文介绍如何在Docker环境中验证TecoPytorch运行是否正常。

 前提条件



文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                       41

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                    安装指南




您已成功构建并进入Docker容器，可参考构建Docker容器和进入Docker容器。

 操作步骤

执行以下命令，验证TecoPytorch是否正常运行。

   python -c "import torch_sdaa"




 执行结果

如果终端成功输出TecoPytorch及其依赖的版本，表示TecoPytorch运行正常。


3.4 海光 7380/7375（x86_64）
3.4.1 Kylin V10 SP3
3.4.1.1 Conda+Pip安装
3.4.1.1.1 安装依赖
本文主要介绍安装TecoPyTorch时的依赖。

 环境依赖

 分类                                说明

 CPU型号                             海光7380/7375

 操作系统                              Kylin V10 SP3

 Python环境                          Python 3.10

 Conda版本                           Anaconda3-2022.05及以上版本


 软件资源依赖

 分类                                 说明

 固件                                 无需安装，芯片出厂前已安装。

                                    需手动安装，可参考环境安装手册（详情请参考《环境安装手册》的Kylin
 TecoDriver
                                    V10章节）。

                                    需手动安装，可参考环境安装手册（详情请参考《环境安装手册》的Kylin
 TecoToolKit
                                    V10章节）。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司               42

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                             安装指南




 版本对应关系

TecoPyTorch与依赖资源的TecoDriver和TecoToolKit版本对应关系如下：


     说明：

     TecoDriver和TecoToolKit各自包含的组件版本信息，例如SDAADriver、TecoCC和TCCL等，可参考环境
     安装手册中的版本信息（详情请参考《环境安装手册》的版本信息章节）。


 TecoPyTorch                            TecoDriver             TecoToolKit

 v3.2.0                                 v3.2.0                 v3.2.0



3.4.1.1.2 安装准备
安装TecoPyTorch前，请检查当前机器上是否安装过相关的依赖资源，以及版本是否正确。若安装的版本不满足要
求，请按照安装依赖提供的方法，重新安装。本文主要介绍如何查看当前机器上相关资源的安装情况。

 固件

  1. 执行以下命令，配置系统环境。


       source /opt/tecoai/setvars.sh



 2. 执行以下命令，查看固件是否已安装。


       teco-smi --query-device firmware_version --format=csv




 TecoDriver

执行以下命令，查看TecoDriver安装包的版本信息。

   rpm -qa | grep tecodriver




 TecoToolKit

执行以下命令，查看TecoToolKit安装包的版本信息。

   rpm -qa | grep tecotoolkit




3.4.1.1.3 安装TecoPyTorch
3.4.1.1.3.1 创建Anaconda环境


文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                    43

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




本文主要介绍如何创建用于安装TecoPytorch的Anaconda虚拟环境。

 前提条件

   您已成功安装规定版本的Anaconda软件，详情参考安装依赖。

   您已成功安装规定版本的Python语言，详情参考安装依赖。

 操作步骤

  1. 执行以下命令，创建Anaconda虚拟环境。


       conda create -n teco-pytorch python==3.10



 2. 执行以下命令，进入Anaconda虚拟环境。


       conda activate teco-pytorch



 3. 执行以下命令，安装TecoPytorch所需环境依赖包。


       conda install astunparse numpy=1.23.5 ninja pyyaml mkl=2023.1.0 mkl-include cmake cffi typing_exten
       sions future six requests dataclasses




3.4.1.1.3.2 获取软件安装包
在安装TecoPyTorch前，需要获取目标软件安装包。

 操作步骤

执行以下命令，下载TecoPyTorch相关安装包至本地。

   下载PyTorch安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-spe-pypi-repo/kylinv10/torch-2.7.1%2Bcpu.cxx11.ab
       i-cp310-cp310-linux_x86_64.whl



   下载TecoPyTorch安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-spe-pypi-repo/kylinv10/torch_sdaa-3.2.0-cp310-cp3
       10-linux_x86_64.whl



   下载torchvision安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-spe-pypi-repo/kylinv10/torchvision-0.22.1%2Bcpu-c
       p310-cp310-manylinux_2_28_x86_64.whl




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                                44

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                  安装指南




 校验安装包

基于下载的软件安装包生成MD5码，并与安装包官方MD5码进行比较，确认下载安装包的完整性。

以TecoPyTorch安装包为例，生成安装包MD5的命令如下：

   md5sum torch_sdaa-3.2.0-cp310-cp310-linux_x86_64.whl




 安装包MD5码

TecoPyTorch相关安装包的官方MD5码信息如下：


 安装包                               MD5码

 PyTorch安装包                        d7b21907a66df07938a15bb7b3f91953

 TecoPyTorch安装包                    b3bc58e9ce836c73c898dc85b8c9ed7e

 torchvision安装包                    a15dcea8f9cab9d1a9b08244c8dcb5ef



3.4.1.1.3.3 安装软件安装包
获取软件安装包后，可对其进行安装。

 前提条件

   您已成功获取PyTorch、TecoPytorch、torchvision和torchaudio的软件安装包，可参考获取软件安装包。

   您已成功创建并进入Anconda虚拟环境，可参考创建Anaconda环境。

 操作步骤

执行以下命令，安装软件包。

  1. 安装PyTorch：


       pip install torch-2.7.1+cpu.cxx11.abi-cp310-cp310-linux_x86_64.whl


 2. 安装TecoPytorch：


       pip install torch_sdaa-3.2.0-cp310-cp310-linux_x86_64.whl



 3. 安装torchvision：


       pip install torchvision-0.22.1+cpu-cp310-cp310-manylinux_2_28_x86_64.whl




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                          45

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     安装指南




 执行结果

执行以下命令，查看目标软件安装包是否成功安装。

   pip list | grep torch   # 安装成功后，可以查询到软件安装包的信息




3.4.1.1.3.4 升/降级软件安装包
如果已安装的软件安装包不满足使用需求时，可对其进行升/降级。

 注意事项

TecoPyTorch采用先卸载再安装的方式进行升降级，您需要卸载已经安装的TecoPyTorch安装包、TecoDriver和
TecoToolKit包，再安装目标版本的TecoDriver、TecoToolKit及TecoPyTorch。


 前提条件

   您已成功获取目标TecoPyTorch版本对应的TecoDriver和TecoToolKit安装包。


          提示：

              请使用与目标TecoPyTorch版本相匹配的TecoDriver和TecoToolkit，不匹配版本可能存在兼容性
              问题，导致TecoPyTorch无法正常使用。
              请切换至目标版本的《TecoPyTorch用户手册》，在安装依赖中获取目标TecoPyTorch版本相匹配
              的TecoDriver和TecoToolkit版本信息。
              请参考目标版本的《环境安装手册》（详情请参考《环境安装手册》的安装包简介章节）获取相应的
              TecoDriver和TecoToolkit安装包。


   您已成功获取目标版本的TecoPyTorch相关安装包。


          说明：

          各版本的《TecoPyTorch用户手册》在其安装指南中提供了相应版本的TecoPyTorch安装包获取方法，
          请参考目标版本的《TecoPyTorch用户手册》获取。

   您已成功进入Anconda虚拟环境，可参考创建Anaconda环境。

 操作步骤

  1. 卸载已安装的TecoDriver和TecoToolkit。


          说明：




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                   46

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     安装指南




          请参考《环境安装手册》（详情请参考《环境安装手册》的安装包简介章节）获取TecoToolkit和
          TecoDriver的卸载方法。


 2. 安装目标版本的TecoDriver和TecoToolKit。


          说明：

          请参考《环境安装手册》（详情请参考《环境安装手册》的安装包简介章节）获取TecoToolkit和
          TecoDriver的安装方法。


 3. 升/降级TecoPyTorch相关安装包。

     a. 执行以下命令，升/降级PyTorch安装包。


           pip install -U <pytorch-name>.whl --force-reinstall



        其中： pytorch-name 表示目标版本的PyTorch安装包的名称。

     b. 执行以下命令，升/降级TecoPyTorch安装包。


           pip install -U <torch_sdaa-name>.whl --force-reinstall



        其中： torch_sdaa-name 表示目标版本的TecoPyTorch安装包的名称。

     c. 执行以下命令，升/降级torchvision安装包。


           pip install -U <torchvision-name>.whl --force-reinstall



        其中： torchvision-name 表示目标版本的torchvision安装包的名称。

 执行结果

执行以下命令，查看目标软件安装包是否成功升/降级。

   pip list | grep torch   # 升/降级成功后，可以查询到软件安装包的信息




3.4.1.1.3.5 卸载软件安装包
如果不再需要已安装的软件安装包时，可将其卸载。

 前提条件

您已成功安装torch_sdaa，可参考安装软件安装包。

 操作步骤


文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司             47

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                         安装指南




执行以下命令，卸载目标软件安装包。

   卸载PyTorch：

       pip uninstall torch



   卸载TecoPyTorch：

       pip uninstall torch_sdaa



   卸载torchvision：

       pip uninstall torchvision




 执行结果

执行以下命令，确认目标软件安装包已成功卸载。

   pip list | grep torch     # 卸载成功后，无法查询到软件安装包




3.4.1.2 Docker安装
3.4.1.2.1 安装依赖
本文主要介绍通过Docker安装TecoPyTorch时的依赖。

 环境依赖

 分类                                说明

 CPU型号                             海光7380/7375

 操作系统                              Kylin V10 SP3

 Docker                            需自行安装


 软件资源依赖

 分类                                说明

 固件                                无需安装，芯片出厂前已安装。

                                   需在宿主机上手动安装v3.2.0版本的TecoDriver，可参考环境安装手册
 TecoDriver
                                   （详情请参考《环境安装手册》的TecoDriver安装指南章节）。




文档版本：v3.2.0                         版权所有 © 太初(无锡)电子科技有限公司                    48

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




3.4.1.2.2 安装准备
安装TecoPyTorch前，请检查当前机器上是否安装过相关的依赖资源，以及版本是否正确。若安装的版本不满足要
求，请按照安装依赖提供的方法，重新安装。本文主要介绍如何查看当前机器上相关资源的安装情况。

 固件

  1. 执行以下命令，配置系统环境。


       source /opt/tecoai/setvars.sh



 2. 执行以下命令，查看固件是否已安装。


       teco-smi --query-device firmware_version --format=csv




 TecoDriver

执行以下命令，查看TecoDriver安装包的版本信息。

   rpm -qa | grep tecodriver




3.4.1.2.3 安装步骤
3.4.1.2.3.1 获取Docker镜像
在Docker中使用TecoPyTorch前，需要获取目标Docker镜像。

 前提条件

您已经成功安装Docker工具。

 操作步骤

执行以下命令，下载Docker镜像至本地。

   wget http://wb.tecorigin.com:8082/repository/teco-docker-tar-repo/release/kylin_v10/x86_64/3.2.0/pytorc
   h-3.2.0-torch_sdaa3.2.0.tar




 校验Docker镜像包

基于下载的镜像包生成MD5码，并与镜像包官方MD5码进行比较，确认下载镜像包的完整性。

执行以下命令，生成MD5码：




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                                                 49

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




   md5sum pytorch-3.2.0-torch_sdaa3.2.0.tar




 镜像包MD5码

Docker镜像包的官方MD5码信息如下：


 Docker镜像包                         MD5码

 pytorch-3.2.0-
                                   8a4eab7caec483b75c555c0898bdc3d7
 torch_sdaa3.2.0.tar



3.4.1.2.3.2 构建Docker容器
在Docker镜像下载到本地后，需要构建一个Docker容器。

 前提条件

您已成功获取Docker镜像，可参考获取Docker镜像。

 操作步骤

  1. 执行以下命令，导入Docker镜像。


       docker load < pytorch-3.2.0-torch_sdaa3.2.0.tar



 2. 执行以下命令，查看镜像是否导入成功。如果导入成功，可以查询到镜像信息。


       docker images | grep torch_sdaa



 3. 执行以下命令，构建Docker容器。


       docker run -itd --name="tecopytorch_docker" --net=host --device=/dev/tcaicard0 --device=/dev/tcaica
       rd1 --device=/dev/tcaicard2 --device=/dev/tcaicard3 --cap-add SYS_PTRACE --cap-add SYS_ADMIN --shm-
       size 64g jfrog.tecorigin.net/tecotp-docker/release/kylin_v10/x86_64/pytorch:3.2.0-torch_sdaa3.2.0 /
       bin/bash



   其中：

          -itd ：在后台运行容器，并与物理机保持交互状态。

          --name="tecopytorch_docker" ：设置Docker容器的名称，本示例中设置的容器名称为
          tecopytprch_docker 。

          --net=host ：设置容器的网络模式为                  host ，容器将直接使用主机的网络接口。

          --device=/dev/tcaicard0 --device=/dev/tcaicard1 --device=/dev/tcaicard2 --
        device=/dev/tcaicard3 ：用于将物理机指定的T1计算设备（SPA）挂载到容器中，使容器能够访问这




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               50

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                           安装指南




        些设备。本示例中挂载的设备
        为 /dev/tcaicard0 、 /dev/tcaicard1 、 /dev/tcaicard2 、 /dev/tcaicard3 。

              提示：

              请根据物理机上实际可用的T1计算设备及实际需求，设置挂载的设备数量。


          --cap-add SYS_PTRACE --cap-add SYS_ADMIN ：设置允许容器访问物理机的系统跟踪功能。


              提示：

              设置该参数可能会增加容器被攻击的风险，需谨慎使用。


          --shm-size ：设置容器中共享内存大小，建议设置为64G及以上内存大小。

        jfrog.tecorigin.net/tecotp-docker/release/kylin_v10/x86_64/pytorch:3.2.0-torch_sdaa3.2.0：导
        入后的Docker镜像名称。
          /bin/bash ：容器启动后要运行的命令。


 执行结果

执行以下命令，查看Docker容器是否创建成功。如果构建成功，可以查询到容器信息。

   docker ps -a | grep tecopytorch_docker




3.4.1.2.3.3 进入Docker容器
在Docker容器构建完成后，需要进入Docker容器，便可以使用TecoPytorch。

 前提条件

您已成功构建Docker容器，可参考构建Docker容器。

 操作步骤

执行以下命令，进入名称为 tecopytorch_docker 的Docker容器。

   docker exec -it tecopytorch_docker /bin/bash




3.4.1.2.3.4 验证TecoPyTorch
本文介绍如何在Docker环境中验证TecoPytorch运行是否正常。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                     51

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                安装指南




 前提条件

您已成功构建并进入Docker容器，可参考构建Docker容器和进入Docker容器。

 操作步骤

  1. 执行以下命令，进入TecoPytorch环境。


       conda activate torch_env



 2. 执行以下命令，验证TecoPytorch是否正常运行。


       python -c "import torch_sdaa"




 执行结果

如果终端成功输出TecoPytorch及其依赖的版本，表示TecoPytorch运行正常。


3.5 飞腾 S5000C
3.5.1 Kylin V10（国防版）
3.5.1.1 Conda+Pip安装
3.5.1.1.1 安装依赖
本文主要介绍安装TecoPyTorch时的依赖。

 环境依赖

 分类                                    说明

 CPU型号                                 飞腾 S5000C

 操作系统                                  Kylin V10（国防版）

 Python环境                              Python 3.10

 Conda版本                               Anaconda3-2022.05及以上版本


 软件资源依赖

 分类                                    说明

 固件                                    无需安装，芯片出厂前已安装。



文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司       52

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                             安装指南




 分类                                    说明

                                       需手动安装，可参考环境安装手册（详情请参考《环境安装手册》的Kylin
 TecoDriver
                                       V10章节）。

                                       需手动安装，可参考环境安装手册（详情请参考《环境安装手册》的Kylin
 TecoToolKit
                                       V10章节）。


 版本对应关系

TecoPyTorch与依赖资源的TecoDriver和TecoToolKit版本对应关系如下：


     说明：

     TecoDriver和TecoToolKit各自包含的组件版本信息，例如SDAADriver、TecoCC和TCCL等，可参考环境
     安装手册中的版本信息（详情请参考《环境安装手册》的版本信息章节）。


 TecoPyTorch                            TecoDriver             TecoToolKit

 v3.2.0                                 v3.2.0                 v3.2.0



3.5.1.1.2 安装准备
安装TecoPyTorch前，请检查当前机器上是否安装过相关的依赖资源，以及版本是否正确。若安装的版本不满足要
求，请按照安装依赖提供的方法，重新安装。本文主要介绍如何查看当前机器上相关资源的安装情况。

 固件

  1. 执行以下命令，配置系统环境。


       source /opt/tecoai/setvars.sh



 2. 执行以下命令，查看固件是否已安装。


       teco-smi --query-device firmware_version --format=csv




 TecoDriver

执行以下命令，查看TecoDriver安装包的版本信息。

   rpm -qa | grep tecodriver




 TecoToolKit



文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                    53

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




执行以下命令，查看TecoToolKit安装包的版本信息。

   rpm -qa | grep tecotoolkit




3.5.1.1.3 安装TecoPyTorch
3.5.1.1.3.1 创建Anaconda环境
本文主要介绍如何创建用于安装TecoPytorch的Anaconda虚拟环境。

 前提条件

   您已成功安装规定版本的Anaconda软件，详情参考安装依赖。

   您已成功安装规定版本的Python语言，详情参考安装依赖。

 操作步骤

  1. 执行以下命令，创建Anaconda虚拟环境。


       conda create -n teco-pytorch python==3.10



 2. 执行以下命令，进入Anaconda虚拟环境。


       conda activate teco-pytorch



 3. 执行以下命令，安装TecoPytorch所需环境依赖包。


       conda install astunparse numpy ninja pyyaml cmake cffi typing_extensions future six requests datacl
       asses




3.5.1.1.3.2 获取软件安装包
在安装TecoPyTorch前，需要获取目标软件安装包。

 操作步骤

执行以下命令，下载TecoPyTorch相关安装包至本地。

   下载PyTorch安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-pypi-repo/packages/torch/2.7.1/torch-2.7.1-cp310-
       cp310-linux_aarch64.whl




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                  54

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




   下载TecoPyTorch安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-spe-pypi-repo/kylinv10/aarch64/torch_sdaa-3.2.0-c
       p310-cp310-linux_aarch64.whl


   下载torchvision安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-pypi-repo/packages/torchvision/0.22.1+59a3e1f/tor
       chvision-0.22.1+59a3e1f-cp310-cp310-linux_aarch64.whl




 校验安装包

基于下载的软件安装包生成MD5码，并与安装包官方MD5码进行比较，确认下载安装包的完整性。

以TecoPyTorch安装包为例，生成安装包MD5的命令如下：

   md5sum torch_sdaa-3.2.0-cp310-cp310-linux_aarch64.whl




 安装包MD5码

TecoPyTorch相关安装包的官方MD5码信息如下：


 安装包                                  MD5码

 PyTorch安装包                           4e8b25872d8c18a6dcd839ffe9cc81e2

 TecoPyTorch安装包                       74ffdce8871707e66e69dcc12b935672

 torchvision安装包                       c70282bd622efbf08fbf3021f0786a2f



3.5.1.1.3.3 安装软件安装包
获取软件安装包后，可对其进行安装。

 前提条件

   您已成功获取PyTorch、TecoPytorch、torchvision和torchaudio的软件安装包，可参考获取软件安装包。

   您已成功创建并进入Anconda虚拟环境，可参考创建Anaconda环境。

 操作步骤

执行以下命令，安装软件包。

  1. 安装PyTorch：




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                                55

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                              安装指南




       pip install torch-2.7.1-cp310-cp310-linux_aarch64.whl



 2. 安装TecoPytorch：


       pip install torch_sdaa-3.2.0-cp310-cp310-linux_x86_64.whl



 3. 安装torchvision：


       pip install torchvision-0.22.1+59a3e1f-cp310-cp310-linux_aarch64.whl




 执行结果

执行以下命令，查看目标软件安装包是否成功安装。

   pip list | grep torch   # 安装成功后，可以查询到软件安装包的信息




3.5.1.1.3.4 升/降级软件安装包
如果已安装的软件安装包不满足使用需求时，可对其进行升/降级。

 注意事项

TecoPyTorch采用先卸载再安装的方式进行升降级，您需要卸载已经安装的TecoPyTorch安装包、TecoDriver和
TecoToolKit包，再安装目标版本的TecoDriver、TecoToolKit及TecoPyTorch。


 前提条件

   您已成功获取目标TecoPyTorch版本对应的TecoDriver和TecoToolKit安装包。


          提示：

              请使用与目标TecoPyTorch版本相匹配的TecoDriver和TecoToolkit，不匹配版本可能存在兼容性
              问题，导致TecoPyTorch无法正常使用。
              请切换至目标版本的《TecoPyTorch用户手册》，在安装依赖中获取目标TecoPyTorch版本相匹配
              的TecoDriver和TecoToolkit版本信息。
              请参考目标版本的《环境安装手册》（详情请参考《环境安装手册》的安装包简介章节）获取相应的
              TecoDriver和TecoToolkit安装包。


   您已成功获取目标版本的TecoPyTorch相关安装包。


          说明：




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                      56

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     安装指南




          各版本的《TecoPyTorch用户手册》在其安装指南中提供了相应版本的TecoPyTorch安装包获取方法，
          请参考目标版本的《TecoPyTorch用户手册》获取。

   您已成功进入Anconda虚拟环境，可参考创建Anaconda环境。

 操作步骤

  1. 卸载已安装的TecoDriver和TecoToolkit。


          说明：

          请参考《环境安装手册》（详情请参考《环境安装手册》的安装包简介章节）获取TecoToolkit和
          TecoDriver的卸载方法。


 2. 安装目标版本的TecoDriver和TecoToolKit。


          说明：

          请参考《环境安装手册》（详情请参考《环境安装手册》的安装包简介章节）获取TecoToolkit和
          TecoDriver的安装方法。


 3. 升/降级TecoPyTorch相关安装包。

     a. 执行以下命令，升/降级PyTorch安装包。


           pip install -U <pytorch-name>.whl --force-reinstall



        其中： pytorch-name 表示目标版本的PyTorch安装包的名称。

     b. 执行以下命令，升/降级TecoPyTorch安装包。


           pip install -U <torch_sdaa-name>.whl --force-reinstall



        其中： torch_sdaa-name 表示目标版本的TecoPyTorch安装包的名称。

     c. 执行以下命令，升/降级torchvision安装包。


           pip install -U <torchvision-name>.whl --force-reinstall



        其中： torchvision-name 表示目标版本的torchvision安装包的名称。

 执行结果

执行以下命令，查看目标软件安装包是否成功升/降级。

   pip list | grep torch   # 升/降级成功后，可以查询到软件安装包的信息




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司             57

TecoPyTorch用户手册（适配PyTorch 2.7.1）                            安装指南




3.5.1.1.3.5 卸载软件安装包
如果不再需要已安装的软件安装包时，可将其卸载。

 前提条件

您已成功安装torch_sdaa，可参考安装软件安装包。

 操作步骤

执行以下命令，卸载目标软件安装包。

   卸载PyTorch：

       pip uninstall torch



   卸载TecoPyTorch：

       pip uninstall torch_sdaa



   卸载torchvision：

       pip uninstall torchvision




 执行结果

执行以下命令，确认目标软件安装包已成功卸载。

   pip list | grep torch     # 卸载成功后，无法查询到软件安装包




3.5.1.2 Docker安装
3.5.1.2.1 安装依赖
本文主要介绍通过Docker安装TecoPyTorch时的依赖。

 环境依赖

 分类                                说明

 CPU型号                             飞腾 S5000C

 操作系统                              Kylin V10（国防版）




文档版本：v3.2.0                         版权所有 © 太初(无锡)电子科技有限公司      58

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                             安装指南




 分类                                    说明

 Docker                                需自行安装


 软件资源依赖

 分类                                    说明

 固件                                    无需安装，芯片出厂前已安装。

                                       需在宿主机上手动安装v3.2.0版本的TecoDriver，可参考环境安装手册
 TecoDriver
                                       （详情请参考《环境安装手册》的TecoDriver安装指南章节）。


3.5.1.2.2 安装准备
安装TecoPyTorch前，请检查当前机器上是否安装过相关的依赖资源，以及版本是否正确。若安装的版本不满足要
求，请按照安装依赖提供的方法，重新安装。本文主要介绍如何查看当前机器上相关资源的安装情况。

 固件

  1. 执行以下命令，配置系统环境。


       source /opt/tecoai/setvars.sh



 2. 执行以下命令，查看固件是否已安装。


       teco-smi --query-device firmware_version --format=csv




 TecoDriver

执行以下命令，查看TecoDriver安装包的版本信息。

   rpm -qa | grep tecodriver




3.5.1.2.3 安装步骤
3.5.1.2.3.1 获取Docker镜像
在Docker中使用TecoPyTorch前，需要获取目标Docker镜像。

 前提条件

您已经成功安装Docker工具。




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                     59

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




 操作步骤

执行以下命令，下载Docker镜像至本地。

   wget http://wb.tecorigin.com:8082/repository/teco-docker-tar-repo/release/kylin_v10/aarch64/3.2.0/pytor
   ch-3.2.0-torch_sdaa3.2.0.tar




 校验Docker镜像包

基于下载的镜像包生成MD5码，并与镜像包官方MD5码进行比较，确认下载镜像包的完整性。

执行以下命令，生成MD5码：

   md5sum pytorch-3.2.0-torch_sdaa3.2.0.tar




 镜像包MD5码

Docker镜像包的官方MD5码信息如下：


 Docker镜像包                         MD5码

 pytorch-3.2.0-
                                   d240f3402c6537c08308c589c8946855
 torch_sdaa3.2.0.tar



3.5.1.2.3.2 构建Docker容器
在Docker镜像下载到本地后，需要构建一个Docker容器。

 前提条件

您已成功获取Docker镜像，可参考获取Docker镜像。

 操作步骤

  1. 执行以下命令，导入Docker镜像。


       docker load < pytorch-3.2.0-torch_sdaa3.2.0.tar



 2. 执行以下命令，查看镜像是否导入成功。如果导入成功，可以查询到镜像信息。


       docker images | grep torch_sdaa



 3. 执行以下命令，构建Docker容器。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               60

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




       docker run -itd --name="tecopytorch_docker" --net=host --device=/dev/tcaicard0 --device=/dev/tcaica
       rd1 --device=/dev/tcaicard2 --device=/dev/tcaicard3 --cap-add SYS_PTRACE --cap-add SYS_ADMIN --shm-
       size 64g jfrog.tecorigin.net/tecotp-docker/release/kylin_v10/phytium_aarch64/pytorch:3.2.0-torch_sd
       aa3.2.0 /bin/bash



   其中：

          -itd ：在后台运行容器，并与物理机保持交互状态。

          --name="tecopytorch_docker" ：设置Docker容器的名称，本示例中设置的容器名称为
          tecopytprch_docker 。

          --net=host ：设置容器的网络模式为                  host ，容器将直接使用主机的网络接口。

          --device=/dev/tcaicard0 --device=/dev/tcaicard1 --device=/dev/tcaicard2 --
        device=/dev/tcaicard3 ：用于将物理机指定的T1计算设备（SPA）挂载到容器中，使容器能够访问这
        些设备。本示例中挂载的设备
        为 /dev/tcaicard0 、 /dev/tcaicard1 、 /dev/tcaicard2 、 /dev/tcaicard3 。

              提示：

              请根据物理机上实际可用的T1计算设备及实际需求，设置挂载的设备数量。


          --cap-add SYS_PTRACE --cap-add SYS_ADMIN ：设置允许容器访问物理机的系统跟踪功能。


              提示：

              设置该参数可能会增加容器被攻击的风险，需谨慎使用。


          --shm-size ：设置容器中共享内存大小，建议设置为64G及以上内存大小。

        jfrog.tecorigin.net/tecotp-docker/release/kylin_v10/phytium_aarch64/pytorch:3.2.0-
        torch_sdaa3.2.0：导入后的Docker镜像名称。

          /bin/bash ：容器启动后要运行的命令。


 执行结果

执行以下命令，查看Docker容器是否创建成功。如果构建成功，可以查询到容器信息。

   docker ps -a | grep tecopytorch_docker




3.5.1.2.3.3 进入Docker容器
在Docker容器构建完成后，需要进入Docker容器，便可以使用TecoPytorch。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                  61

TecoPyTorch用户手册（适配PyTorch 2.7.1）                               安装指南




 前提条件

您已成功构建Docker容器，可参考构建Docker容器。

 操作步骤

执行以下命令，进入名称为 tecopytorch_docker 的Docker容器。

   docker exec -it tecopytorch_docker /bin/bash




3.5.1.2.3.4 验证TecoPytorch
本文介绍如何在Docker环境中验证TecoPytorch运行是否正常。

 前提条件

您已成功构建并进入Docker容器，可参考构建Docker容器和进入Docker容器。

 操作步骤

  1. 执行以下命令，进入TecoPytorch环境。


       conda activate torch_env



 2. 执行以下命令，验证TecoPytorch是否正常运行。


       python -c "import torch_sdaa"




 执行结果

如果终端成功输出TecoPytorch及其依赖的版本，表示TecoPytorch运行正常。




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司      62

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                       环境变量
