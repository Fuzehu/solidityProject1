// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/*
* @author Foti Nicolas
* @notice -> Given here -> https://formation.alyra.fr/products/developpeur-blockchain/categories/2149052575/posts/2153025072
* 
*/
contract Voting is Ownable {

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    uint public winningProposalId; 

    enum WorkflowStatus { 
        RegisteringVoters, 
        ProposalsRegistrationStarted, 
        ProposalsRegistrationEnded, 
        VotingSessionStarted, 
        VotingSessionEnded, 
        VotesTallied 
    }
    WorkflowStatus public currentStatus; 

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus); 
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    mapping (address => Voter) public voters; 

    Proposal[] public proposals;

    //////////////////////     
    // MODIFIERS /////////     
    //////////////////////

    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered == true, "Voter not registered"); 
        _;
    }

    modifier onlyDuringProposalRegistration() {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Not in the proposals registration phase"); 
        _;
    }

    modifier onlyDuringVotingSession() {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Not in the voting session phase"); 
        _;
    }

    modifier onlyAfterVotingSession() {
        require(currentStatus == WorkflowStatus.VotingSessionEnded, "Voting session is still active or has not started yet");
        _;
    }

    modifier onlyAfterVotesTallied() {
        require(currentStatus == WorkflowStatus.VotesTallied, "Votes have not been tallied yet");
        _;
    }

    //////////////////////     
    // FUNCTIONS /////////     
    //////////////////////

    /*
    * @dev Switch current workflow status from RegisteringVoters to ProposalsRegistrationStarted
    */
    function startProposalsRegistration() external onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Can't start proposals registration at this stage");
        currentStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted); 
    }

    /*
    * @dev Switch current workflow status from ProposalsRegistrationStarted to ProposalsRegistrationEnded
    */
    function endProposalsRegistration() external onlyOwner {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Can't end proposals registration at this stage");
        currentStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded); 
    }

    /*
    * @dev Switch current workflow status from ProposalsRegistrationEnded to VotingSessionStarted
    */
    function startVotingSession() external onlyOwner {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "Can't start voting session at this stage");
        currentStatus = WorkflowStatus.VotingSessionStarted; 
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted); 
    }

    /*
    * @dev Switch current workflow status from VotingSessionStarted to VotingSessionEnded
    */
    function endVotingSession() external onlyOwner {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Can't end voting session at this stage");
        currentStatus = WorkflowStatus.VotingSessionEnded; 
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded); 
    }


    /*
    * @dev Add voter to whitelist from his address 
    * @param _address User's address 
    */
    function Whitelist (address _address) external onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Too late, registering session ended");  
        require(!voters[_address].isRegistered, "You are already registered."); 
        voters[_address].isRegistered = true; 
        emit VoterRegistered(_address); 
    }

    /*
    * @dev Check if proposal already exists
    *      Revert if proposal already exists 
    *      Add a new available proposal for the voting session
    * @param _description Description of a proposal
    */
    function submitProposal(string memory _description) external onlyDuringProposalRegistration onlyRegisteredVoter {
        for (uint i = 0; i < proposals.length; i++) {
        if (keccak256(abi.encodePacked(proposals[i].description)) == keccak256(abi.encodePacked(_description))) {
            revert("Proposal already exists"); 
        }
    }
        proposals.push(Proposal(_description, 0)); 
        emit ProposalRegistered(proposals.length - 1); 
    }

    /*
    * @dev Register voter's voting proposal      
    * @param _label Voting choice label
    */
    function vote(string memory _label) external onlyDuringVotingSession onlyRegisteredVoter { 
        require(!voters[msg.sender].hasVoted, "Sender has already voted"); 
        uint _proposalId = getProposalIdByDescription(_label);
        require(_proposalId < proposals.length, "Invalid proposal"); 
        
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;

        proposals[_proposalId].voteCount++;

        emit Voted(msg.sender, _proposalId);
    }

    /*
    * @dev Tally votes
    *      Store winning proposal 
    *      Switch current workflow status to VotesTallied
    */
    function tallyVotes() external onlyOwner onlyAfterVotingSession {
        require(proposals.length > 0, "No proposals registered"); 
        uint highestVoteCount = 0;
        uint winningProposalIndex; 

        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > highestVoteCount) { 
                highestVoteCount = proposals[i].voteCount;  
                winningProposalIndex = i;
            }
        }

        winningProposalId = winningProposalIndex; 
        currentStatus = WorkflowStatus.VotesTallied; 

        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

    //////////////////////     
    // GETTERS ///////////    
    //////////////////////

    /*
    * @dev Return the entire eligible proposals' list to the voting session 
    * @return Return the proposal's list
    */
    function getProposalsList() public view returns (string[] memory) {
        require(currentStatus >= WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration has not started");
        require(proposals.length != 0, "No proposal registered yet.");

        string[] memory proposalDescriptions = new string[](proposals.length);
        for (uint i = 0; i < proposals.length; i++) {
            proposalDescriptions[i] = proposals[i].description;
        }

        return proposalDescriptions;
    }

    /*
    * @dev Return the winning proposal after the votes are tallied
    * @return Return the winning proposal (w/ description)
    */
    function getWinner() public view onlyAfterVotesTallied returns (Proposal memory) {
        if (winningProposalId < proposals.length) { 
            return proposals[winningProposalId]; 
        } else {
            revert("No winning proposal");
        }
    }

    /*
    * @dev Return proposal's ID from the specific description 
    *      Revert if not found
    * @param _description Description of a proposal
    * @return Return the proposal ID
    */
    function getProposalIdByDescription(string memory _description) public view returns (uint) {
        for (uint i = 0; i < proposals.length; i++) {
            if (keccak256(abi.encodePacked(proposals[i].description)) == keccak256(abi.encodePacked(_description))) {
                return i; 
            }
        }
        revert("Proposal not found"); 
    }

    /**
     * @dev Retrieves information about a proposal.
     * @param proposalId ID of the proposal.
     * @return Return the description of the proposal.
     * @return Return the number of votes received by the proposal.
     */
    function getProposal(uint proposalId) public view onlyRegisteredVoter returns (string memory, uint) {
        require(proposalId < proposals.length, "Invalid proposal ID");
        Proposal memory proposal = proposals[proposalId];
        return (proposal.description, proposal.voteCount);
    }

    /*
    * @dev Return the votes of a specific voter
    * @param _voterAddress The address of the voter
    * @return Return the votes of the voter
    */
    function getVoterVotes(address _voterAddress) public view onlyRegisteredVoter returns (string[] memory) {
        require(voters[_voterAddress].isRegistered, "Voter not registered");

        uint count = 0;
        for (uint i = 0; i < proposals.length; i++) {
            if (voters[_voterAddress].votedProposalId == i) {
                count++;
            }
        }

        string[] memory voterVotes = new string[](count);
        count = 0;

        for (uint i = 0; i < proposals.length; i++) {
            if (voters[_voterAddress].votedProposalId == i) {
                voterVotes[count] = proposals[i].description;
                count++;
            }
        }

        return voterVotes;
    }


}
