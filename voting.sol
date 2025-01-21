// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//install openzeppelin to import the packages
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTVoting is ReentrancyGuard {
    struct Proposal {
        string description;
        uint256 voteCount;
        address proposer;
        uint256 deadline;
        bool expired;
        bool depositClaimed;
    }

    Proposal[] public proposals;

    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => bool) public allowedNFTContracts;
    mapping(uint256 => bool) public expiredProposals;

    address public owner;
    uint256 public proposalDeposit;

    event ProposalCreated(
        uint256 indexed proposalId,
        string description,
        address indexed proposer,
        uint256 deadline
    );
    event Voted(uint256 indexed proposalId, address indexed voter);
    event ProposalExpired(uint256 indexed proposalId);
    event DepositRefunded(uint256 indexed proposalId, address indexed proposer);
    event NFTContractAdded(address indexed nftContract);
    event NFTContractRemoved(address indexed nftContract);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor(address[] memory _nftContracts, uint256 _proposalDeposit) {
        owner = msg.sender;
        proposalDeposit = _proposalDeposit;

        for (uint256 i = 0; i < _nftContracts.length; i++) {
            allowedNFTContracts[_nftContracts[i]] = true;
            emit NFTContractAdded(_nftContracts[i]);
        }
    }

    function createProposal(string memory _description, uint256 _votingDuration)
        external
        payable
    {
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_votingDuration > 0, "Voting duration must be greater than 0");
        require(msg.value == proposalDeposit, "Incorrect deposit amount");

        proposals.push(
            Proposal({
                description: _description,
                voteCount: 0,
                proposer: msg.sender,
                deadline: block.timestamp + _votingDuration,
                expired: false,
                depositClaimed: false
            })
        );

        emit ProposalCreated(
            proposals.length - 1,
            _description,
            msg.sender,
            block.timestamp + _votingDuration
        );
    }

    function vote(uint256 _proposalId) external {
        require(_proposalId < proposals.length, "Proposal does not exist");
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.expired, "Proposal has expired");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        require(
            block.timestamp <= proposal.deadline,
            "Voting period has ended"
        );

        require(
            isNFTOwner(msg.sender),
            "You do not own an NFT from allowed contracts"
        );

        hasVoted[_proposalId][msg.sender] = true;
        proposal.voteCount++;

        emit Voted(_proposalId, msg.sender);
    }

    function markExpiredProposals() public {
        uint256 length = proposals.length;
        for (uint256 i = 0; i < length; i++) {
            if (
                !proposals[i].expired && block.timestamp > proposals[i].deadline
            ) {
                proposals[i].expired = true;
                expiredProposals[i] = true;
                emit ProposalExpired(i);
            }
        }
    }

    function refundDeposit(uint256 _proposalId) external nonReentrant {
        require(_proposalId < proposals.length, "Proposal does not exist");
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.expired, "Proposal has not expired");
        require(!proposal.depositClaimed, "Deposit already refunded");
        require(
            proposal.proposer == msg.sender,
            "Only proposer can claim deposit"
        );

        proposal.depositClaimed = true;

        emit DepositRefunded(_proposalId, proposal.proposer);

        (bool success, ) = payable(proposal.proposer).call{
            value: proposalDeposit
        }("");
        require(success, "Transfer failed");
    }

    function addNFTContract(address _nftContract) external onlyOwner {
        require(
            !allowedNFTContracts[_nftContract],
            "NFT contract already allowed"
        );
        allowedNFTContracts[_nftContract] = true;
        emit NFTContractAdded(_nftContract);
    }

    function removeNFTContract(address _nftContract) external onlyOwner {
        require(allowedNFTContracts[_nftContract], "NFT contract not allowed");
        allowedNFTContracts[_nftContract] = false;
        emit NFTContractRemoved(_nftContract);
    }

    function isNFTOwner(address user) internal view returns (bool) {
        for (uint256 i = 0; i < proposals.length; i++) {
            if (
                allowedNFTContracts[address(proposals[i].proposer)] &&
                IERC721(address(proposals[i].proposer)).balanceOf(user) > 0
            ) {
                return true;
            }
        }
        return false;
    }

    function getProposalsCount() external view returns (uint256) {
        return proposals.length;
    }
}
