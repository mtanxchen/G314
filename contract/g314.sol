/**
 *Submitted for verification at testnet.bscscan.com on 2024-05-23
*/

/**
 * Game 314
 * This is a place where dreams begin
 * G314 leads the future direction with technological changes!
 * Committed to building a democratic, fair and transparent blockchain community
 * author MtanXchen
 * date 2024-05-22
 */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IEERC314 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event AddLiquidity(uint32 _blockToUnlockLiquidity, uint256 value);
    event RemoveLiquidity(uint256 value);
    event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out);
}

abstract contract ERC314 is IEERC314{
    mapping(address account => uint256) private _balances;
    mapping(address account => uint256) private _lastTxTime;
    mapping(address account => uint32) private lastTransaction;
    mapping(address => mapping(address => uint256)) private _allowances;


    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
    */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    uint256 private _totalSupply;
    uint32 public blockToUnlockLiquidity;

    string private _name;
    string private _symbol;

    address public owner;
    address public liquidityProvider;

    bool public tradingEnable;
    bool public liquidityAdded;

    address public _gamePoolAddress = address(0x8967057D8474C2578de9C86b6178E21b5E2cA4eE);

    uint256 public taxFee = 200;


    modifier onlyOwner() {
        require(msg.sender == owner, 'Ownable: caller is not the owner');
        _;
    }

    modifier onlyLiquidityProvider() {
        require(msg.sender == liquidityProvider, 'You are not the liquidity provider');
        _;
    }

    constructor(string memory name_, string memory symbol_, uint256 totalSupply_) {
        _name = name_;
        _symbol = symbol_;
        _totalSupply = totalSupply_;
        owner = msg.sender;
        tradingEnable = false;

        _balances[msg.sender] = (totalSupply_ * 90) / 100;
        uint256 liquidityAmount = totalSupply_ - _balances[msg.sender] - _balances[_gamePoolAddress];
        _balances[address(this)] = liquidityAmount;
        liquidityAdded = false;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function allowance(address _owner, address spender) external  view returns (uint256) {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount) external  returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require(subtractedValue > 0 && _allowances[msg.sender][spender] >= subtractedValue, "BEP20: decreased allowance below zero");
        uint256 newAmount = _allowances[msg.sender][spender] - subtractedValue;
        _approve(msg.sender, spender, newAmount);
        return true;
    }

    function setGamePoolAddress(address gamePoolAddress) external onlyOwner {
        _gamePoolAddress = gamePoolAddress;
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        // sell or transfer
        if (to == address(this)) {
            sell(msg.sender, value);
        } else {
            _transfer(msg.sender, to, value);
        }
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external  returns (bool) {
        if (to == address(this)) {
            sell(from, amount);
        } else {
            _transfer(from, to, amount);
        }
        require(amount > 0 && _allowances[from][msg.sender] >= amount, 'BEP20: transfer amount exceeds allowance');

        uint256 newAmount = _allowances[from][msg.sender] - amount;
        _approve(from, msg.sender, newAmount);
        return true;
    }

    function getReserves() public view returns (uint256, uint256) {
        return (address(this).balance, _balances[address(this)]);
    }

    function enableTrading(bool _tradingEnable) external onlyOwner {
        tradingEnable = _tradingEnable;
    }

    function renounceOwnership() external onlyOwner {
        owner = address(0);
    }

    function addLiquidity(uint32 _blockToUnlockLiquidity) public payable onlyOwner {
        require(liquidityAdded == false, 'Liquidity already added');

        liquidityAdded = true;

        require(msg.value > 0, 'No ETH sent');
        require(block.number < _blockToUnlockLiquidity, 'Block number too low');

        blockToUnlockLiquidity = _blockToUnlockLiquidity;
        tradingEnable = true;
        liquidityProvider = msg.sender;

        emit AddLiquidity(_blockToUnlockLiquidity, msg.value);
    }

    function removeLiquidity() public onlyLiquidityProvider {
        require(block.number > blockToUnlockLiquidity, 'Liquidity locked');

        tradingEnable = false;

        payable(msg.sender).transfer(address(this).balance);

        emit RemoveLiquidity(address(this).balance);
    }

    function extendLiquidityLock(uint32 _blockToUnlockLiquidity) public onlyLiquidityProvider {
        require(blockToUnlockLiquidity < _blockToUnlockLiquidity, "You can't shorten duration");

        blockToUnlockLiquidity = _blockToUnlockLiquidity;
    }

    function getAmountOut(uint256 value, bool _buy) public view returns (uint256) {
        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        if (_buy) {
            return (value * reserveToken) / (reserveETH + value);
        } else {
            return (value * reserveETH) / (reserveToken + value);
        }
    }

    function buy() internal {
        require(tradingEnable, 'Trading not enable');
        uint256 swapEthAmount = (msg.value / 10000) * (10000 - taxFee);
        uint256 taxEthAmount = msg.value - swapEthAmount;
        uint256 tokenAmount = (swapEthAmount * _balances[address(this)]) / (address(this).balance);
        _transfer(address(this), msg.sender, tokenAmount);
        payable(_gamePoolAddress).transfer(taxEthAmount);
        emit Swap(msg.sender, msg.value, 0, 0, tokenAmount);
    }

    function sell(address _owner, uint256 sell_amount) internal {
        require(tradingEnable, 'Trading not enable');
        uint256 ethAmount = (sell_amount * address(this).balance) / (_balances[address(this)] + sell_amount);
        require(ethAmount > 0, 'Sell amount too low');
        require(address(this).balance >= ethAmount, 'Insufficient ETH in reserves');
        uint256 swapEthAmount = (ethAmount / 10000) * (10000 - taxFee);
        uint256 taxEthAmount = ethAmount - swapEthAmount;

        _transfer(_owner, address(this), sell_amount);
        payable(_owner).transfer(swapEthAmount);
        payable(_gamePoolAddress).transfer(taxEthAmount);
        emit Swap(msg.sender, 0, sell_amount, swapEthAmount, 0);
    }

    function _approve(address _owner, address spender, uint256 amount) internal {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 value) internal virtual {
        if (to != address(0) && to != _gamePoolAddress) {
            require(lastTransaction[msg.sender] != block.number, "You can't make two transactions in the same block");
            lastTransaction[msg.sender] = uint32(block.number);
            require(block.timestamp >= _lastTxTime[msg.sender] + 60, 'Sender must wait for cooldown');
            _lastTxTime[msg.sender] = block.timestamp;
        }

        require(_balances[from] >= value, 'ERC20: transfer amount exceeds balance');

        unchecked {
            _balances[from] = _balances[from] - value;
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    receive() external payable {
        buy();
    }
}

contract GAME314 is ERC314 {
    constructor() ERC314('Game 314', 'G314', 210000000 * 10 ** 18) {}
}