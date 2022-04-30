// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface IERC20 {
    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface ISwapRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface ISwapFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

abstract contract Ownable {
    address internal _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "!owner");
        _;
    }

    //放弃权限
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    //转移权限
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "new is 0");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract AbsToken is IERC20, Ownable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address private fundAddress;//营销钱包地址

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    mapping(address => bool) private _feeWhiteList;//交易税白名单

    uint256 private _tTotal;

    ISwapRouter private _swapRouter;
    address private _mainPair;

    bool private inSwap;
    uint256 private numTokensSellToFund;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _marketFee;
    uint256 private _dividendFee;

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor (string memory Name, string memory Symbol, uint8 Decimals, uint256 Supply, address FundAddress, uint256 DividendFee, uint256 MarketFee){
        _name = Name;
        _symbol = Symbol;
        _decimals = Decimals;

        //BSC PancakeSwap 路由地址
        ISwapRouter swapRouter = ISwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        _swapRouter = swapRouter;

        //创建BNB交易对
        ISwapFactory swapFactory = ISwapFactory(swapRouter.factory());
        address mainPair = swapFactory.createPair(address(this), swapRouter.WETH());
        _mainPair = mainPair;

        //将当前合约的代币授权给路由地址，授权最大值
        _allowances[address(this)][address(swapRouter)] = MAX;

        //总量
        uint256 total = Supply * 10 ** Decimals;
        _tTotal = total;

        //营销钱包加池子
        _balances[FundAddress] = total;
        emit Transfer(address(0), FundAddress, total);

        //营销钱包，暂时设置为合约部署的开发者地址
        fundAddress = FundAddress;

        //营销地址为手续费白名单
        _feeWhiteList[FundAddress] = true;
        _feeWhiteList[address(this)] = true;
        _feeWhiteList[address(swapRouter)] = true;
        _feeWhiteList[msg.sender] = true;
        _feeWhiteList[address(0x000000000000000000000000000000000000dEaD)] = true;

        //营销钱包卖出条件 总量的万分之一
        numTokensSellToFund = total / 10000;

        //排除 分红
        excludeHolder[address(0)] = true;
        excludeHolder[address(this)] = true;
        excludeHolder[address(mainPair)] = true;
        excludeHolder[address(0x000000000000000000000000000000000000dEaD)] = true;
        excludeHolder[address(swapRouter)] = true;
        //粉红锁仓合约地址
        excludeHolder[address(0x7ee058420e5937496F5a2096f04caA7721cF70cc)] = true;

        //合约地址里有 0.001 BNB 开始分红
        holderRewardCondition = 1000000000000000;
        //持有200万个才能参与分红
        holderCondition = 2000000 * 10 ** Decimals;

        //分红税和营销税
        _dividendFee = DividendFee;
        _marketFee = MarketFee;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] != MAX) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        }
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        //地址卖不干净，留0.1
        if (amount == balanceOf(from)) {
            if (amount > 100000000000000000) {
                amount -= 100000000000000000;
            } else {
                amount = 0;
            }
        }

        //交易税
        uint256 txFee;

        //to == _mainPair 表示卖出，有人卖出时，合约达到卖出条件，合约先卖币换成BNB
        if (_mainPair == to && !_feeWhiteList[from]) {
            //兑换代币
            uint256 contractTokenBalance = balanceOf(address(this));
            if (
                contractTokenBalance >= numTokensSellToFund &&
                !inSwap
            ) {
                swapTokenForFund(numTokensSellToFund);
            }
        }
        //不在手续费白名单，转账和交易需要扣税
        if (!_feeWhiteList[from] && !_feeWhiteList[to]) {
            //交易税
            txFee = _dividendFee + _marketFee;
        }
        _tokenTransfer(from, to, amount, txFee);
        //加入分红列表
        addHolder(to);
        addHolder(from);

        //分红
        if (from != address(this)) {
            processReward(500000);
        }
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 fee
    ) private {
        _balances[sender] = _balances[sender] - tAmount;
        uint256 feeAmount;
        //转账，交易
        //6%持币分BNB  2%营销
        if (fee > 0) {
            feeAmount = tAmount * fee / 100;
            //累计在合约里，等待时机卖出，分红
            _takeTransfer(
                sender,
                address(this),
                feeAmount
            );
        }
        //接收者增加余额
        _takeTransfer(sender, recipient, tAmount - feeAmount);
    }

    function swapTokenForFund(uint256 tokenAmount) private lockTheSwap {
        uint256 initialBalance = address(this).balance;

        //6%持币分BNB  2%营销，将合约里的代币兑换为 BNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _swapRouter.WETH();
        _swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 newBalance = address(this).balance - initialBalance;

        uint256 marketValue = newBalance * _marketFee / (_marketFee + _dividendFee);
        //营销钱包
        fundAddress.call{value : marketValue}("");
    }

    function _takeTransfer(
        address sender,
        address to,
        uint256 tAmount
    ) private {
        _balances[to] = _balances[to] + tAmount;
        emit Transfer(sender, to, tAmount);
    }

    //设置营销钱包
    function setFundAddress(address addr) external onlyFunder {
        fundAddress = addr;
        _feeWhiteList[addr] = true;
    }

    //设置营销卖出条件及数量，具体数量就行，不需要精度
    function setFundSellAmount(uint256 amount) external onlyFunder {
        numTokensSellToFund = amount * 10 ** _decimals;
    }

    //修改分红税率
    function setDividendFee(uint256 fee) external onlyOwner {
        _dividendFee = fee;
    }

    //修改营销税率
    function setMarketFee(uint256 fee) external onlyOwner {
        _marketFee = fee;
    }

    //设置交易手续费白名单
    function setFeeWhiteList(address addr, bool enable) external onlyFunder {
        _feeWhiteList[addr] = enable;
    }

    //领取主链币余额
    function claimBalance() external {
        payable(fundAddress).transfer(address(this).balance);
    }

    //领取代币余额
    function claimToken(address token, uint256 amount) external {
        IERC20(token).transfer(fundAddress, amount);
    }

    //持币 分红
    address[] private holders;
    mapping(address => uint256) holderIndex;
    //排除分红
    mapping(address => bool) excludeHolder;

    //加入持有列表，发生转账时就加入
    function addHolder(address adr) private {
        uint256 size;
        assembly {size := extcodesize(adr)}
        //合约地址不参与分红
        if (size > 0) {
            return;
        }
        if (0 == holderIndex[adr]) {
            if (0 == holders.length || holders[0] != adr) {
                holderIndex[adr] = holders.length;
                holders.push(adr);
            }
        }
    }

    uint256 private currentIndex;
    uint256 private holderRewardCondition;//合约里达到这么多余额开始分红
    uint256 private holderCondition;//激活分红条件
    uint256 private progressRewardBlock;

    //执行分红，使用 gas gasLimit 去执行分红
    //间隔 10 分钟分红一次
    function processReward(uint256 gas) private {
        if (progressRewardBlock + 200 > block.number) {
            return;
        }

        //当前合约余额
        uint256 balance = address(this).balance;
        if (balance < holderRewardCondition) {
            return;
        }

        address shareHolder;
        uint256 tokenBalance;
        uint256 amount;

        uint256 shareholderCount = holders.length;

        uint256 gasUsed = 0;
        uint256 iterations = 0;
        uint256 gasLeft = gasleft();

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }
            shareHolder = holders[currentIndex];
            tokenBalance = balanceOf(shareHolder);
            //不在排除列表，才分红
            if (tokenBalance > holderCondition && !excludeHolder[shareHolder]) {
                amount = balance * tokenBalance / _tTotal;
                if (amount > 0) {
                    shareHolder.call{value : amount}("");
                }
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }

        progressRewardBlock = block.number;
    }

    //设置分红的合约余额条件，即合约里的余额达到该值才分红
    function setHolderRewardCondition(uint256 amount) external onlyFunder {
        holderRewardCondition = amount;
    }

    //设置分红的持币条件，默认 2000000
    function setHolderCondition(uint256 amount) external onlyFunder {
        holderCondition = amount * 10 ** _decimals;
    }

    //是否排除分红
    function setExcludeHolder(address addr, bool enable) external onlyFunder {
        excludeHolder[addr] = enable;
    }

    modifier onlyFunder() {
        require(_owner == msg.sender || fundAddress == msg.sender, "!Funder");
        _;
    }

    receive() external payable {

    }
}

contract DividendBNB is AbsToken {
    constructor() AbsToken(
        "HoldDividendBNB",
        "HDB",
        18,
        100000000000,
    //营销钱包，也是代币接收地址
        address(0x344Efc334e084477AF5539E7287C6AEd2CE835EF),
    //分红税率
        6,
    //营销税率
        2
    ){

    }
}