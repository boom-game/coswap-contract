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

最大发行量： 21000000；

初始流通量：0；

挖矿启动时间：待定  ~~2020-09-19 20:00:00 , 时间戳 1600516800~~

减产规则：
仿照比特币的减半机制，CFS的减半规则如下：

| 代币  | 初始奖励  |减产比例  |奖励级数求和  |减产规则  |总量  |
| ------------ | ------------ | ------------ | ------------ | ------------ | ------------ |
|BTC|50|50%|100|每210000块减产一次|210000*100=21000000|
|CFS|1|90%|10|每2100000块减产一次|2100000*10=21000000|

可以看出，不同点在于，比特币每次减半对矿工打击很大，CFS为了保证挖矿平稳进行，每次减产90%

|减产次数|块奖励|
| ------------ | ------------ |
|初始|1|
|1|0.9|
|2|0.81|
|3|0.729|
|..|..|
|20|0.121576|


矿池种类：

| 矿池  | 出块速度  |
| ------------ | ------------ |
|交易挖矿|10秒|
|BANCOR抵押|10秒|
|SWAP做市|10秒|
|加速挖矿(有矿损)|1秒|

不同的矿池通过不同的出块速度来区分挖矿权重，出块速度是一个可治理参数，可由社区持币者投票决定






## 质押分红

通过质押CFS到质押合约中，每天可以获得分红池的EOS分红奖励。目前EOS协议费收入的50%将纳入分红池，后续将引入其他协议费的收入也将纳入分红池中。

分红时间为24小时，需要用户手动领取，或由第三方合约代领。

解除抵押的CFS，三天后到账，解锁期间无分红。


## 开发规划

* 稳定币资产协议:  DeFis Bank (已经开发好)，USDD是以加密资产超额抵押生成的EOS公链通用结算货币。通过超额抵押机制，在保证用户抵押物100%安全的同时，还可以参与公链底层的质押收益。
* 资产流动性协议: DeFis Swap (已经开发好)， 类似uniswap的算法型Dex。**CFS持有者可获得协议费分红。**
* 资产借贷协议: DeFis Lend (类似compound，开发中)
* 资产合成协议: DeFis Synthetix (资产合成平台，开发中)

其他类型的DeFi协议，也将持续开发出来，并添加进 Cocos Financial Share，持续壮大这个开放式金融网络。

## 项目启动方式说明

Cocos Financial Share的源代码，由DeFi爱好者免费贡献和维护。

项目由社区爱好者进行启动和运营。 

代币分配方式，采用最接近比特币的公平竞争分配方式。

而且协议所产生的收益，按智能合约公平分配给代币持有者。

因此，我们可以说，所有参与挖矿、或持有项目代币CFS的用户，都是这个项目的拥有者。

## 代码版权声明

Cocos Financial Share下面所有的DeFi协议代码，采用GPL开源协议。

允许任何的个人或组织(“被许可方”)私下研究、审查和分析该软件。被许可方，可在GPL开源协议的约束下，对本软件进行引用和修改。
在任何情况下，版权所有人都不承担因错误使用、修改本软件而产生的或与本软件有关的任何损害或其他责任，无论是在合同、侵权或其他方面。

## 风险提示

本项目的智能合约已经过专业安全团队审计。但仍可能存在不可意料的风险。请注意并自行承担使用风险。

## 总结

Cocos Financial Share, 愿景是打造一个去中心化金融网络的底层基础和入口, 成为用户和去中心化金融之间的桥梁。

我们致力于加速去中心化金融的到来。通过释放区块链的力量，来实现区块链对金融的变革。

我们以一种去中心化的方式来推动这个愿景。  

