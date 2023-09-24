// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20 {
function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);
function transfer(address recipient, uint256 amount) external returns (bool);
function allowance(address owner, address spender) external view returns (uint256);
function approve(address spender, uint256 amount) external returns (bool);
function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

}

contract TEX is IERC20 {
mapping (address => uint256) private _balances;
mapping (address => mapping (address => uint256)) private _allowances;
mapping (address => bool) private _excludedFromFee;
string private _name = "TEX";
string private _symbol = "TEX";
uint8 private _decimals = 5;
uint256 private _totalSupply;
address private _owner;
uint256 private _maxTxAmount;
constructor() {
    uint256 initialSupply = 1000000000000000; // 100,000 tokens
    _totalSupply = initialSupply;
    _balances[msg.sender] = initialSupply;
    emit Transfer(address(0), msg.sender, initialSupply);

    _owner = msg.sender;
    _maxTxAmount = _totalSupply / 100; // 1% of the total supply
}

modifier onlyOwner() {
    require(msg.sender == _owner, "Only the owner can perform this action");
    _;
}


function name() public view returns (string memory) {
    return _name;
}

function symbol() public view returns (string memory) {
    return _symbol;
}

function decimals() public view returns (uint8) {
    return _decimals;
}

function totalSupply() public view override returns (uint256) {
    return _totalSupply;
}

function balanceOf(address account) public view override returns (uint256) {
    if (_excludedFromFee[account]) {
        return _balances[account];
    }
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
    _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
    return true;
}

function excludeFromFee(address account) public onlyOwner() {
    require(!_excludedFromFee[account], "Account is already excluded from fee");
    _excludedFromFee[account] = true;
}

function includeInFee(address account) external onlyOwner() {
    require(_excludedFromFee[account], "Account is already included in fee");
    _excludedFromFee[account] = false;
}

function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner() {
    require(maxTxAmount > 0, "Max transaction amount must be greater than 0");
    _maxTxAmount = maxTxAmount;
}

function renounceOwnership() public onlyOwner() {
    emit OwnershipTransferred(_owner, address(0));
_owner = address(0);
}

function transferOwnership(address newOwner) public onlyOwner() {
require(newOwner != address(0), "New owner is the zero address");
emit OwnershipTransferred(_owner, newOwner);
_owner = newOwner;
}

function _transfer(address sender, address recipient, uint256 amount) private {
require(sender != address(0), "Transfer from the zero address");
require(recipient != address(0), "Transfer to the zero address");
require(amount > 0, "Transfer amount must be greater than 0");
require(amount <= _maxTxAmount, "Transfer amount exceeds the max transaction amount");

if (_excludedFromFee[sender] || _excludedFromFee[recipient]) {
    _balances[sender] -= amount;
    _balances[recipient] += amount;
    emit Transfer(sender, recipient, amount);
} else {
    uint256 fee = amount / 100; // 1% fee
    _balances[sender] -= amount;
    _balances[recipient] += amount - fee;
    _balances[address(this)] += fee;
    emit Transfer(sender, recipient, amount);
    emit Transfer(sender, address(this), fee);
}
}

function _approve(address owner, address spender, uint256 amount) private {
require(owner != address(0), "Approve from the zero address");
require(spender != address(0), "Approve to the zero address");
require(amount > 0, "Approve amount must be greater than 0");
_allowances[owner][spender] = amount;
emit Approval(owner, spender, amount);
}

}