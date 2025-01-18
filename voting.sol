// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//install openzeppelin to import the packages
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTVoting {
    // Struct to represent a proposal
    struct Proposal {
        string description; // Proposal description
        uint256 voteCount;  // Total votes received
        address proposer;   // Address of the proposer
        uint256 deadline;   // Voting deadline (timestamp)
        bool expired;       // Whether the proposal is expired
        bool depositClaimed; // Whether the proposer has claimed the deposit
    }

    // Array to store all proposals
    Proposal[] public proposals;

    // Mapping to track if an address has voted on a specific proposal
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // Mapping of allowed NFT contracts for efficient lookup
    mapping(address => bool) public allowedNFTContracts;

    // Array of NFT contract addresses for iteration
    address[] public nftContractList;

    // Owner of the contract
    address public owner;

    // Proposal creation deposit amount
    uint256 public proposalDeposit;

    // Events
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

    // Modifier to restrict access to only the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Constructor to initialize allowed NFT contracts, set the contract owner, and set the proposal deposit amount
    constructor(address[] memory _nftContracts, uint256 _proposalDeposit) {
        owner = msg.sender;
        proposalDeposit = _proposalDeposit;

        for (uint256 i = 0; i < _nftContracts.length; i++) {
            _addNFTContract(_nftContracts[i]);
        }
    }

    // Function to create a new proposal with a deposit
    function createProposal(string memory _description, uint256 _votingDuration) external payable {
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_votingDuration > 0, "Voting duration must be greater than 0");
        require(msg.value == proposalDeposit, "Incorrect deposit amount");

        proposals.push(Proposal({
            description: _description,
            voteCount: 0,
            proposer: msg.sender,
            deadline: block.timestamp + _votingDuration,
            expired: false,
            depositClaimed: false
        }));

        emit ProposalCreated(proposals.length - 1, _description, msg.sender, block.timestamp + _votingDuration);
    }

    // Function to vote on a proposal
    function vote(uint256 _proposalId) external {
        require(_proposalId < proposals.length, "Proposal does not exist");
        require(!proposals[_proposalId].expired, "Proposal has expired");
        require(!hasVoted[_proposalId][msg.sender], "You have already voted on this proposal");
        require(block.timestamp <= proposals[_proposalId].deadline, "Voting period has ended");

        // Check if the voter owns an NFT from any allowed NFT contract
        bool isNFTOwner = false;
        for (uint256 i = 0; i < nftContractList.length; i++) {
            if (IERC721(nftContractList[i]).balanceOf(msg.sender) > 0) {
                isNFTOwner = true;
                break;
            }
        }
        require(isNFTOwner, "You do not own an NFT from allowed contracts");

        // Mark as voted and increment the vote count
        hasVoted[_proposalId][msg.sender] = true;
        proposals[_proposalId].voteCount++;

        emit Voted(_proposalId, msg.sender);
    }

    // Function to mark proposals as expired
    function markExpiredProposals() public {
        for (uint256 i = 0; i < proposals.length; i++) {
            if (!proposals[i].expired && block.timestamp > proposals[i].deadline) {
                proposals[i].expired = true;
                emit ProposalExpired(i);
            }
        }
    }

    // Function to refund deposit to the proposer after the proposal expires
    function refundDeposit(uint256 _proposalId) external {
        require(_proposalId < proposals.length, "Proposal does not exist");
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.expired, "Proposal has not expired");
        require(!proposal.depositClaimed, "Deposit already refunded");
        require(proposal.proposer == msg.sender, "Only the proposer can claim the deposit");

        proposal.depositClaimed = true;
        payable(proposal.proposer).transfer(proposalDeposit);

        emit DepositRefunded(_proposalId, proposal.proposer);
    }

    // Internal function to add an NFT contract (used by owner functions)
    function _addNFTContract(address _nftContract) internal {
        require(!allowedNFTContracts[_nftContract], "NFT contract already allowed");
        allowedNFTContracts[_nftContract] = true;
        nftContractList.push(_nftContract);
        emit NFTContractAdded(_nftContract);
    }

    // Function to add an NFT contract to the allowed list
    function addNFTContract(address _nftContract) external onlyOwner {
        _addNFTContract(_nftContract);
    }

    // Function to remove an NFT contract from the allowed list
    function removeNFTContract(address _nftContract) external onlyOwner {
        require(allowedNFTContracts[_nftContract], "NFT contract not allowed");
        allowedNFTContracts[_nftContract] = false;

        // Remove from the array
        for (uint256 i = 0; i < nftContractList.length; i++) {
            if (nftContractList[i] == _nftContract) {
                nftContractList[i] = nftContractList[nftContractList.length - 1];
                nftContractList.pop();
                break;
            }
        }
        emit NFTContractRemoved(_nftContract);
    }

    // Function to get the total number of proposals
    function getProposalsCount() external view returns (uint256) {
        return proposals.length;
    }
}
