// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/// @notice Minimal Relic NFT where only the configured minter can mint.
contract RelicNFT is ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint256 => string) public relicTier;
    address public immutable minter;

    constructor(address _minter) ERC721("LegacyRelic", "RELIC") {
        require(_minter != address(0), "minter=0");
        minter = _minter;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "Only minter");
        _;
    }

    function mintRelic(address to, string memory tier) external onlyMinter returns (uint256) {
        uint256 newId = _tokenIds.current();
        _safeMint(to, newId);
        relicTier[newId] = tier;
        _tokenIds.increment();
        return newId;
    }

    function getTier(uint256 tokenId) external view returns (string memory) {
        return relicTier[tokenId];
    }
}

contract Legacy6Coin is ERC20 {
    using Counters for Counters.Counter;

    uint256 public constant MAX_SUPPLY = 666000 * 10**18;
    uint256 public constant MIN_WITNESSES_FOR_ACTION = 6;

    // 👥 Witness Registry
    mapping(address => bool) public isWitness;
    mapping(address => string) public witnessNames; // embedded names
    address[] public witnessList;
    uint256 public witnessCount;

    // 🛡️ Staking
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakeTimestamp;
    mapping(address => bool) public hasRelic;
    mapping(address => bool) public canProphesy;

    // 📜 Prophecy Archive
    string[] public prophecies;
    mapping(uint256 => address) public prophecyAuthors;

    // 🪬 Relic NFT (deployed and owned by contract logic - coin is minter)
    RelicNFT public relicNFT;

    // 🗳️ Governance
    struct Proposal {
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        address proposer;
        uint256 witnessEndorsements;
    }
    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public voted;
    mapping(uint256 => mapping(address => bool)) public witnessEndorsed;

    event WitnessAdded(address indexed witness, string name);
    event WitnessRemoved(address indexed witness);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RelicMinted(address indexed user);
    event ProphecyUnlocked(address indexed user);
    event ProphecyDeclared(address indexed prophet, string message);
    event ProposalCreated(uint256 id, string description, address proposer);
    event Voted(address indexed voter, uint256 proposalId, bool support);
    event ProposalExecuted(uint256 id);
    event WitnessEndorsedProposal(address indexed witness, uint256 proposalId);

    constructor() ERC20("Legacy6Coin", "L6C") {
        // deploy the Relic NFT and make this contract the minter
        relicNFT = new RelicNFT(address(this));

        // mint supply to deployer
        _mint(msg.sender, MAX_SUPPLY);

        // initial witness
        _addWitness(msg.sender, "Genesis Witness");
        canProphesy[msg.sender] = true;
    }

    modifier onlyWitness() {
        require(isWitness[msg.sender], "Not a crowned witness");
        _;
    }

    modifier onlyProphets() {
        require(canProphesy[msg.sender], "Prophecy access not unlocked");
        _;
    }

    modifier requireWitnessConsensus() {
        require(witnessCount >= MIN_WITNESSES_FOR_ACTION, "Need minimum witnesses");
        _;
    }

    // --- Witness management ---
    function _addWitness(address witness, string memory name) internal {
        require(witness != address(0), "zero address");
        require(!isWitness[witness], "already witness");
        require(bytes(name).length > 0 && bytes(name).length <= 32, "invalid name");

        isWitness[witness] = true;
        witnessNames[witness] = name;
        witnessList.push(witness);
        witnessCount++;

        emit WitnessAdded(witness, name);
    }

    // Any witness can add another witness. This is a simple model — we can add endorsement logic later.
    function addWitness(address witness, string calldata name) external onlyWitness {
        _addWitness(witness, name);
    }

    // Removal must not reduce below the minimum; only witnesses can remove others.
    function removeWitness(address witness) external onlyWitness requireWitnessConsensus {
        require(isWitness[witness], "not witness");
        require(msg.sender != witness, "cannot remove self");
        require(witnessCount > MIN_WITNESSES_FOR_ACTION, "cannot go below minimum");

        isWitness[witness] = false;
        delete witnessNames[witness];
        witnessCount--;

        // remove from array
        for (uint i = 0; i < witnessList.length; i++) {
            if (witnessList[i] == witness) {
                witnessList[i] = witnessList[witnessList.length - 1];
                witnessList.pop();
                break;
            }
        }

        emit WitnessRemoved(witness);
    }

    // mint a fixed allotment to a new witness and register their name
    function mintToWitness(address to, string calldata witnessName) external onlyWitness requireWitnessConsensus {
        uint256 amount = 666 * 10**18; // example allotment
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
        _addWitness(to, witnessName);
    }

    // --- Relic mechanics ---
    function burnForRelic(uint256 amount) external {
        require(!hasRelic[msg.sender], "Already has relic");
        require(amount >= 1 * 10**18, "Minimum burn 1 L6C");
        _burn(msg.sender, amount);
        hasRelic[msg.sender] = true;
        relicNFT.mintRelic(msg.sender, "Seer");
        emit RelicMinted(msg.sender);
    }

    // override _transfer so both transfer and transferFrom are constrained
    function _transfer(address from, address to, uint256 amount) internal virtual override {
        if (to != address(this) && from != address(this)) {
            require(balanceOf(to) + amount <= MAX_SUPPLY / 15, "No wallet may hold more than 6.66%");
            require(amount <= 66 * 10**18, "Transfer exceeds 66 L6C limit");
        }
        super._transfer(from, to, amount);
    }

    // --- Staking ---
    function stake(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to stake");
        _transfer(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        stakeTimestamp[msg.sender] = block.timestamp;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");
        stakedBalance[msg.sender] -= amount;
        _transfer(address(this), msg.sender, amount);
        emit Unstaked(msg.sender, amount);

        uint256 stakedDuration = block.timestamp - stakeTimestamp[msg.sender];

        if (stakedDuration >= 30 days && !hasRelic[msg.sender]) {
            hasRelic[msg.sender] = true;
            relicNFT.mintRelic(msg.sender, "Watcher");
            emit RelicMinted(msg.sender);
        }

        if (stakedDuration >= 60 days && !canProphesy[msg.sender]) {
            canProphesy[msg.sender] = true;
            emit ProphecyUnlocked(msg.sender);
        }
    }

    function declareProphecy(string memory message) external onlyProphets {
        uint256 prophecyId = prophecies.length;
        prophecies.push(message);
        prophecyAuthors[prophecyId] = msg.sender;
        relicNFT.mintRelic(msg.sender, "Prophetic Seal");
        emit ProphecyDeclared(msg.sender, message);
    }

    // --- Governance ---
    function createProposal(string memory description) external onlyWitness {
        uint256 proposalId = proposals.length;
        proposals.push(Proposal({
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            executed: false,
            proposer: msg.sender,
            witnessEndorsements: 1
        }));
        witnessEndorsed[proposalId][msg.sender] = true;
        emit ProposalCreated(proposalId, description, msg.sender);
        emit WitnessEndorsedProposal(msg.sender, proposalId);
    }

    function endorseProposal(uint256 proposalId) external onlyWitness {
        require(!witnessEndorsed[proposalId][msg.sender], "Already endorsed");
        require(!proposals[proposalId].executed, "Already executed");

        proposals[proposalId].witnessEndorsements++;
        witnessEndorsed[proposalId][msg.sender] = true;
        emit WitnessEndorsedProposal(msg.sender, proposalId);
    }

    function vote(uint256 proposalId, bool support) external {
        require(!voted[proposalId][msg.sender], "Already voted");
        uint256 weight = balanceOf(msg.sender) + stakedBalance[msg.sender];
        require(weight > 0, "No voting power");

        if (support) {
            proposals[proposalId].votesFor += weight;
        } else {
            proposals[proposalId].votesAgainst += weight;
        }

        voted[proposalId][msg.sender] = true;
        emit Voted(msg.sender, proposalId, support);
    }

    function executeProposal(uint256 proposalId) external onlyWitness requireWitnessConsensus {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(p.witnessEndorsements >= MIN_WITNESSES_FOR_ACTION, "Need witness endorsements");
        require(p.votesFor > p.votesAgainst, "Not approved by vote");

        p.executed = true;
        emit ProposalExecuted(proposalId);
    }

    // --- Views ---
    function getProphecy(uint256 index) external view returns (string memory message, address author) {
        return (prophecies[index], prophecyAuthors[index]);
    }

    function getProposal(uint256 id) external view returns (
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        bool executed,
        address proposer,
        uint256 witnessEndorsements
    ) {
        Proposal storage p = proposals[id];
        return (p.description, p.votesFor, p.votesAgainst, p.executed, p.proposer, p.witnessEndorsements);
    }

    function getWitnessName(address witness) external view returns (string memory) {
        return witnessNames[witness];
    }

    function getWitnessList() external view returns (address[] memory) {
        return witnessList;
    }
}
