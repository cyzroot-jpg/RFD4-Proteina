---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p02
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第2部分 (ch3-install-x86-sw64)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "967-2500"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, install, conda, pip, docker, x86-64, sw64]
---

# TecoPyTorch 用户手册 v3.2.0（第2部分）

> 原文行范围：`967-2500`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

3. 安装指南
3.1 Intel/AMD（x86_64）
3.1.1 Ubuntu 22.04
3.1.1.1 Conda+Pip安装
3.1.1.1.1 安装依赖
本文主要介绍安装TecoPyTorch时的依赖。

 环境依赖

 分类                            说明

 操作系统                          Ubuntu 22.04

 Python环境                      Python 3.10

 Conda版本                       Anaconda3-2022.10及以上版本


 软件资源依赖

 分类                                说明

 固件                                无需安装，太初AI加速卡出厂前已安装。

                                   需手动安装，可参考环境安装手册（详情请参考《环境安装手册》的
 TecoDriver
                                   Intel/AMD CPU（x86_64）章节）。

                                   需手动安装，可参考环境安装手册（详情请参考《环境安装手册》的
 TecoToolKit
                                   Intel/AMD CPU（x86_64）章节）。


 版本对应关系

TecoPyTorch与依赖资源的TecoDriver和TecoToolKit版本对应关系如下：


     说明：

     TecoDriver和TecoToolKit各自包含的组件版本信息，例如SDAADriver、TecoCC和TCCL等，可参考环境
     安装手册中的版本信息（详情请参考《环境安装手册》的版本信息章节）。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                 10

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                             安装指南




 TecoPyTorch                            TecoDriver             TecoToolKit

 v3.2.0                                 v3.2.0                 v3.2.0



3.1.1.1.2 安装准备
安装TecoPyTorch前，请检查当前机器上是否安装过相关的依赖资源，以及版本是否正确。若安装的版本不满足要
求，请按照安装依赖提供的方法，重新安装。本文主要介绍如何查看当前机器上相关资源的安装情况。

 固件

  1. 执行以下命令，配置系统环境。


       source /opt/tecoai/setvars.sh


 2. 执行以下命令，查看固件是否已安装。


       teco-smi --query-device firmware_version --format=csv




 TecoDriver

执行以下命令，查看TecoDriver安装包的版本信息。

   dpkg -l | grep tecodriver




 TecoToolKit

执行以下命令，查看TecoToolKit安装包的版本信息。

   dpkg -l | grep tecotoolkit




3.1.1.1.3 安装TecoPyTorch
3.1.1.1.3.1 创建Anaconda环境
本文主要介绍如何创建用于安装TecoPytorch的Anaconda虚拟环境。

 前提条件

   您已成功安装规定版本的Anaconda软件，详情参考安装依赖。

   您已成功安装规定版本的Python语言，详情参考安装依赖。

 操作步骤


文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                    11

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




  1. 执行以下命令，创建Anaconda虚拟环境。


       conda create -n teco-pytorch python=3.10


 2. 执行以下命令，进入Anaconda虚拟环境。


       conda activate teco-pytorch


 3. 执行以下命令，安装TecoPytorch所需环境依赖包。


       conda install numpy=1.23.5




3.1.1.1.3.2 获取软件安装包
在安装TecoPyTorch前，需要获取目标软件安装包。

 操作步骤

执行以下命令，下载TecoPyTorch相关安装包至本地。

   下载PyTorch安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-pypi-repo/packages/torch/2.7.1%2Bcpu.cxx11.abi/to
       rch-2.7.1%2Bcpu.cxx11.abi-cp310-cp310-linux_x86_64.whl



   下载TecoPyTorch安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-pypi-repo/packages/torch-sdaa/3.2.0/torch_sdaa-3.
       2.0-cp310-cp310-linux_x86_64.whl



   下载torchvision安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-pypi-repo/packages/torchvision/0.22.1%2Bcpu/torch
       vision-0.22.1%2Bcpu-cp310-cp310-manylinux_2_28_x86_64.whl



   下载torchaudio安装包：

       wget http://jfrog.tecorigin.net/artifactory/Teco-py310-whl/Ubuntu/22.04/Intel_AMD_x86_64/TecoPyTorc
       h/3.1.0/beta/3.1.0b0/15/torchaudio-2.7.1%2Bcpu-cp310-cp310-manylinux_2_28_x86_64.whl



   （可选）下载torchdata安装包：

       wget http://jfrog.tecorigin.net/artifactory/Teco-py310-whl/Ubuntu/22.04/Intel_AMD_x86_64/TecoPyTorc
       h/3.1.0/beta/3.1.0b0/15/torchdata-0.10.0-py3-none-any.whl




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                  12

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




   （可选）下载torchtext安装包：

       wget http://jfrog.tecorigin.net/artifactory/Teco-py310-whl/Ubuntu/22.04/Intel_AMD_x86_64/TecoPyTorc
       h/3.1.0/beta/3.1.0b0/15/torchtext-0.18.0-cp310-cp310-linux_x86_64.whl




 校验安装包

基于下载的软件安装包生成MD5码，并与安装包官方MD5码进行比较，确认下载安装包的完整性。

以TecoPyTorch安装包为例，生成安装包MD5的命令如下：

   md5sum torch_sdaa-3.2.0-cp310-cp310-linux_x86_64.whl




 安装包MD5码

TecoPyTorch相关安装包的官方MD5码信息如下：


 安装包                               MD5码

 PyTorch安装包                        d7b21907a66df07938a15bb7b3f91953

 TecoPyTorch安装包                    3ecda1f78860972dbb44a8af64c44146

 torchvision安装包                    a15dcea8f9cab9d1a9b08244c8dcb5ef

 torchaudio安装包                     ca7eb5eebd6d928fa287ec96895e4c89

 torchdata安装包                      f681a4725bb19c78b198d394c9c76932

 torchtext安装包                      279c457b1cbee80b732594ca4e87531a



3.1.1.1.3.3 安装软件安装包
获取软件安装包后，可对其进行安装。

 前提条件

   您已成功获取PyTorch、TecoPytorch、torchvision和torchaudio的软件安装包，可参考获取软件安装包。

   您已成功创建并进入Anconda虚拟环境，可参考创建Anaconda环境。

 操作步骤

执行以下命令，安装软件包。

  1. 安装PyTorch：




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                  13

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                  安装指南




       pip install torch-2.7.1+cpu.cxx11.abi-cp310-cp310-linux_x86_64.whl



 2. 安装TecoPytorch：


       pip install torch_sdaa-3.2.0-cp310-cp310-linux_x86_64.whl



 3. 安装torchvision：


       pip install torchvision-0.22.1+cpu-cp310-cp310-manylinux_2_28_x86_64.whl



 4. 安装torchaudio：


       pip install torchaudio-2.7.1+cpu-cp310-cp310-manylinux_2_28_x86_64.whl


 5. （可选）安装torchdata：


       pip install torchdata-0.10.0-py3-none-any.whl


 6. （可选）安装torchtext：


          提示：

          安装torchtext前，需要先安装torchdata。


       pip install torchtext-0.18.0-cp310-cp310-linux_x86_64.whl




 执行结果

执行以下命令，查看目标软件安装包是否成功安装。

   pip list | grep torch   # 安装成功后，可以查询到软件安装包的信息




3.1.1.1.3.4 升/降级软件安装包
如果已安装的软件安装包不满足使用需求时，可对其进行升/降级。

 注意事项

TecoPyTorch采用先卸载再安装的方式进行升降级，您需要卸载已经安装的TecoPyTorch安装包、TecoDriver和
TecoToolKit包，再安装目标版本的TecoDriver、TecoToolKit及TecoPyTorch。


 前提条件

   您已成功获取目标TecoPyTorch版本对应的TecoDriver和TecoToolKit安装包。



文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                          14

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     安装指南




         提示：

              请使用与目标TecoPyTorch版本相匹配的TecoDriver和TecoToolkit，不匹配版本可能存在兼容性
              问题，导致TecoPyTorch无法正常使用。
              请切换至目标版本的《TecoPyTorch用户手册》，在安装依赖中获取目标TecoPyTorch版本相匹配
              的TecoDriver和TecoToolkit版本信息。
              请参考目标版本的《环境安装手册》（详情请参考《环境安装手册》的Intel/AMD CPU
              （x86_64）章节）获取相应的TecoDriver和TecoToolkit安装包。


   您已成功获取目标版本的TecoPyTorch相关安装包。


         说明：

         各版本的《TecoPyTorch用户手册》在其安装指南中提供了相应版本的TecoPyTorch安装包获取方法，
         请参考目标版本的《TecoPyTorch用户手册》获取。

   您已成功进入Anconda虚拟环境，可参考创建Anaconda环境。

 操作步骤

  1. 卸载已安装的TecoDriver和TecoToolkit。


         说明：

         请参考《环境安装手册》（详情请参考《环境安装手册》的Intel/AMD CPU（x86_64）章节）获取
         TecoToolkit和TecoDriver的卸载方法。


 2. 安装目标版本的TecoDriver和TecoToolKit。


         说明：

         请参考《环境安装手册》（详情请参考《环境安装手册》的Intel/AMD CPU（x86_64）章节）获取
         TecoToolkit和TecoDriver的安装方法。


 3. 升/降级TecoPyTorch相关安装包。

     a. 执行以下命令，升/降级PyTorch安装包。


          pip install -U <pytorch-name>.whl --force-reinstall


       其中： pytorch-name 表示目标版本的PyTorch安装包的名称。

     b. 执行以下命令，升/降级TecoPyTorch安装包。




文档版本：v3.2.0                          版权所有 © 太初(无锡)电子科技有限公司                 15

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     安装指南




           pip install -U <torch_sdaa-name>.whl --force-reinstall


        其中： torch_sdaa-name 表示目标版本的TecoPyTorch安装包的名称。

     c. 执行以下命令，升/降级torchvision安装包。


           pip install -U <torchvision-name>.whl --force-reinstall



        其中： torchvision-name 表示目标版本的torchvision安装包的名称。

     d. 执行以下命令，升/降级torchaudio安装包。


           pip install -U <torchaudio-name>.whl --force-reinstall



        其中： torchaudio-name 表示目标版本的torchaudio安装包的名称。

     e. 执行以下命令，升/降级torchdata安装包。


           pip install -U <torchdata-name>.whl --force-reinstall


        其中： torchdata-name 表示目标版本的torchdata安装包的名称。

      f. 执行以下命令，升/降级torchtext安装包。


           pip install -U <torchtext-name>.whl --force-reinstall



        其中： torchtext-name 表示目标版本的torchtext安装包的名称。

 执行结果

执行以下命令，查看目标软件安装包是否成功升/降级。

   pip list | grep torch   # 升/降级成功后，可以查询到软件安装包的信息




3.1.1.1.3.5 卸载软件安装包
如果不再需要已安装的软件安装包时，可将其卸载。

 前提条件

您已成功安装torch_sdaa，可参考安装软件安装包。

 操作步骤

执行以下命令，卸载目标软件安装包。



文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司             16

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                安装指南




   卸载PyTorch：

       pip uninstall torch


   卸载TecoPyTorch：

       pip uninstall torch_sdaa


   卸载torchaudio：

       pip uninstall torchaudio


   卸载torchvision：

       pip uninstall torchvision


   卸载torchdata：

       pip uninstall torchdata



   卸载torchtext：

       pip uninstall torchtext




 执行结果

执行以下命令，确认目标软件安装包已成功卸载。

   pip list | grep torch     # 卸载成功后，无法查询到软件安装包




3.1.1.2 Docker安装
3.1.1.2.1 安装依赖
本文主要介绍通过Docker安装TecoPyTorch时的依赖。

 环境依赖

 分类                                说明

 操作系统                              Ubuntu 22.04

 系统架构                              X86（64位）




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司      17

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                            安装指南




 分类                               说明

 Docker                           需自行安装


 软件资源依赖

 分类                                    说明

 固件                                    无需安装，太初AI加速卡出厂前已安装。

                                       需在宿主机上手动安装v3.2.0版本的TecoDriver，可参考环境安装手册
 TecoDriver
                                       （详情请参考《环境安装手册》的Intel/AMD CPU（x86_64）章节）。


3.1.1.2.2 安装准备
安装TecoPyTorch前，请检查当前机器上是否安装过相关的依赖资源，以及版本是否正确。若安装的版本不满足要
求，请按照安装依赖提供的方法，重新安装。本文主要介绍如何查看当前机器上相关资源的安装情况。

 固件

  1. 执行以下命令，配置系统环境。


       source /opt/tecoai/setvars.sh


 2. 执行以下命令，查看固件是否已安装。


       teco-smi --query-device firmware_version --format=csv




 TecoDriver

执行以下命令，查看TecoDriver安装包的版本信息。

   dpkg -l | grep tecodriver




3.1.1.2.3 安装步骤
3.1.1.2.3.1 获取Docker镜像
在Docker中使用TecoPytorch前，需要获取目标Docker镜像。

 前提条件

您已经成功安装Docker工具。




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                      18

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




 操作步骤

执行以下命令，下载Docker镜像至本地。

   wget http://wb.tecorigin.com:8082/repository/teco-docker-tar-repo/release/ubuntu22.04/x86_64/3.2.0/pyto
   rch-3.2.0-torch_sdaa3.2.0.tar




 校验Docker镜像包

基于下载的镜像包生成MD5码，并与镜像包官方MD5码进行比较，确认下载镜像包的完整性。

执行以下命令，生成MD5码：

   md5sum pytorch-3.2.0-torch_sdaa3.2.0.tar




 镜像包MD5码

Docker镜像包的官方MD5码信息如下：


 Docker镜像包                         MD5码

 pytorch-3.2.0-
                                   d85ec9ff7b181791c2d2fb77c3f0cf21
 torch_sdaa3.2.0.tar




3.1.1.2.3.2 构建Docker容器
在Docker镜像下载到本地后，需要构建一个Docker容器。

 前提条件

您已成功获取Docker镜像，可参考获取Docker镜像。

 操作步骤

  1. 执行以下命令，导入Docker镜像。


       docker load < pytorch-3.2.0-torch_sdaa3.2.0.tar


 2. 执行以下命令，查看镜像是否导入成功。如果导入成功，可以查询到镜像信息。


       docker images | grep torch_sdaa


 3. 执行以下命令，构建Docker容器。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               19

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




       docker run -itd --name="tecopytorch_docker" --net=host --device=/dev/tcaicard0 --device=/dev/tcaica
       rd1 --device=/dev/tcaicard2 --device=/dev/tcaicard3 --cap-add SYS_PTRACE --cap-add SYS_ADMIN --shm-
       size 64g jfrog.tecorigin.net/tecotp-docker/release/ubuntu22.04/x86_64/pytorch:3.2.0-torch_sdaa3.2.0
       /bin/bash



   其中：

          -itd ：在后台运行容器，并与物理机保持交互状态。

          --name="tecopytorch_docker" ：设置Docker容器的名称，本示例中设置的容器名称为
          tecopytorch_docker 。

          --net=host ：设置容器的网络模式为                  host ，容器将直接使用主机的网络接口。

          --device=/dev/tcaicard0 --device=/dev/tcaicard1 --device=/dev/tcaicard2 --
        device=/dev/tcaicard3 ：用于将物理机指定的SDAA计算设备（SPA）挂载到容器中，使容器能够访
        问这些设备。本示例中挂载的设备
        为 /dev/tcaicard0 、 /dev/tcaicard1 、 /dev/tcaicard2 、 /dev/tcaicard3 。

              提示：

              请根据物理机上实际可用的SDAA计算设备及实际需求，设置挂载的设备数量。


          --cap-add SYS_PTRACE --cap-add SYS_ADMIN ：设置允许容器访问物理机的系统跟踪功能。


              提示：

              设置该参数可能会增加容器被攻击的风险，需谨慎使用。


          --shm-size ：设置容器享内存大小，建议设置为64G及以上内存大小。

        jfrog.tecorigin.net/tecotp-docker/release/ubuntu22.04/x86_64/pytorch:3.2.0-
        torch_sdaa3.2.0：导入后的Docker镜像名称。

          /bin/bash ：容器启动后要运行的命令。


 执行结果

执行以下命令，查看Docker容器是否创建成功。如果构建成功，可以查询到容器信息。

   docker ps -a | grep tecopytorch_docker




3.1.1.2.3.3 进入Docker容器
在Docker容器构建完成后，需要进入Docker容器，便可以使用TecoPytorch。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                  20

TecoPyTorch用户手册（适配PyTorch 2.7.1）                               安装指南




 前提条件

您已成功构建Docker容器，可参考构建Docker容器。

 操作步骤

执行以下命令，进入名称为 tecopytorch_docker 的Docker容器。

   docker exec -it tecopytorch_docker /bin/bash




3.1.1.2.3.4 验证TecoPyTorch
本文介绍如何在Docker环境中验证TecoPytorch运行是否正常。

 前提条件

您已成功构建并进入Docker容器，可参考构建Docker容器和进入Docker容器。

 操作步骤

  1. 执行以下命令，进入TecoPytorch环境。


       conda activate torch27_env_py310



 2. 执行以下命令，验证TecoPytorch是否正常运行。


       python -c "import torch_sdaa"




 执行结果

如果终端成功输出TecoPyTorch及其依赖的版本，表示TecoPyTorch运行正常。


3.2 申威 8A（SW-64)
3.2.1 UOS Server 20
3.2.1.1 Pip安装
3.2.1.1.1 安装依赖
本文主要介绍安装TecoPyTorch时的依赖。

 环境依赖




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司      21

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                               安装指南




 分类                                              说明

 CPU型号                                           8A

 操作系统                                            UOS Server 20

 Python环境                                        Python 3.9


 软件资源依赖

 分类                                              说明

 固件                                              无需安装，太初AI加速卡出厂前已安装。

                                                 需手动安装，可参考环境安装手册（详情请参考《环境安装
 TecoDriver
                                                 手册》的Intel/AMD CPU（x86_64）章节）。

                                                 需手动安装，可参考环境安装手册（详情请参考《环境安装
 TecoToolKit
                                                 手册》的Intel/AMD CPU（x86_64）章节）。


 版本对应关系

TecoPyTorch与依赖资源的TecoDriver和TecoToolKit版本对应关系如下：


     说明：

     TecoDriver和TecoToolKit各自包含的组件版本信息，例如SDAADriver、TecoCC和TCCL等，可参考环境
     安装手册中的版本信息（详情请参考《环境安装手册》的版本信息章节）。


 TecoPyTorch                            TecoDriver               TecoToolKit

 v3.2.0                                 v3.2.0                   v3.2.0



3.2.1.1.2 安装准备
安装TecoPyTorch前，请检查当前机器上是否安装过相关的依赖资源，以及版本是否正确。若安装的版本不满足要
求，请按照安装依赖提供的方法，重新安装。本文主要介绍如何查看当前机器上相关资源的安装情况。

 固件

  1. 执行以下命令，配置系统环境。


       source /opt/tecoai/setvars.sh


 2. 执行以下命令，查看固件是否已安装。



文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                      22

TecoPyTorch用户手册（适配PyTorch 2.7.1）                               安装指南




       teco-smi --query-device firmware_version --format=csv




 TecoDriver

执行以下命令，查看TecoDriver安装包的版本信息。

   rpm -qa | grep tecodriver




 TecoToolKit

执行以下命令，查看TecoToolKit安装包的版本信息。

   rpm -qa | grep tecotoolkit




3.2.1.1.3 安装TecoPyTorch
3.2.1.1.3.1 创建Python虚拟环境
本节主要介绍如何创建用于安装TecoPytorch的Python虚拟环境。


     提示：

     申威平台上Anaconda不可用，需使用系统自带的Python环境创建虚拟环境。


 前提条件

系统中已安装Python 3.9环境。

 操作步骤

  1. 执行以下命令，创建Python虚拟环境。


          说明：

          使用 venv 创建虚拟环境时，将完整拷贝一份系统Python。拷贝的Python版本与系统Python一致且
          相互隔离。


       mkdir $PWD/myenv
       python -m venv myenv



 2. 执行以下命令，激活虚拟环境。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司         23

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




       source $PWD/myenv/bin/activate


 3. 执行以下命令，安装TecoPytorch所需环境依赖包。


       pip install astunparse numpy pyyaml cmake cffi typing_extensions future six




3.2.1.1.3.2 获取软件安装包
在安装TecoPyTorch前，需要获取目标软件安装包。

 操作步骤

执行以下命令，下载TecoPyTorch相关安装包至本地。

   下载PyTorch安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-sw-pypi-repo/sw_8a/torch-2.7.1-cp311-cp311-linux_
       sw_64.whl



   下载TecoPyTorch安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-sw-pypi-repo/sw_8a/torch_sdaa-3.2.0-cp311-cp311-l
       inux_sw_64.whl


   下载torchvision安装包：

       wget http://wb.tecorigin.com:8082/repository/teco-sw-pypi-repo/sw_8a/torchvision-0.22.1+59a3e1f-cp3
       11-cp311-linux_sw_64.whl




 校验安装包

基于下载的软件安装包生成MD5码，并与安装包官方MD5码进行比较，确认下载安装包的完整性。

以TecoPyTorch安装包为例，生成安装包MD5的命令如下：

   md5sum torch_sdaa-3.2.0-cp311-cp311-linux_sw_64.whl




 安装包MD5码

TecoPyTorch相关安装包的官方MD5码信息如下：




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                                24

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                          安装指南




 安装包                               MD5码

 PyTorch安装包                        cefdb8db1f4db3df9432ab43928e6625

 TecoPyTorch安装包                    6c9621c1a9897ee07aadd05741031a48

 torchvision安装包                    449ee97cb8a21d6a9958d2494e1072b5



3.2.1.1.3.3 安装软件安装包
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

   pip list | grep torch   # 安装成功后，可以查询到软件安装包的信息




3.2.1.1.3.4 升/降级软件安装包
如果已安装的软件安装包不满足使用需求时，可对其进行升/降级。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                  25

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     安装指南




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


 2. 安装目标版本的TecoDriver和TecoToolKit。


         说明：

         请参考《环境安装手册》（详情请参考《环境安装手册》的安装包简介章节）获取TecoToolkit和
         TecoDriver的安装方法。


 3. 升/降级TecoPyTorch相关安装包。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                   26

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     安装指南




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

   pip list | grep torch     # 升/降级成功后，可以查询到软件安装包的信息




3.2.1.1.3.5 卸载软件安装包
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



文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司             27

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                            安装指南




       pip uninstall torchvision




 执行结果

执行以下命令，确认目标软件安装包已成功卸载。

   pip list | grep torch   # 卸载成功后，无法查询到软件安装包




3.2.1.2 Docker安装
3.2.1.2.1 安装依赖
本文主要介绍通过Docker安装TecoPyTorch时的依赖。

 环境依赖

 分类                                    说明

 CPU型号                                 8A

 操作系统                                  UOS Server 20

 Docker                                需自行安装


 软件资源依赖

 分类                                    说明

 固件                                    无需安装，太初AI加速卡出厂前已安装。

                                       需在宿主机上手动安装v3.2.0版本的TecoDriver，可参考环境安装手册
 TecoDriver
                                       （详情请参考《环境安装手册》的Intel/AMD CPU（x86_64）章节）。


3.2.1.2.2 安装准备
安装TecoPyTorch前，请检查当前机器上是否安装过相关的依赖资源，以及版本是否正确。若安装的版本不满足要
求，请按照安装依赖提供的方法，重新安装。本文主要介绍如何查看当前机器上相关资源的安装情况。

 固件

  1. 执行以下命令，配置系统环境。


       source /opt/tecoai/setvars.sh




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                      28

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




 2. 执行以下命令，查看固件是否已安装。


       teco-smi --query-device firmware_version --format=csv




 TecoDriver

执行以下命令，查看TecoDriver安装包的版本信息。

   rpm -qa | grep tecodriver




3.2.1.2.3 安装步骤
3.2.1.2.3.1 获取Docker镜像
在Docker中使用TecoPytorch前，需要获取目标Docker镜像。

 前提条件

您已经成功安装Docker工具。

 操作步骤

执行以下命令，下载Docker镜像至本地。

   wget http://wb.tecorigin.com:8082/repository/teco-docker-tar-repo/release/uos/sw_8a/3.2.0/pytorch-3.2.0
   -torch_sdaa3.2.0.tar




 校验Docker镜像包

基于下载的镜像包生成MD5码，并与镜像包官方MD5码进行比较，确认下载镜像包的完整性。

执行以下命令，生成MD5码：

   md5sum pytorch-3.2.0-torch_sdaa3.2.0.tar




 镜像包MD5码

Docker镜像包的官方MD5码信息如下：


 Docker镜像包                         MD5码

 pytorch-3.2.0-
                                   70533cbeddb79b2e75d2723389a998ca
 torch_sdaa3.2.0.tar




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                  29

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      安装指南




3.2.1.2.3.2 构建Docker容器
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
       size 64g jfrog.tecorigin.net/tecotp-docker/release/uos_server_20/sw_64/8a/pytorch:3.2.0-torch_sdaa
       3.2.0 /bin/bash



   其中：

          -itd ：在后台运行容器，并与物理机保持交互状态。

          --name="tecopytorch_docker" ：设置Docker容器的名称，本示例中设置的容器名称为
          tecopytprch_docker 。

          --net=host ：设置容器的网络模式为                  host ，容器将直接使用主机的网络接口。

          --device=/dev/tcaicard0 --device=/dev/tcaicard1 --device=/dev/tcaicard2 --
       device=/dev/tcaicard3 ：用于将物理机指定的SDAA计算设备（SPA）挂载到容器中，使容器能够访
       问这些设备。本示例中挂载的设备
       为 /dev/tcaicard0 、 /dev/tcaicard1 、 /dev/tcaicard2 、 /dev/tcaicard3 。

              提示：

              请根据物理机上实际可用的SDAA计算设备及实际需求，设置挂载的设备数量。


          --cap-add SYS_PTRACE --cap-add SYS_ADMIN ：设置允许容器访问物理机的系统跟踪功能。


              提示：

              设置该参数可能会增加容器被攻击的风险，需谨慎使用。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               30

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                          安装指南




          --shm-size ：设置容器共享内存大小，建议设置为64G及以上内存大小。

        jfrog.tecorigin.net/tecotp-docker/release/uos_server_20/sw_64/8a/pytorch:3.2.0-
        torch_sdaa3.2.0：导入后的Docker镜像名称。

          /bin/bash ：容器启动后要运行的命令。


 执行结果

执行以下命令，查看Docker容器是否创建成功。如果构建成功，可以查询到容器信息。

   docker ps -a | grep tecopytorch_docker




3.2.1.2.3.3 进入Docker容器
在Docker容器构建完成后，需要进入Docker容器，便可以使用TecoPytorch。

 前提条件

您已成功构建Docker容器，可参考构建Docker容器。

 操作步骤

执行以下命令，进入名称为 tecopytorch_docker 的Docker容器。

   docker exec -it tecopytorch_docker /bin/bash




3.2.1.2.3.4 验证TecoPytorch
本文介绍如何在Docker环境中验证TecoPytorch运行是否正常。

 前提条件

您已成功构建并进入Docker容器，可参考构建Docker容器和进入Docker容器。

 操作步骤

执行以下命令，验证TecoPytorch是否正常运行。

   python -c "import torch_sdaa"




 执行结果

如果终端成功输出TecoPytorch及其依赖的版本，表示TecoPytorch运行正常。


文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                  31

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                  安装指南




3.3 龙芯 3C6000（LoongArch）
3.3.1 Loongnix Server 23.1
3.3.1.1 Pip
3.3.1.1.1 安装依赖
本文主要介绍安装TecoPyTorch时的依赖。

 环境依赖

 分类                                          说明

 CPU型号                                       龙芯 3C6000

 操作系统                                        Loongnix Server 23.1

 Python环境                                    Python 3.11


 软件资源依赖

 分类                                          说明

 固件                                          无需安装，太初AI加速卡出厂前已安装。

                                             需手动安装，可参考环境安装手册（详情请参考《环境安装
 TecoDriver
                                             手册》的Loongnix Server 23.1章节）。

                                             需手动安装，可参考环境安装手册（详情请参考《环境安装
 TecoToolKit
                                             手册》的Loongnix Server 23.1章节）。


 版本对应关系

TecoPyTorch与依赖资源的TecoDriver和TecoToolKit版本对应关系如下：


     说明：

     TecoDriver和TecoToolKit各自包含的组件版本信息，例如SDAADriver、TecoCC和TCCL等，可参考环境
     安装手册中的版本信息（详情请参考《环境安装手册》的版本信息章节）。


 TecoPyTorch                        TecoDriver                      TecoToolKit

 v3.2.0                             v3.2.0                          v3.2.0




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                             32

TecoPyTorch用户手册（适配PyTorch 2.7.1）                               安装指南




3.3.1.1.2 安装准备
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




3.3.1.1.3 安装TecoPyTorch
3.3.1.1.3.1 创建Python虚拟环境
本节主要介绍如何创建用于安装TecoPytorch的Python虚拟环境。


     提示：

     申威平台上Anaconda不可用，需使用系统自带的Python环境创建虚拟环境。


 前提条件
