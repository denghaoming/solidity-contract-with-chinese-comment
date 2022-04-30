# 带中文注释的 Solidity 智能合约

### 1. HoldDividendBNB，持币分红 BNB
#### 6% 持币分红 BNB，2% 营销钱包 BNB
1. 买卖、转账都有 8% 滑点，6% 给持币分红 BNB，2% 营销钱包 BNB<br>
2. 持有 200万 币才能参与分红<br>
3. 卖不干净，最少省 0.1 币<br>
https://github.com/denghaoming/solidity-contract-with-chinese-comment/blob/master/ERC20/HoldDividendBNB.sol<br>

### 2. RebaseDividendToken，Rebase 分红本币
#### 4% 持币分红本币，1% 营销钱包本币
1. 买卖5%滑点，4%给持币分红，1%营销钱包<br>
2. 未开启交易时，只能项目方加池子，加池子未开放交易，机器人购买高滑点<br>
3. 手续费白名单，分红排除名单<br>
https://github.com/denghaoming/solidity-contract-with-chinese-comment/blob/master/ERC20/RebaseDividend.sol<br>

### 3. LPDividendUsdt，加LP分红
#### 加 LP 分红 USDT，推荐关系绑定，推荐分红本币，营销钱包，限购，自动杀区块机器人
1. 买卖14%滑点，3%给加LP池子分红，4%分配10级推荐，1%营销钱包，1%备用拉盘，5%进入NFT盲盒<br>
2. 推荐分红，1级0.48%,2级0.44%,3级0.42%，4-10级各0.38%<br>
3. 限购总量 1%<br>
https://github.com/denghaoming/solidity-contract-with-chinese-comment/blob/master/ERC20/LPDividend.sol<br>

### 4. AddUsdtLP，回流USDT池子
#### USDT 回流加池子，营销钱包，销毁
1. 买卖10%滑点，3%销毁，3%回流筑池（1.5%币、1.5%U），3%LP分红 DAPP实现，1%基金会（U到账）<br>
https://github.com/denghaoming/solidity-contract-with-chinese-comment/blob/master/ERC20/AddUsdtLP.sol<br>

### 区块链 Solidity 智能合约交流QQ群：103682866