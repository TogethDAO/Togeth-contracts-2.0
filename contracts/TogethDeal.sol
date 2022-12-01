// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Together} from "./TogethCore.sol";
import {IAllowList} from "./Interface.sol";

contract TogetherDeal is Together {
    IAllowList public immutable allowList;
    uint16 public constant VERSION = 1;

    // ============ Events ============
    event Bought(
        address triggeredBy,
        address targetAddress,
        string tokenid,
        address propsal
    );

    event Sell(
        address triggeredBy,
        address targetAddress,
        string tokenid,
        uint256 expiresAt,
        address propsal
    );

    event Bought(address triggeredBy, address targetAddress, address propsal);

    event Cancle(address triggeredBy, address targetAddress, address propsal);

    // ======== Modifiers =========

    modifier onlyTogethDAO() {
        require(msg.sender == togetherDAO, "No authorization");
        _;
    }

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
        uint256 _nftTokenId,
        address _token,
        uint256 _tokenAmount,
        uint256 _secondsToTimeoutFoundraising,
        uint256 _secondsToTimeoutBuy,
        uint256 _secondsToTimeoutSell,
        string memory _name
    ) external initializer {
        require(_tokenAmount > 0, "tokenAmount must higher than 0");
        __Togeth_init(
            _nftContract,
            _token,
            _tokenAmount,
            _secondsToTimeoutFoundraising,
            _secondsToTimeoutBuy
        );
    }

    // ======== External: Buy =========

    function buy(
        uint256 _value,
        address _targetContract,
        string memory _tokenid,
        bytes calldata _calldata
    ) external nonReentrant {
        require(step = 2, "not active");
        require(allowList.allowed(_targetContract), "Not on AllowList");
        require(_value > 0, "value can't spend zero");

        (bool _success, bytes memory _returnData) = address(_targetContract)
            .call{value: _value}(_calldata);

        require(_success, string(_returnData));
        require(_getOwner() == address(this), "failed to buy token");
        tokenId = _tokenid;
        step = 3;

        // emit Bought event
        emit Bought(
            msg.sender,
            _targetContract,
            _tokenid,
            _value,
            address(this)
        );
    }

    // ======== External: Sell =========

    function sell(
        uint256 _value,
        address _targetContract,
        string memory _tokenid,
        uint256 _expiresAt,
        bytes calldata _calldata
    ) external nonReentrant {
        require(step = 3, "not active");
        require(allowList.allowed(_targetContract), "Not on AllowList");
        require(_value > 0, "value can't spend zero");

        (bool _success, bytes memory _returnData) = address(_targetContract)
            .call{value: _value}(_calldata);

        require(_success, string(_returnData));
        require(_getOwner() != address(this), "failed to sell token");
        tokenId = _tokenid;
        step = 4;

        emit Sell(
            msg.sender,
            _targetContract,
            _tokenid,
            _value,
            _expiresAt,
            address(this)
        );
    }

    // ======== External: Cancle ========

    function cancle(
        uint256 _value,
        address _targetContract,
        string memory _tokenid,
        bytes calldata _calldata
    ) external nonReentrant {
        require(step = 3, "not active");
        require(allowList.allowed(_targetContract), "Not on AllowList");

        (bool _success, bytes memory _returnData) = address(_targetContract)
            .call{value: _value}(_calldata);

        require(_success, string(_returnData));
        require(_getOwner() = address(this), "failed to cancle token");

        emit Cancle(msg.sender, _targetContract, _tokenid, address(this));
    }

    function _getOwner() internal view returns (address _owner) {
        (bool _success, bytes memory _returnData) = address(nftContract)
            .staticcall(abi.encodeWithSignature("ownerOf(uint256)", tokenId));
        if (_success && _returnData.length > 0) {
            _owner = abi.decode(_returnData, (address));
        }
    }
}
