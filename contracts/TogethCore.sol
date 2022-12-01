// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC1271Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC1271Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ERC721HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {SafeMath} from "./SafeMath.sol";
import {IWETH} from "./Interface.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TransferSwap} from "./TransferSwap.sol";
import "./sgn-v2-contracts/contracts/message/libraries/MessageSenderLib.sol";

/// @author The TogethDAO Team
/// @title The core DAO contract
contract Together is
    TransferSwap,
    ReentrancyGuardUpgradeable,
    ERC721HolderUpgradeable,
    IERC1271Upgradeable
{
    using SafeMath for uint256;

    uint256 constant CONST_SQRTNUMBER = 18446744073709551616;
    uint256 constant CONST_PROPORTION = 10e4;
    uint256 constant MIN_FEE = 500; // the minimum of fee charge

    address public immutable togetherFactory;
    address public immutable togetherDAO;

    IWETH public immutable weth;

    IERC721Metadata public nftContract;
    uint256 public tokenId;
    uint256 public createAt; // the proposal creation time
    IERC20 public token; // the funding token
    uint256 public preAmount; // the funding amount set in advance
    uint256 public actualAmount; // the actual funding amount
    uint256 public foundExpiresAt; // second  the expired funding time
    uint256 public buyExpiresAt; // second   the expired buying time
    uint256 public sellExpiresAt;
    uint256 public step; // 0 funding 1 cross-to 2 purchase 3 selling  4 cross-back 5 claim
    uint256[] public proportionList;

    // ============ Public Mutable Storage ============
    mapping(address => uint256) public contributions;
    address[] public conributorList;
    mapping(address => uint256) public income;
    mapping(address => uint256) public fee;
    mapping(address => bool) public claimed;
    uint256 public totalfee;
    uint256 public totalIncome; // total income after cross-back
    modifier onlyTogethDAO() {
        require(msg.sender == togetherDAO, "No authorization");
        _;
    }

    // ======== Constructor =========
    constructor(
        address _togetherDAO,
        address _weth,
        address _messageBus,
        address _supportedDex,
        address _nativeWrap
    ) TransferSwap(_messageBus, _supportedDex, _nativeWrap) {
        togetherFactory = msg.sender;
        togetherDAO = _togetherDAO;
        weth = IWETH(_weth);
        // cross-chain
        messageBus = _messageBus;
        supportedDex[_supportedDex] = true;
        nativeWrap = _nativeWrap;
    }

    // ======== External: Return bill =========

    /**
     * @notice Record the tx_fee charge of each contributor
     * @param _totalfee the total tx_fee of the process
     */
    function returnIncome(uint256 _totalfee) external {
        totalfee = _totalfee;

        for (uint256 i = 0; i < conributorList.length; i++) {
            address contributor = conributorList[i];
            uint256 proportion = feeProportion(contributor);
            uint256 _fee = proportion.mul(_totalfee).div(CONST_PROPORTION);

            uint256 _income = (investProportion(contributor).mul(totalIncome))
                .div(CONST_PROPORTION) - _fee;
            income[contributor] = _income;
            fee[contributor] = _fee;
        }
    }

    /**
     * @notice Escape hatch: in case of emergency,
     * TogethDAO can use emergencyCall to call an external contract
     * (e.g. to withdraw a stuck NFT or stuck ERC-20s)
     */
    function emergencyCall(address _contract, bytes memory _calldata)
        external
        onlyTogethDAO
        returns (bool _success, bytes memory _returnData)
    {
        (_success, _returnData) = _contract.call(_calldata);
        require(_success, string(_returnData));
    }

    function emergencyWithdrawEth(uint256 _value) external onlyTogethDAO {
        _transferETHOrWETH(togetherDAO, _value);
    }

    // ======== Internal: Init =========
    function __Togeth_init(
        address _nftContract,
        address _token,
        uint256 _tokenAmount,
        uint256 _secondsToTimeoutFoundraising,
        uint256 _secondsToTimeoutBuy,
        uint256 _secondsToTimeoutSell
    ) internal {
        require(msg.sender == togetherFactory, "only factory can init");
        require(_token != address(0) && _tokenAmount != 0, "invalid parameter");

        __ReentrancyGuard_init();
        __ERC721Holder_init();

        nftContract = IERC721Metadata(_nftContract);
        token = IERC20(_token);
        preAmount = _tokenAmount;
        foundExpiresAt = block.timestamp + _secondsToTimeoutFoundraising;
        buyExpiresAt = foundExpiresAt + _secondsToTimeoutBuy;
        sellExpiresAt = buyExpiresAt + _secondsToTimeoutSell;
        step = 0;
    }

    function _contribute(address _token, uint256 _amount) internal {
        require(step == 0, "not active");
        address _contributor = msg.sender;
        uint256 number = preAmount - actualAmount;
        require(
            _amount <= number && _amount > 0,
            "Amount must be less " + number
        );
        require(
            IERC20(_token).transfer(address(this), _amount),
            "Transfer failed"
        );

        actualAmount = actualAmount.add(_amount);

        contributions[_contributor] = _amount;
        conributorList.push(_contributor);

        if (actualAmount >= preAmount) {
            step = 1; // funding has complated and cross-to begins
        }
    }

    /**
     * @notice Calculate the investing proportion of a given contributor
     * @param _contributor the address of contributor
     */
    function investProportion(address _contributor)
        internal
        view
        returns (uint256 _proportion)
    {
        _proportion = contributions[_contributor].mul(CONST_PROPORTION).div(
            actualAmount
        );
        return _proportion;
    }

    /**
     * @notice Calculate the fee proportion of a given contributor
     * @param _contributor the address of contributor
     */
    function feeProportion(address _contributor)
        internal
        returns (uint256 _proportion)
    {
        address[] memory contributorList = conributorList;
        uint256[] memory proportionList;
        for (uint256 i = 0; i < contributorList.length; i++) {
            uint256 _proportion = investProportion(contributorList[i]).mul(
                CONST_SQRTNUMBER
            );
            uint256 number = sqrt(_proportion);
            proportionList[i] = number;
        }
        uint256 _sum = sum(proportionList);
        uint256 amount = sqrt(
            investProportion(_contributor).mul(CONST_SQRTNUMBER)
        );
        _proportion = amount.mul(CONST_PROPORTION).div(_sum);

        return _proportion;
    }

    // ============ Internal: TransferEthOrWeth ============
    function _transferETHOrWETH(address _to, uint256 _value) internal {
        // skip if attempting to send 0 ETH
        if (_value == 0) {
            return;
        }
        if (_value > address(this).balance) {
            _value = address(this).balance;
        }
        if (!_attemptETHTransfer(_to, _value)) {
            weth.deposit{value: _value}();
            weth.transfer(_to, _value);
        }
    }

    function _attemptETHTransfer(address _to, uint256 _value)
        internal
        returns (bool)
    {
        (bool success, ) = _to.call{value: _value, gas: 30000}("");
        return success;
    }

    // EIP1271
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        override
        returns (bytes4 magicValue)
    {
        bytes32 messageHash = keccak256(abi.encodePacked(hash));
        address signer = messageHash.recover(signature);
        if (signer == owner) {
            return 0x1626ba7e;
        } else {
            return 0xffffffff;
        }
    }

    //  ================== Util ========================
    function sqrt(uint256 y) internal pure returns (uint256) {
        if (y > 3) {
            uint256 z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
            return z;
        } else if (y != 0) {
            return 1;
        } else {
            return 0;
        }
    }

    function sum(uint256[] memory _arr) internal pure returns (uint256 s) {
        for (uint256 i = 0; i < _arr.length; i++) {
            s.add(_arr[i]);
        }
    }
}
