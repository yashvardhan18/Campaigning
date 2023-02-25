//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "hardhat/console.sol";

contract crowdFunding is Initializable, ReentrancyGuardUpgradeable {
    struct cmp {
        uint256 campaignID;
        mapping(uint256 => campaign) details;
    }
    struct campaign {
        address creator;
        uint256 targetAmount;
        uint256 currentFundingAmount;
        uint256 targetTime;
        address currencyToken;
        bool completed;
    }
    cmp private detail;
    mapping(address => mapping(uint256 => uint256)) public donationDetails;
    mapping(address => cmp) public campaignDetails;

    event crowdFund(
        address creator,
        uint256 campaignId,
        uint256 targetAmount,
        uint256 targetTime,
        address currencyToken
    );

    event donated(uint256 campaignId, uint256 donationAmount);

    function initialize() external initializer {
        __ReentrancyGuard_init_unchained();
    }

    function createCampaign(
        uint256 _targetAmount,
        uint256 _targetTime,
        address _token
    ) external {
        require(_targetAmount > 0, "ITA"); //Invalid Target Amount
        require(_targetTime > block.timestamp, "ITT"); //Invalid Target Time
        require(_token != address(0), "ZAT"); //Zero Address for Token

        uint256 id = campaignDetails[msg.sender].campaignID;
        id++;

        campaignDetails[msg.sender].campaignID = id;
        campaignDetails[msg.sender].details[id].creator = msg.sender;
        campaignDetails[msg.sender].details[id].targetAmount = _targetAmount;
        campaignDetails[msg.sender].details[id].targetTime = _targetTime;
        campaignDetails[msg.sender].details[id].currencyToken = _token;

        emit crowdFund(msg.sender, id, _targetAmount, _targetTime, _token);
    }

    function donate(
        uint256 campaignId,
        address creator,
        uint256 donationAmount
    ) external nonReentrant {
        require(!campaignDetails[creator].details[campaignId].completed, "CC"); // Campaign Completed
        require(
            block.timestamp <
                campaignDetails[creator].details[campaignId].targetTime,
            "TTR"
        ); //Target Time Reached
        IERC20(campaignDetails[creator].details[campaignId].currencyToken)
            .transferFrom(
                msg.sender,
                campaignDetails[creator].details[campaignId].creator,
                donationAmount
            );
        campaignDetails[creator]
            .details[campaignId]
            .currentFundingAmount += donationAmount;
        donationDetails[msg.sender][campaignId] += donationAmount;
        if (
            campaignDetails[creator].details[campaignId].currentFundingAmount >=
            campaignDetails[creator].details[campaignId].targetAmount
        ) campaignDetails[creator].details[campaignId].completed = true;

        emit donated(campaignId, donationAmount);
    }

    function returnDonation(uint256 campaignId, address _creator) external {
        require(donationDetails[msg.sender][campaignId] > 0, "Invalid donor");
        require(
            block.timestamp <
                campaignDetails[_creator].details[campaignId].targetTime,
            "Campaign not completed"
        );
        require(
            !campaignDetails[_creator].details[campaignId].completed,
            "Campaign is completed"
        );

        uint256 donation = donationDetails[msg.sender][campaignId];

        campaignDetails[_creator]
            .details[campaignId]
            .currentFundingAmount -= donation;

        donationDetails[msg.sender][campaignId] = 0;

        IERC20(campaignDetails[_creator].details[campaignId].currencyToken)
            .transferFrom(_creator, msg.sender, donation);
    }

    function viewCampaignDetails(uint256 campaignId, address _creator)
        public
        view
        returns (campaign memory info)
    {
        info = campaignDetails[_creator].details[campaignId];
        return info;
    }
}
