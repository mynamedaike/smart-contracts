pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------//  
  // ------------------------------------------ //

  // ERC-20 allowances: owner => spender => amount
  mapping (address => mapping (address => uint256)) private _allowances;

  // Dividend tracking
  mapping (address => uint256) private _withdrawableDividend;

  // Efficient holder list using array + index mapping
  address[] private _holders;
  mapping (address => uint256) private _holderIndex; // 1-based index into _holders (0 means not in list)

  // --- Internal holder management ---

  function _addHolder(address account) internal {
    if (_holderIndex[account] == 0 && balanceOf[account] > 0) {
      _holders.push(account);
      _holderIndex[account] = _holders.length; // 1-based
    }
  }

  function _removeHolder(address account) internal {
    if (_holderIndex[account] != 0 && balanceOf[account] == 0) {
      uint256 idx = _holderIndex[account] - 1; // convert to 0-based
      uint256 lastIdx = _holders.length - 1;

      if (idx != lastIdx) {
        // Swap with last element
        address lastHolder = _holders[lastIdx];
        _holders[idx] = lastHolder;
        _holderIndex[lastHolder] = idx + 1; // 1-based
      }

      _holders.pop();
      _holderIndex[account] = 0;
    }
  }

  // --- IERC20 ---

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(balanceOf[msg.sender] >= value, "Insufficient balance");

    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    _removeHolder(msg.sender);
    _addHolder(to);

    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(balanceOf[from] >= value, "Insufficient balance");
    require(_allowances[from][msg.sender] >= value, "Insufficient allowance");

    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);

    _removeHolder(from);
    _addHolder(to);

    return true;
  }

  // --- IMintableToken ---

  function mint() external payable override {
    require(msg.value > 0, "Must send ETH to mint");

    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);

    _addHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];

    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);

    _removeHolder(msg.sender);

    dest.transfer(amount);
  }

  // --- IDividends ---

  function getNumTokenHolders() external view override returns (uint256) {
    return _holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > _holders.length) {
      return address(0);
    }
    return _holders[index - 1]; // convert 1-based to 0-based
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Must send ETH for dividend");

    uint256 dividendAmount = msg.value;
    uint256 supply = totalSupply;

    for (uint256 i = 0; i < _holders.length; i++) {
      address holder = _holders[i];
      uint256 share = dividendAmount.mul(balanceOf[holder]).div(supply);
      _withdrawableDividend[holder] = _withdrawableDividend[holder].add(share);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return _withdrawableDividend[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = _withdrawableDividend[msg.sender];
    _withdrawableDividend[msg.sender] = 0;
    dest.transfer(amount);
  }
}