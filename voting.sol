// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//Install open zeppelin to import the packages
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTVoting {
    // Struct to represent a proposal
    struct Proposal {
        string description; // Proposal description
        uint256 voteCount;  // Total votes received
        address proposer;   // Address of the proposer
        uint256 deadline;   // Voting deadline (timestamp)
    }

    // Array to store all proposals
    Proposal[] public proposals;

    // Mapping to track if an address has voted on a specific proposal
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // Array of NFT contracts allowed for voting
    IERC721[] public nftContracts;

    // Owner of the contract (for administrative purposes)
    address public owner;

    // Events for proposal creation and voting
    event ProposalCreated(
        uint256 indexed proposalId,
        string description,
        address indexed proposer,
        uint256 deadline
    );
    event Voted(
        uint256 indexed proposalId,
        address indexed voter
    );

    // Modifier to restrict access to only the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Constructor to initialize the owner
    constructor(address[] memory _nftContracts) {
        for (uint256 i = 0; i < _nftContracts.length; i++) {
            nftContracts.push(IERC721(_nftContracts[i]));
        }
        owner = msg.sender;
    }

    // Function to create a new proposal
    function createProposal(string memory _description, uint256 _votingDuration) external {
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_votingDuration > 0, "Voting duration must be greater than 0");

        proposals.push(Proposal({
            description: _description,
            voteCount: 0,
            proposer: msg.sender,
            deadline: block.timestamp + _votingDuration
        }));

        emit ProposalCreated(proposals.length - 1, _description, msg.sender, block.timestamp + _votingDuration);
    }

    // Function to vote on a proposal
    function vote(uint256 _proposalId) external {
        require(_proposalId < proposals.length, "Proposal does not exist");
        require(!hasVoted[_proposalId][msg.sender], "You have already voted on this proposal");
        require(block.timestamp <= proposals[_proposalId].deadline, "Voting period has ended");

        // Check if the caller owns any NFT from the allowed NFT contracts
        bool isNFTOwner = false;
        for (uint256 i = 0; i < nftContracts.length; i++) {
            if (nftContracts[i].balanceOf(msg.sender) > 0) {
                isNFTOwner = true;
                break;
            }
        }
        require(isNFTOwner, "You do not own any NFT from the allowed collections");

        // Mark the user as having voted
        hasVoted[_proposalId][msg.sender] = true;

        // Increment the vote count for the proposal
        proposals[_proposalId].voteCount++;

        emit Voted(_proposalId, msg.sender);
    }

    // Function to get the total number of proposals
    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

    // Function to get the details of a specific proposal
    function getProposal(uint256 _proposalId) external view returns (string memory, uint256, address, uint256) {
        require(_proposalId < proposals.length, "Proposal does not exist");

        Proposal memory proposal = proposals[_proposalId];
        return (proposal.description, proposal.voteCount, proposal.proposer, proposal.deadline);
    }

    // Function to determine the winning proposal
    function getWinningProposal() external view returns (uint256, string memory) {
        uint256 winningVoteCount = 0;
        uint256 winningProposalId;

        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                winningProposalId = i;
            }
        }

        return (winningProposalId, proposals[winningProposalId].description);
    }

    // Function to add a new NFT contract to the allowed list (only owner)
    function addNFTContract(address _nftContract) external onlyOwner {
        require(_nftContract != address(0), "Invalid contract address");
        nftContracts.push(IERC721(_nftContract));
    }

    // Function to remove an NFT contract from the allowed list (only owner)
    function removeNFTContract(uint256 _index) external onlyOwner {
        require(_index < nftContracts.length, "Index out of range");

        // Remove the NFT contract by swapping it with the last and popping
        nftContracts[_index] = nftContracts[nftContracts.length - 1];
        nftContracts.pop();
    }

    // Function to transfer ownership
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be the zero address");
        owner = _newOwner;
    }
}
