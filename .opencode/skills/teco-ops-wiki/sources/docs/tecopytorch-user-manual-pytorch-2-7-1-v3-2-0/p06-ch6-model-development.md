---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p06
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第6部分 (ch6-model-development)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "6844-7178"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, model-development]
---

# TecoPyTorch 用户手册 v3.2.0（第6部分）

> 原文行范围：`6844-7178`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

6. 模型开发
本文以手写数字识别任务为例，介绍如何使用TecoPyTorch开发模型并进行模型训练，帮助您快速了解太初AI加速卡
上深度学习模型的开发流程。


     说明：

     手写数字识别任务用于检测和识别手写的0~9十类数字，即根据输入的手写数字图片，准确识别出图片中的数
     字。其广泛应用于各个领域，如：自动填写银行支票、识别邮编地址等。


 编程思路




                                      图1 手写数字识别任务编程思路

  1. 安装软件安装包：安装TecoPyTorch软件安装包，指定太初计算设备后端（TecoPyTorch对应的为SDAA后
   端）。
 2. 读取并处理数据：从PyTorch内置的MNIST数据集中读取数据并处理。

 3. 定义网络：以类的方式定义数字识别的网络结构。

 4. 训练模型：生成模型实例，设置优化算法和学习率。

 5. 保存模型：保存训练好的模型，以便在模型预测时调用。


 编写程序

 步骤一：安装TecoPyTorch软件安装包

  1. 安装TecoPyTorch软件安装包，可参考安装TecoPyTorch。

 2. 执行以下命令，指定太初计算设备。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司          102

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         模型开发




       import torch   #torch
       import torch_sdaa    #导入torch_sdaa
       import numpy as np
       from torch.utils.data import DataLoader
       from torchvision import transforms
       from torchvision import datasets
       import torch.nn.functional as F


       device = torch.device('sdaa')




 步骤二：数据加载与处理

加载PyTorch内置的手写数字数据集MNIST。在手写数字识别任务中，通过 torchvision.datasets.MNIST 来
获取处理好的MNIST训练集和测试集。

   batch_size = 64
   learning_rate = 0.01
   momentum = 0.5
   EPOCH = 10


   transform = transforms.Compose([transforms.ToTensor(), transforms.Normalize((0.1307,), (0.3081,))])


   # 若本地没有MNIST数据集，则需要加上download=True
   train_dataset = datasets.MNIST(root='./data/mnist', train=True, download=True, transform=transform)
   # train=True训练集，train=False测试集
   test_dataset = datasets.MNIST(root='./data/mnist', train=False, download=True, transform=transform)


   train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
   test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)




 步骤三：定义网络。

执行以下命令，定义数字识别的网络结构。

   class Net(torch.nn.Module):


      def __init__(self):
           super(Net, self).__init__()
           self.conv1 = torch.nn.Sequential(
                torch.nn.Conv2d(1, 10, kernel_size=5),
                torch.nn.ReLU(),
                torch.nn.MaxPool2d(kernel_size=2),
           )
           self.conv2 = torch.nn.Sequential(
                torch.nn.Conv2d(10, 20, kernel_size=5),
                torch.nn.ReLU(),
                torch.nn.MaxPool2d(kernel_size=2),
           )
           self.fc = torch.nn.Sequential(
                torch.nn.Linear(320, 50),
                torch.nn.Linear(50, 10),
           )




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                             103

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         模型开发




         def forward(self, x):
             batch_size = x.size(0)
             x = self.conv1(x)   # 一层卷积层，一层池化层，一层激活层
             x = self.conv2(x)   #一层卷积层，一层池化层，一层激活层
             x = x.flatten(1)    # flatten变成全连接网络需要的输入 (batch, 20,4,4) ==> (batch,320), -1 此处自动算出的
   是320
             x = self.fc(x)
             return x   # 最后输出的是维度为10的，也就是（对应数学符号的0~9）



   model = Net().to(device)




 步骤四：训练模型

执行以下命令，生成模型实例，设置优化算法和学习率。

从终端输出中可以看出损失持续下降，模型训练精度持续提升。

   criterion = torch.nn.CrossEntropyLoss().to(device)
   optimizer = torch.optim.SGD(model.parameters(), lr=learning_rate, momentum=momentum)


   def train(epoch):
         running_loss = 0.0
         running_total = 0
         running_correct = 0
         for batch_idx, data in enumerate(train_loader, 0):
             inputs, target = data[0].to(device), data[1].to(device)
             optimizer.zero_grad()


             # forward + backward + update
             outputs = model(inputs)
             loss = criterion(outputs, target)


             loss.backward()
             optimizer.step()


             running_loss += loss.item()
             _, predicted = torch.max(outputs.data, dim=1)
             running_total += inputs.shape[0]
             running_correct += (predicted == target).sum().item()


             if batch_idx % 300 == 299:
                 print('[%d, %5d]: loss: %.3f , acc: %.2f %%'
                        % (epoch + 1, batch_idx + 1, running_loss / 300, 100 * running_correct / running_tota
   l))
                 running_loss = 0.0
                 running_total = 0
                 running_correct = 0




 步骤五：保存模型

执行以下命令，保存训练好的模型。




文档版本：v3.2.0                                版权所有 © 太初(无锡)电子科技有限公司                                                104

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         模型开发




   torch.save(model.state_dict(), './model_mnist.pth')




 完整程序

手写数字识别任务的完整程序如下：

   import torch   #torch
   import torch_sdaa    #导入torch_sdaa
   import numpy as np
   from torch.utils.data import DataLoader
   from torchvision import transforms
   from torchvision import datasets
   import torch.nn.functional as F


   device = torch.device('sdaa')


   batch_size = 64
   learning_rate = 0.01
   momentum = 0.5
   EPOCH = 10


   transform = transforms.Compose([transforms.ToTensor(), transforms.Normalize((0.1307,), (0.3081,))])


   train_dataset = datasets.MNIST(root='./data/mnist', train=True, download=True, transform=transform)   #
   若本地没有MNIST数据集，则需要加上download=True
   test_dataset = datasets.MNIST(root='./data/mnist', train=False, download=True, transform=transform)   #
   train=True训练集，train=False测试集
   train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
   test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)


   class Net(torch.nn.Module):


       def __init__(self):
           super(Net, self).__init__()
           self.conv1 = torch.nn.Sequential(
                torch.nn.Conv2d(1, 10, kernel_size=5),
                torch.nn.ReLU(),
                torch.nn.MaxPool2d(kernel_size=2),
           )
           self.conv2 = torch.nn.Sequential(
                torch.nn.Conv2d(10, 20, kernel_size=5),
                torch.nn.ReLU(),
                torch.nn.MaxPool2d(kernel_size=2),
           )
           self.fc = torch.nn.Sequential(
                torch.nn.Linear(320, 50),
                torch.nn.Linear(50, 10),
           )


       def forward(self, x):
           batch_size = x.size(0)
           x = self.conv1(x)   # 一层卷积层,一层池化层,一层激活层
           x = self.conv2(x)   #一层卷积层,一层池化层,一层激活层
           x = x.flatten(1)    # flatten变成全连接网络需要的输入 (batch, 20,4,4) ==> (batch,320), -1 此处自动算出的
   是320




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               105

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         模型开发




             x = self.fc(x)
             return x   # 最后输出的是维度为10的，也就是（对应数学符号的0~9）



   model = Net().to(device)


   criterion = torch.nn.CrossEntropyLoss().to(device)
   optimizer = torch.optim.SGD(model.parameters(), lr=learning_rate, momentum=momentum)



   def train(epoch):
         running_loss = 0.0
         running_total = 0
         running_correct = 0
         for batch_idx, data in enumerate(train_loader, 0):
             inputs, target = data[0].to(device), data[1].to(device)
             optimizer.zero_grad()


             # forward + backward + update
             outputs = model(inputs.to(device))
             loss = criterion(outputs, target)


             loss.backward()
             optimizer.step()


             running_loss += loss.item()
             _, predicted = torch.max(outputs.data, dim=1)
             running_total += inputs.shape[0]
             running_correct += (predicted == target).sum().item()


             if batch_idx % 300 == 299:
                 print('[%d, %5d]: loss: %.3f , acc: %.2f %%'
                        % (epoch + 1, batch_idx + 1, running_loss / 300, 100 * running_correct / running_tota
   l))
                 running_loss = 0.0
                 running_total = 0
                 running_correct = 0


         torch.save(model.state_dict(), './model_mnist.pth')



   if __name__ == '__main__':
         train(epoch=1)




文档版本：v3.2.0                                版权所有 © 太初(无锡)电子科技有限公司                                                106

TecoPyTorch用户手册（适配PyTorch 2.7.1）                             自定义 SDAAC 算子接入
