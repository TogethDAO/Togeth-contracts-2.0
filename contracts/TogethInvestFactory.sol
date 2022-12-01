// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {TogetherProxy} from "./TogethProxy.sol";
import {TogetherInvest} from "./TogethInvest.sol";

contract TogetherInvestFactory {
    //======== Events ========

    event CreateProposalDeploy(
        address indexed creator,
        address indexed nftContract,
        uint256 nftTokenId,
        address token,
        uint256 tokenAmount,
        uint256 secondsToTimeoutFoundraising,      
        uint256 secondsToTimeoutBuy,
        uint256 secondsToTimeoutSell,
        string name 
        
    );

    //======== Immutable storage =========

    address public immutable logic;   // the logic contract
    address public immutable togetherDAO;  // the tx_fee charging address
    address public immutable weth;    

    //======== Constructor =========
    constructor(
        address _togetherDAO,     
        address _weth,
        address _allowList
    ) {
        togetherDAO = _togetherDAO; 
      
        weth = _weth;
        // deploy logic contract
        TogetherInvest _logicContract = new TogetherInvest(
            _togetherDAO,           
            _weth,
            _allowList
        );
        // store logic contract address
        logic = address(_logicContract);
    }

    //======== Deploy function =========

    function createProposal(
        address _nftContract,        
        address _token,    
        uint256 _tokenAmount,
        uint256 _secondsToTimeoutFoundraising,
        uint256 _secondsToTimeoutBuy,
        uint256 _secondsToTimeoutSell               
    ) external returns (address togetherProxy) {
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            TogetherInvest.initialize.selector,
            _nftContract,           
            _token,
            _tokenAmount,
            _secondsToTimeoutFoundraising,
            _secondsToTimeoutBuy, 
            _secondsToTimeoutSell               
        );
   
       togetherProxy = address(
            new TogetherProxy(logic, _initializationCalldata)
        );

        emit CreateProposalDeploy(
            togetherProxy,
            msg.sender,
            _nftContract,         
            _token,
            _tokenAmount,
            _secondsToTimeoutFoundraising,
            _secondsToTimeoutBuy,
            _secondsToTimeoutSell         
        );
    }
}