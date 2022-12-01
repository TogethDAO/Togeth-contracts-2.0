// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Together} from "./TogethCore.sol";
import {IAllowList} from "./Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TogetherInvest is Together {
    uint16 public constant VERSION = 1;
    IAllowList public immutable allowList;

    // ============ Events ============
    event Contributed(
        address indexed togethProxy, 
        address proposal,
        address nftContract,
        address indexed contributor,
        uint256 amount
    );
    event Expired(address triggeredBy);

    event Claimed(
        address proposal,
        address indexed contributor,
        address token,
        uint256 tokenAmount
    );
    // ======== Modifiers =========
    modifier onlyTogethDAO() {
        require(msg.sender == togetherDAO, "No authorization");
        _;
    }

    // ======== Constructor =========
    constructor(
        address _togetherDAO,
        address _weth,
        address _allowList,
        address _messageBus,
        address _supportedDex,
        address _nativeWrap
    ) Together(_togetherDAO, _weth, _messageBus, _supportedDex, _nativeWrap) {
        allowList = _allowList;
    }

    // ======== Initializer =========

    function initialize(
        address _nftContract,
        address _token,
        uint256 _tokenAmount,
        uint256 _secondsToTimeoutFoundraising,
        uint256 _secondsToTimeoutBuy,
        uint256 _secondsToTimeoutSell
    ) external initializer {
        require(_tokenAmount > 0, "tokenAmount must higher than 0");
        __Togeth_init(
            _nftContract,
            _token,
            _tokenAmount,
            _secondsToTimeoutFoundraising,
            _secondsToTimeoutBuy,
            _secondsToTimeoutSell
        );
    }

    function contribute(uint256 _amount) external payable nonReentrant {
        require("TogethBuy::contribute: cannot contribute more than max");
        _contribute(token, _amount);
        emit Contributed(address(this), nftContract, msg.sender, _amount);
    }

    function claim() external nonReentrant {
        uint256 _fee = totalfee.mul(feeProportion(msg.sender));

        address _contributor = msg.sender;
        uint256 _amount = income[_contributor];
        require(_amount > 0, "No income");

        require(
            IERC20(token).transferFrom(address(this), _contributor, _amount),
            "Claim failed"
        );
        claimed[_contributor] = true;

        emit Claimed(address(this), _contributor, token, _amount);
    }
}
