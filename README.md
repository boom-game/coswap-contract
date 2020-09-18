# CFS: Cocos Financial Share

v1.0 Sep 14 2020

## 项目定位和愿景

CFS致力于在COCOS链上打造一个开放，安全，易用的金融系统

COCOS是目前世界上排名第一的h5游戏引擎，COCOS目前急需一个交易平台，来满足各种游戏代币，NFT的交易需求。

而基于最新的DEFI的各项协议，可以完美解决当前游戏资产交易的问题。

我们的目标是依托COCOS强大的能力成为游戏界最大的去中心化资产交易平台。


## CFS 功能概述

### Bancor协议: CFS Bancor

用户可以通过bancor协议进行代币交换，交换是完全由算法控制的。

一些新的项目方首次发行代币，往往会采用bancor形式首次进入市场。

交易会产生手续费，可以用来奖励抵押代币的用户。

### 流动性协议: CFS Swap

在Swap中，用户可以自由创建任意两个币种之间的交易对，并注入流动性资金，使其形成有效的交换市场。

交易产生的手续费，会按照注入的流动性资金的比例，奖励给提供流动性的用户

## 平台币: CFS , Cocos Financial Share

CFS是 coswap.io 的平台币，与MakerDAO的MKR、Compound的COMP类似，但功能不局限于治理和支付利息费用。主要可用于:

* 交易
* 治理投票
* 流动性激励
* 交易挖矿
* 运营合作
* 抵押分红

通过整合一系列DeFi协议，CFS将成为COCOS链上最强大的金融工具。

而平台币CFS就是平台的分红凭证。CFS持有者将持续获得手续费的分红。

持有CFS份额，就可加入coswap.io社区，有权参与一些关键的治理。

## 代币CFS分配方案与挖矿规则

最大发行量： 12096000；

初始流通量：0；

挖矿启动时间：待定  ~~2020-09-19 20:00:00 , 时间戳 1600516800~~

减产规则：
仿照比特币的减半机制，CFS的减半规则如下：

| 代币  | 初始奖励  |减产比例  |奖励级数求和  |减产规则  |总量  |
| ------------ | ------------ | ------------ | ------------ | ------------ | ------------ |
|BTC|50|50%|100|每210000块减产一次|210000*100=21000000|
|CFS|1|90%|10|每1209600块减产一次|1209600*10=12096000|

可以看出，不同点在于，比特币每次减半对矿工打击很大，CFS为了保证挖矿平稳进行，每次减产90%
CFS按照时间匀速出块，如果按照每秒出块2个算，则每周减产一次，每次减产，价格预期升高10%

|减产次数|块奖励|
| ------------ | ------------ |
|初始|1|
|1|0.81|
|2|0.729|
|3|0.6561|
|..|..|
|20|0.121576|


矿池种类：

| 矿池  | 出块速度  |
| ------------ | ------------ |
|交易挖矿|交易1笔出块一次，最快1秒出一个块，不交易则不出块|
|BANCOR抵押|1秒出块1次，权重5|
|SWAP做市|1秒出块1次，权重5|
|质押COCOS挖矿|1秒出块1次，权重5|

不同的矿池权重不同，权重是一个可治理参数，可由社区持币者投票决定






## 质押分红

通过质押CFS到质押合约中，每天可以获得分红池的COCOS分红奖励。

分红实时结算，但需要用户手动领取。

解除抵押的CFS，实时到账。


## 代码版权声明

Cocos Financial Share下面所有的DeFi协议代码，采用GPL开源协议。

允许任何的个人或组织(“被许可方”)私下研究、审查和分析该软件。被许可方，可在GPL开源协议的约束下，对本软件进行引用和修改。
在任何情况下，版权所有人都不承担因错误使用、修改本软件而产生的或与本软件有关的任何损害或其他责任，无论是在合同、侵权或其他方面。

