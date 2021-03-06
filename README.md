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

计划最大发行量： 12096000

实际最大发行量：3200000 (社区投票修改了减产规则，缩减了总量)

初始流通量：0；

挖矿启动时间：2020-09-22 20:00:00

减产规则：
计划仿照比特币的减半机制，CFS的减产规则如下：

| 代币  | 初始奖励  |减产比例  |奖励级数求和  |减产规则  |总量  |
| ------------ | ------------ | ------------ | ------------ | ------------ | ------------ |
|BTC|50|50%|100|每210000块减产一次|210000*100=21000000|
|CFS|1|90%|10|每1209600块减产一次|1209600*10=12096000|

CFS按照时间匀速出块，如果按照每秒出块2个算，则每周减产一次

实际减产情况：

<table>
   <tr>
      <td colspan="10" align="center">CFS产量</td>
   </tr>
   <tr>
      <td>减产次数</td>
      <td>区块开始</td>
      <td>区块结束</td>
      <td>区块奖励</td>
      <td>减产系数</td>
      <td>每块产出</td>
      <td>总产出</td>
      <td>挖矿期数</td>
      <td>总量</td>
      <td>总量</td>
   </tr>
   <tr>
      <td>0</td>
      <td>0</td>
      <td>1209600</td>
      <td>1</td>
      <td>1</td>
      <td>1</td>
      <td>1209600</td>
      <td align="center" rowspan="2">第一期</td>
      <td align="center" rowspan="2">2088122.4</td>
      <td align="center" rowspan="7">3102495.2</td>
   </tr>
   <tr>
      <td>1</td>
      <td>1209601</td>
      <td>2185736</td>
      <td>1</td>
      <td>0.9</td>
      <td>0.9</td>
      <td>878522.4</td>
   </tr>
   <tr>
      <td>1</td>
      <td>2185737</td>
      <td>2419200</td>
      <td>0.25</td>
      <td>0.8</td>
      <td>0.2</td>
      <td>46692.8</td>
      <td align="center" rowspan="5">第二期</td>
      <td align="center" rowspan="5">1014372.8</td>
   </tr>
   <tr>
      <td>2</td>
      <td>2419201</td>
      <td>3628800</td>
      <td>0.25</td>
      <td>0.64</td>
      <td>0.16</td>
      <td>193536</td>
   </tr>
   <tr>
      <td>3</td>
      <td>3628801</td>
      <td>4838400</td>
      <td>0.25</td>
      <td>0.512</td>
      <td>0.128</td>
      <td>154828.8</td>
   </tr>
   <tr>
      <td>4</td>
      <td>4838401</td>
      <td>6048000</td>
      <td>0.25</td>
      <td>0.4096</td>
      <td>0.1024</td>
      <td>123863.04</td>
   </tr>
   <tr>
      <td>…</td>
      <td>…</td>
      <td>…</td>
      <td>…</td>
      <td>…</td>
      <td>…</td>
      <td>…</td>
   </tr>
</table>


矿池种类：

| 矿池  | 出块速度  |
| ------------ | ------------ |
|交易挖矿|交易1笔出块一次，最快1秒出一个块，不交易则不出块|
|BANCOR抵押(待上线)|  |
|SWAP做市(待上线)|  |
|质押COCOS挖矿|权重23|
|质押COCOS-CFS-LP|权重25|
|质押COCOS-LWT-LP|权重2|

不同的矿池权重不同，权重是一个可治理参数，可由社区持币者投票决定






## 质押分红

通过质押CFS到质押合约中，每天可以获得分红池的COCOS分红奖励。

分红实时结算，但需要用户手动领取。

解除抵押的CFS，实时到账。

截止2020年10月20日，已累积分红 1亿cocos


## 代码版权声明

Cocos Financial Share下面所有的DeFi协议代码，采用GPL开源协议。

允许任何的个人或组织(“被许可方”)私下研究、审查和分析该软件。被许可方，可在GPL开源协议的约束下，对本软件进行引用和修改。
在任何情况下，版权所有人都不承担因错误使用、修改本软件而产生的或与本软件有关的任何损害或其他责任，无论是在合同、侵权或其他方面。

