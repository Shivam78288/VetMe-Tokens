// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@routerprotocol/router-crosstalk/contracts/RouterCrossTalkUpgradeable.sol";
import "./IUniswapFactory.sol";
import "./IUniswapV2Router02.sol";

contract VetMe is
    Initializable,
    ContextUpgradeable,
    IERC20Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    RouterCrossTalkUpgradeable
{
    using SafeMathUpgradeable for uint256;

    string private constant _name = "VetMe";
    string private constant _symbol = "VetMe";
    uint8 private constant _decimals = 9;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 1000000000 * 10**9;
    uint256 private _rTotal;
    uint256 private _currentSupply;
    uint256 private _tFeeTotal;
    uint256 private _redisFeeOnBuy;
    uint256 private _taxFeeOnBuy;
    uint256 private _redisFeeOnSell;
    uint256 private _taxFeeOnSell;

    //Original Fee
    uint256 private _redisFee;
    uint256 private _taxFee;

    uint256 private _previousredisFee;
    uint256 private _previoustaxFee;

    mapping(address => bool) public bots;
    mapping(address => uint256) public _buyMap;
    address payable private _developmentAddress;
    address payable private _marketingAddress;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool private tradingOpen;
    bool private inSwap;
    bool private swapEnabled;

    uint256 public _maxTxAmount;
    uint256 public _maxWalletSize;
    uint256 public _swapTokensAtAmount;

    uint64 public nonce;
    mapping(uint64 => bytes32) public nonceToHash;

    event TxCreated(uint64 indexed nonce, uint256 amount);
    event MaxTxAmountUpdated(uint256 _maxTxAmount);

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    function initialize(address handler, address feeToken)
        external
        initializer
    {
        __Ownable_init_unchained();
        __Context_init_unchained();
        __RouterCrossTalkUpgradeable_init_unchained(handler);

        setLink(msg.sender);
        setFeeToken(feeToken);
        approveFees(feeToken, 1000000000000000000000000);

        _rTotal = (MAX - (MAX % _tTotal));

        tradingOpen = true;
        swapEnabled = true;

        _developmentAddress = payable(
            0xc791AE7170Ab0B1F1ec4434559BD36DAE3374694
        );
        _marketingAddress = payable(0xc791AE7170Ab0B1F1ec4434559BD36DAE3374694);

        _maxTxAmount = 4000000 * 10**9;
        _maxWalletSize = 5000000 * 10**9;
        _swapTokensAtAmount = 10000 * 10**9;

        _taxFeeOnBuy = 5;
        _taxFeeOnSell = 5;

        _redisFee = _redisFeeOnSell;
        _taxFee = _taxFeeOnSell;

        _previousredisFee = _redisFee;
        _previoustaxFee = _taxFee;

        // _rOwned[_msgSender()] = _rTotal;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x16e71B13fE6079B4312063F7E81F76d165Ad32Ad
        ); //
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_developmentAddress] = true;
        _isExcludedFromFee[_marketingAddress] = true;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _currentSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address _owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _mint(address recipient, uint256 amount) internal {
        _currentSupply += amount;
        uint256 currentRate = _getRate();
        _rOwned[recipient] = amount.mul(currentRate);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 currentRate = _getRate();
        _currentSupply -= amount;
        _rOwned[from] -= amount.mul(currentRate);
    }

    function setUniswapRouterAndLp(address uniswapRouter, address uniswapPair)
        external
        onlyOwner
    {
        uniswapV2Router = IUniswapV2Router02(uniswapRouter);
        uniswapV2Pair = uniswapPair;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function tokenFromReflection(uint256 rAmount)
        private
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function removeAllFee() private {
        if (_redisFee == 0 && _taxFee == 0) return;

        _previousredisFee = _redisFee;
        _previoustaxFee = _taxFee;

        _redisFee = 0;
        _taxFee = 0;
    }

    function restoreAllFee() private {
        _redisFee = _previousredisFee;
        _taxFee = _previoustaxFee;
    }

    function _approve(
        address _owner,
        address spender,
        uint256 amount
    ) private {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (from != owner() && to != owner()) {
            //Trade start check
            if (!tradingOpen) {
                require(
                    from == owner(),
                    "TOKEN: This account cannot send tokens until trading is enabled"
                );
            }

            require(amount <= _maxTxAmount, "TOKEN: Max Transaction Limit");
            require(
                !bots[from] && !bots[to],
                "TOKEN: Your account is blacklisted!"
            );

            if (to != uniswapV2Pair) {
                require(
                    balanceOf(to) + amount < _maxWalletSize,
                    "TOKEN: Balance exceeds wallet size!"
                );
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            bool canSwap = contractTokenBalance >= _swapTokensAtAmount;

            if (contractTokenBalance >= _maxTxAmount) {
                contractTokenBalance = _maxTxAmount;
            }

            if (
                canSwap &&
                !inSwap &&
                from != uniswapV2Pair &&
                swapEnabled &&
                !_isExcludedFromFee[from] &&
                !_isExcludedFromFee[to]
            ) {
                swapTokensForEth(contractTokenBalance);
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        bool takeFee = true;

        //Transfer Tokens
        if (
            (_isExcludedFromFee[from] || _isExcludedFromFee[to]) ||
            (from != uniswapV2Pair && to != uniswapV2Pair)
        ) {
            takeFee = false;
        } else {
            //Set Fee for Buys
            if (from == uniswapV2Pair && to != address(uniswapV2Router)) {
                _redisFee = _redisFeeOnBuy;
                _taxFee = _taxFeeOnBuy;
            }

            //Set Fee for Sells
            if (to == uniswapV2Pair && from != address(uniswapV2Router)) {
                _redisFee = _redisFeeOnSell;
                _taxFee = _taxFeeOnSell;
            }
        }

        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function sendETHToFee(uint256 amount) private {
        _marketingAddress.transfer(amount);
    }

    function setTrading(bool _tradingOpen) public onlyOwner {
        tradingOpen = _tradingOpen;
    }

    function manualswap() external {
        require(
            _msgSender() == _developmentAddress ||
                _msgSender() == _marketingAddress
        );
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForEth(contractBalance);
    }

    function manualsend() external {
        require(
            _msgSender() == _developmentAddress ||
                _msgSender() == _marketingAddress
        );
        uint256 contractETHBalance = address(this).balance;
        sendETHToFee(contractETHBalance);
    }

    function blockBots(address[] memory bots_) public onlyOwner {
        for (uint256 i = 0; i < bots_.length; i++) {
            bots[bots_[i]] = true;
        }
    }

    function unblockBot(address notbot) public onlyOwner {
        bots[notbot] = false;
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();
        _transferStandard(sender, recipient, amount);
        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tTeam
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeTeam(tTeam);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _takeTeam(uint256 tTeam) private {
        uint256 currentRate = _getRate();
        uint256 rTeam = tTeam.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rTeam);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    receive() external payable {}

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 tTransferAmount, uint256 tFee, uint256 tTeam) = _getTValues(
            tAmount,
            _redisFee,
            _taxFee
        );
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tTeam,
            currentRate
        );
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tTeam);
    }

    function _getTValues(
        uint256 tAmount,
        uint256 redisFee,
        uint256 taxFee
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = tAmount.mul(redisFee).div(100);
        uint256 tTeam = tAmount.mul(taxFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tTeam);
        return (tTransferAmount, tFee, tTeam);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tTeam,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTeam = tTeam.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rTeam);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function setFee(
        uint256 redisFeeOnBuy,
        uint256 redisFeeOnSell,
        uint256 taxFeeOnBuy,
        uint256 taxFeeOnSell
    ) public onlyOwner {
        require(
            redisFeeOnBuy >= 0 && redisFeeOnBuy <= 4,
            "Buy rewards must be between 0% and 4%"
        );
        require(
            taxFeeOnBuy >= 0 && taxFeeOnBuy <= 98,
            "Buy tax must be between 0% and 98%"
        );
        require(
            redisFeeOnSell >= 0 && redisFeeOnSell <= 4,
            "Sell rewards must be between 0% and 4%"
        );
        require(
            taxFeeOnSell >= 0 && taxFeeOnSell <= 98,
            "Sell tax must be between 0% and 98%"
        );

        _redisFeeOnBuy = redisFeeOnBuy;
        _redisFeeOnSell = redisFeeOnSell;
        _taxFeeOnBuy = taxFeeOnBuy;
        _taxFeeOnSell = taxFeeOnSell;
    }

    //Set minimum tokens required to swap.
    function setMinSwapTokensThreshold(uint256 swapTokensAtAmount)
        public
        onlyOwner
    {
        _swapTokensAtAmount = swapTokensAtAmount;
    }

    //Set minimum tokens required to swap.
    function toggleSwap(bool _swapEnabled) public onlyOwner {
        swapEnabled = _swapEnabled;
    }

    //Set maximum transaction
    function setMaxTxnAmount(uint256 maxTxAmount) public onlyOwner {
        _maxTxAmount = maxTxAmount;
    }

    function setMaxWalletSize(uint256 maxWalletSize) public onlyOwner {
        _maxWalletSize = maxWalletSize;
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFee[accounts[i]] = excluded;
        }
    }

    /// @notice Function to be called to send VetMe tokens to the other chain
    /// @param  _chainID ChainId of the destination chain(router specs)
    /// @param  _amount Amount of tokens to be transferred to the destination chain
    /// @param  _crossChainGasPrice Gas price to be used while executing the cross-chain tx.
    /// @notice If you pass a gas limit and price that are lower than what is expected on the
    /// destination chain, your transaction can get stuck on the bridge. You can always replay
    /// these transactions using the replay transaction function by passing a higher gas limit and price.
    function sendVetMeCrossChain(
        uint8 _chainID,
        address _recipient,
        uint256 _amount,
        uint256 _crossChainGasPrice
    ) external returns (bool) {
        nonce = nonce + 1;
        bytes memory _data = abi.encode(_recipient, _amount);

        _burn(msg.sender, _amount);

        (bool success, bytes32 hash) = routerSend(
            _chainID,
            0x00000000,
            _data,
            350000,
            _crossChainGasPrice
        );

        nonceToHash[nonce] = hash;
        require(success == true, "unsuccessful");

        emit TxCreated(nonce, _amount);
        return success;
    }

    /// @notice Function to replay a transaction stuck on the bridge due to insufficient
    /// gas price or limit passed while setting greeting cross-chain
    /// @param _nonce Nonce of the transaction you want to execute
    /// @param _crossChainGasLimit Updated gas limit
    /// @param _crossChainGasPrice Updated gas price
    function replaySendVetMeCrossChain(
        uint64 _nonce,
        uint256 _crossChainGasLimit,
        uint256 _crossChainGasPrice
    ) external onlyOwner {
        routerReplay(
            nonceToHash[_nonce],
            _crossChainGasLimit,
            _crossChainGasPrice
        );
    }

    /// @notice Function which handles an incoming cross-chain request from another chain
    /// @dev You need to implement your logic here as to what you want to do when a request
    /// from another chain is received
    // /// @param _selector Selector to the function which will be called on this contract
    /// @param _data Data to be called on that selector. You need to decode the data as per
    /// your requirements before calling the function
    /// In this contract, the selector is received for the receiveTokens(uint256) function and
    /// the data contains abi.encode(amount)
    function _routerSyncHandler(
        bytes4, /**_selector*/
        bytes memory _data
    ) internal override returns (bool, bytes memory) {
        (address _recipient, uint256 _amount) = abi.decode(
            _data,
            (address, uint256)
        );
        _mint(_recipient, _amount);
        return (true, "");
    }

    /// @notice Function to recover fee tokens sent to this contract
    /// @notice Only the owner address can call this function
    function recoverFeeTokens() external onlyOwner {
        address feeToken = this.fetchFeeToken();
        uint256 amount = IERC20Upgradeable(feeToken).balanceOf(address(this));
        IERC20Upgradeable(feeToken).transfer(msg.sender, amount);
    }
}
