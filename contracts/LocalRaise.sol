// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title LocalRaise V2
/// @notice Micro-investment platform for local businesses on Base
/// @dev Includes default protection, reviews, updates, exit listings, milestones

contract LocalRaise {

    // ── Platform Config ───────────────────────────────
    address public platformOwner;
    address public treasury;
    uint256 public raiseFeePercent = 150;
    uint256 public repaymentFeePercent = 50;
    uint256 public minimumInvestment = 0.001 ether;
    uint256 public defaultPeriod = 60 days;
    uint256 public totalPlatformVolume;
    uint256 public totalCampaigns;
    uint256 public totalInvestors;
    uint256 public totalExitListings;

    // ── Enums ─────────────────────────────────────────
    enum Category { Food, Retail, Transport }
    enum ReturnModel { RevenueShare, FixedReturn }
    enum Status {
        Active,
        Funded,
        Repaying,
        Completed,
        Cancelled,
        Defaulted
    }

    // ── Structs ───────────────────────────────────────
    struct Campaign {
        uint256 id;
        address owner;
        string businessName;
        string description;
        string location;
        Category category;
        ReturnModel returnModel;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 fundingDeadline;
        uint256 repaymentMonths;
        uint256 returnPercent;
        uint256 totalRepaid;
        uint256 repaymentCount;
        Status status;
        uint256 createdAt;
        uint256 lastRepaymentTime;
        uint256 fundsReleased;
    }

    struct Investment {
        address investor;
        uint256 amount;
        uint256 sharePercent;
        uint256 totalEarned;
        uint256 timestamp;
    }

    struct RepaymentRecord {
        uint256 amount;
        uint256 timestamp;
        string note;
    }

    struct Review {
        address reviewer;
        uint8 rating;
        string comment;
        uint256 timestamp;
    }

    struct Update {
        string message;
        uint256 timestamp;
        uint256 currentRevenue;
    }

    struct Milestone {
        string description;
        uint256 fundPercent;
        bool completed;
        uint256 completedAt;
        uint256 fundsReleased;
    }

    struct ExitListing {
        address seller;
        uint256 campaignId;
        uint256 askPrice;
        bool active;
        uint256 listedAt;
    }

    struct BusinessProfile {
        uint256 totalRaised;
        uint256 totalRepaid;
        uint256 completedCampaigns;
        uint256 activeCampaigns;
        uint256 reputationScore;
        bool isVerified;
        bool isBlacklisted;
        uint256 totalReviews;
        uint256 totalRatingPoints;
    }

    // ── Storage ───────────────────────────────────────
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => Investment)) public investments;
    mapping(uint256 => address[]) public campaignInvestors;
    mapping(uint256 => RepaymentRecord[]) public repaymentHistory;
    mapping(uint256 => Review[]) public campaignReviews;
    mapping(uint256 => mapping(address => bool)) public hasReviewed;
    mapping(uint256 => Update[]) public campaignUpdates;
    mapping(uint256 => Milestone[]) public milestones;
    mapping(uint256 => ExitListing) public exitListings;
    mapping(address => BusinessProfile) public businessProfiles;
    mapping(address => uint256[]) public investorPortfolio;
    mapping(address => uint256[]) public businessCampaigns;
    mapping(address => bool) public isInvestor;

    // ── Events ────────────────────────────────────────
    event CampaignCreated(
        uint256 indexed id,
        address indexed owner,
        string businessName,
        uint256 goalAmount,
        Category category,
        ReturnModel returnModel
    );
    event InvestmentMade(
        uint256 indexed campaignId,
        address indexed investor,
        uint256 amount,
        uint256 sharePercent
    );
    event CampaignFunded(uint256 indexed id, uint256 totalRaised);
    event RevenueDistributed(
        uint256 indexed campaignId,
        uint256 totalAmount
    );
    event InstallmentRepaid(
        uint256 indexed campaignId,
        uint256 amount,
        uint256 repaymentCount
    );
    event CampaignCompleted(uint256 indexed id);
    event CampaignCancelled(uint256 indexed id);
    event CampaignDefaulted(uint256 indexed id, address indexed owner);
    event RefundIssued(
        uint256 indexed campaignId,
        address indexed investor,
        uint256 amount
    );
    event ReviewPosted(
        uint256 indexed campaignId,
        address indexed reviewer,
        uint8 rating
    );
    event UpdatePosted(
        uint256 indexed campaignId,
        string message,
        uint256 timestamp
    );
    event MilestoneAdded(
        uint256 indexed campaignId,
        uint256 milestoneIndex,
        string description
    );
    event MilestoneCompleted(
        uint256 indexed campaignId,
        uint256 milestoneIndex,
        uint256 fundsReleased
    );
    event ExitListed(
        uint256 indexed listingId,
        address indexed seller,
        uint256 campaignId,
        uint256 askPrice
    );
    event ExitCompleted(
        uint256 indexed listingId,
        address indexed seller,
        address indexed buyer
    );
    event ExitCancelled(uint256 indexed listingId);

    // ── Modifiers ─────────────────────────────────────
    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Not platform owner");
        _;
    }

    modifier onlyCampaignOwner(uint256 _id) {
        require(
            msg.sender == campaigns[_id].owner,
            "Not campaign owner"
        );
        _;
    }

    modifier campaignExists(uint256 _id) {
        require(_id < totalCampaigns, "Campaign does not exist");
        _;
    }

    modifier notBlacklisted() {
        require(
            !businessProfiles[msg.sender].isBlacklisted,
            "Address is blacklisted"
        );
        _;
    }

    // ── Constructor ───────────────────────────────────
    constructor(address _treasury) {
        platformOwner = msg.sender;
        treasury = _treasury;
    }

    // ─────────────────────────────────────────────────
    // CAMPAIGN MANAGEMENT
    // ─────────────────────────────────────────────────

    /// @notice Create a new funding campaign
    function createCampaign(
        string calldata _businessName,
        string calldata _description,
        string calldata _location,
        Category _category,
        ReturnModel _returnModel,
        uint256 _goalAmount,
        uint256 _fundingDeadlineDays,
        uint256 _repaymentMonths,
        uint256 _returnPercent
    ) external notBlacklisted {
        require(
            bytes(_businessName).length > 0,
            "Business name required"
        );
        require(
            bytes(_description).length > 0,
            "Description required"
        );
        require(
            bytes(_location).length > 0,
            "Location required"
        );
        require(_goalAmount > 0, "Goal must be greater than 0");
        require(
            _fundingDeadlineDays >= 7,
            "Min 7 days funding period"
        );
        require(
            _fundingDeadlineDays <= 90,
            "Max 90 days funding period"
        );
        require(
            _repaymentMonths >= 3,
            "Min 3 months repayment"
        );
        require(
            _repaymentMonths <= 36,
            "Max 36 months repayment"
        );
        require(_returnPercent >= 5, "Min 5 percent return");
        require(_returnPercent <= 200, "Max 200 percent return");

        uint256 deadline = block.timestamp +
            (_fundingDeadlineDays * 1 days);

        campaigns[totalCampaigns] = Campaign({
            id: totalCampaigns,
            owner: msg.sender,
            businessName: _businessName,
            description: _description,
            location: _location,
            category: _category,
            returnModel: _returnModel,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            fundingDeadline: deadline,
            repaymentMonths: _repaymentMonths,
            returnPercent: _returnPercent,
            totalRepaid: 0,
            repaymentCount: 0,
            status: Status.Active,
            createdAt: block.timestamp,
            lastRepaymentTime: 0,
            fundsReleased: 0
        });

        businessProfiles[msg.sender].activeCampaigns++;
        businessCampaigns[msg.sender].push(totalCampaigns);

        emit CampaignCreated(
            totalCampaigns,
            msg.sender,
            _businessName,
            _goalAmount,
            _category,
            _returnModel
        );

        totalCampaigns++;
    }

    /// @notice Cancel campaign before funded
    function cancelCampaign(
        uint256 _id
    ) external campaignExists(_id) onlyCampaignOwner(_id) {
        Campaign storage c = campaigns[_id];
        require(
            c.status == Status.Active,
            "Can only cancel active campaigns"
        );
        c.status = Status.Cancelled;
        businessProfiles[msg.sender].activeCampaigns--;
        _refundAllInvestors(_id);
        emit CampaignCancelled(_id);
    }

    // ─────────────────────────────────────────────────
    // MILESTONES
    // ─────────────────────────────────────────────────

    /// @notice Add a milestone to a campaign before it gets funded
    function addMilestone(
        uint256 _id,
        string calldata _description,
        uint256 _fundPercent
    ) external campaignExists(_id) onlyCampaignOwner(_id) {
        Campaign storage c = campaigns[_id];
        require(
            c.status == Status.Active,
            "Can only add milestones to active campaigns"
        );
        require(
            bytes(_description).length > 0,
            "Description required"
        );
        require(
            _fundPercent > 0 && _fundPercent <= 100,
            "Invalid fund percent"
        );
        require(
            _totalMilestonePercent(_id) + _fundPercent <= 100,
            "Total milestone percent exceeds 100"
        );

        milestones[_id].push(Milestone({
            description: _description,
            fundPercent: _fundPercent,
            completed: false,
            completedAt: 0,
            fundsReleased: 0
        }));

        emit MilestoneAdded(
            _id,
            milestones[_id].length - 1,
            _description
        );
    }

    /// @notice Complete a milestone and release funds to business
    function completeMilestone(
        uint256 _id,
        uint256 _milestoneIndex
    ) external campaignExists(_id) onlyCampaignOwner(_id) {
        Campaign storage c = campaigns[_id];
        require(
            c.status == Status.Funded ||
            c.status == Status.Repaying,
            "Campaign not funded"
        );
        require(
            _milestoneIndex < milestones[_id].length,
            "Milestone does not exist"
        );

        Milestone storage m = milestones[_id][_milestoneIndex];
        require(!m.completed, "Milestone already completed");

        // Check previous milestone is completed if not first
        if (_milestoneIndex > 0) {
            require(
                milestones[_id][_milestoneIndex - 1].completed,
                "Complete previous milestone first"
            );
        }

        m.completed = true;
        m.completedAt = block.timestamp;

        uint256 tranche = (c.raisedAmount * m.fundPercent) / 100;
        m.fundsReleased = tranche;
        c.fundsReleased += tranche;

        // Fee on tranche release
        uint256 fee = (tranche * raiseFeePercent) / 10000;
        uint256 payout = tranche - fee;
        payable(treasury).transfer(fee);
        payable(c.owner).transfer(payout);

        if (c.status == Status.Funded) {
            c.status = Status.Repaying;
            c.lastRepaymentTime = block.timestamp;
        }

        emit MilestoneCompleted(_id, _milestoneIndex, tranche);
    }

    // ─────────────────────────────────────────────────
    // INVESTMENT
    // ─────────────────────────────────────────────────

    /// @notice Invest ETH in a campaign
    function invest(
        uint256 _id
    ) external payable campaignExists(_id) {
        Campaign storage c = campaigns[_id];
        require(c.status == Status.Active, "Campaign not active");
        require(
            block.timestamp <= c.fundingDeadline,
            "Funding deadline passed"
        );
        require(
            msg.value >= minimumInvestment,
            "Below minimum investment"
        );
        require(
            c.raisedAmount + msg.value <= c.goalAmount,
            "Exceeds funding goal"
        );
        require(
            msg.sender != c.owner,
            "Owner cannot invest in own campaign"
        );

        if (investments[_id][msg.sender].amount == 0) {
            campaignInvestors[_id].push(msg.sender);
            if (!isInvestor[msg.sender]) {
                isInvestor[msg.sender] = true;
                totalInvestors++;
            }
            investorPortfolio[msg.sender].push(_id);
        }

        investments[_id][msg.sender].investor = msg.sender;
        investments[_id][msg.sender].amount += msg.value;
        investments[_id][msg.sender].timestamp = block.timestamp;

        c.raisedAmount += msg.value;
        _updateSharePercents(_id);

        if (c.raisedAmount >= c.goalAmount) {
            _fundCampaign(_id);
        }

        emit InvestmentMade(
            _id,
            msg.sender,
            msg.value,
            investments[_id][msg.sender].sharePercent
        );
    }

    /// @notice Internal — fund campaign when goal reached
    function _fundCampaign(uint256 _id) internal {
        Campaign storage c = campaigns[_id];
        c.status = Status.Funded;
        totalPlatformVolume += c.raisedAmount;
        businessProfiles[c.owner].totalRaised += c.raisedAmount;
        businessProfiles[c.owner].activeCampaigns--;

        // If no milestones release all funds immediately
        if (milestones[_id].length == 0) {
            uint256 fee = (c.raisedAmount * raiseFeePercent) / 10000;
            uint256 payout = c.raisedAmount - fee;
            payable(treasury).transfer(fee);
            payable(c.owner).transfer(payout);
            c.fundsReleased = c.raisedAmount;
            c.status = Status.Repaying;
            c.lastRepaymentTime = block.timestamp;
        }

        emit CampaignFunded(_id, c.raisedAmount);
    }

    /// @notice Update share percentages for all investors
    function _updateSharePercents(uint256 _id) internal {
        Campaign storage c = campaigns[_id];
        address[] memory investors = campaignInvestors[_id];
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 amount = investments[_id][investor].amount;
            investments[_id][investor].sharePercent =
                (amount * 10000) / c.goalAmount;
        }
    }

    // ─────────────────────────────────────────────────
    // REPAYMENT
    // ─────────────────────────────────────────────────

    /// @notice Distribute monthly revenue to investors
    function distributeRevenue(
        uint256 _id,
        string calldata _note
    ) external payable campaignExists(_id) onlyCampaignOwner(_id) {
        Campaign storage c = campaigns[_id];
        require(
            c.status == Status.Repaying,
            "Campaign not in repayment"
        );
        require(
            c.returnModel == ReturnModel.RevenueShare,
            "Not a revenue share campaign"
        );
        require(msg.value > 0, "Must send ETH");

        _processRepayment(_id, _note);

        uint256 targetReturn =
            (c.raisedAmount * c.returnPercent) / 100;
        if (c.totalRepaid >= targetReturn) {
            _completeCampaign(_id);
        }

        emit RevenueDistributed(_id, msg.value);
    }

    /// @notice Repay fixed monthly installment
    function repayInstallment(
        uint256 _id,
        string calldata _note
    ) external payable campaignExists(_id) onlyCampaignOwner(_id) {
        Campaign storage c = campaigns[_id];
        require(
            c.status == Status.Repaying,
            "Campaign not in repayment"
        );
        require(
            c.returnModel == ReturnModel.FixedReturn,
            "Not a fixed return campaign"
        );
        require(msg.value > 0, "Must send ETH");

        _processRepayment(_id, _note);

        uint256 totalOwed = c.raisedAmount +
            (c.raisedAmount * c.returnPercent) / 100;
        if (c.totalRepaid >= totalOwed) {
            _completeCampaign(_id);
        }

        emit InstallmentRepaid(_id, msg.value, c.repaymentCount);
    }

    /// @notice Internal repayment processing
    function _processRepayment(
        uint256 _id,
        string calldata _note
    ) internal {
        Campaign storage c = campaigns[_id];

        uint256 fee = (msg.value * repaymentFeePercent) / 10000;
        uint256 distributable = msg.value - fee;
        payable(treasury).transfer(fee);

        address[] memory investors = campaignInvestors[_id];
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 share = investments[_id][investor].sharePercent;
            if (share > 0) {
                uint256 payout = (distributable * share) / 10000;
                investments[_id][investor].totalEarned += payout;
                payable(investor).transfer(payout);
            }
        }

        c.totalRepaid += msg.value;
        c.repaymentCount++;
        c.lastRepaymentTime = block.timestamp;

        businessProfiles[c.owner].totalRepaid += msg.value;
        businessProfiles[c.owner].reputationScore += 10;

        repaymentHistory[_id].push(RepaymentRecord({
            amount: msg.value,
            timestamp: block.timestamp,
            note: _note
        }));
    }

    /// @notice Complete campaign
    function _completeCampaign(uint256 _id) internal {
        Campaign storage c = campaigns[_id];
        c.status = Status.Completed;
        businessProfiles[c.owner].completedCampaigns++;
        businessProfiles[c.owner].reputationScore += 100;
        emit CampaignCompleted(_id);
    }

    // ─────────────────────────────────────────────────
    // DEFAULT PROTECTION
    // ─────────────────────────────────────────────────

    /// @notice Mark campaign as defaulted if no payment for defaultPeriod
    function markAsDefaulted(
        uint256 _id
    ) external campaignExists(_id) {
        Campaign storage c = campaigns[_id];
        require(
            c.status == Status.Repaying,
            "Campaign not in repayment"
        );
        require(
            c.lastRepaymentTime > 0,
            "No repayment started yet"
        );
        require(
            block.timestamp > c.lastRepaymentTime + defaultPeriod,
            "Default period not passed yet"
        );

        c.status = Status.Defaulted;
        businessProfiles[c.owner].isBlacklisted = true;
        businessProfiles[c.owner].reputationScore = 0;

        emit CampaignDefaulted(_id, c.owner);
    }

    /// @notice Platform owner can remove blacklist after resolution
    function removeBlacklist(
        address _business
    ) external onlyPlatformOwner {
        businessProfiles[_business].isBlacklisted = false;
        businessProfiles[_business].reputationScore = 10;
    }

    // ─────────────────────────────────────────────────
    // REVIEWS
    // ─────────────────────────────────────────────────

    /// @notice Investor leaves a review after investing
    function leaveReview(
        uint256 _id,
        uint8 _rating,
        string calldata _comment
    ) external campaignExists(_id) {
        require(
            investments[_id][msg.sender].amount > 0,
            "Not an investor in this campaign"
        );
        require(
            !hasReviewed[_id][msg.sender],
            "Already reviewed this campaign"
        );
        require(
            _rating >= 1 && _rating <= 5,
            "Rating must be 1 to 5"
        );
        Campaign storage c = campaigns[_id];
        require(
            c.status == Status.Repaying ||
            c.status == Status.Completed,
            "Campaign not active enough to review"
        );

        campaignReviews[_id].push(Review({
            reviewer: msg.sender,
            rating: _rating,
            comment: _comment,
            timestamp: block.timestamp
        }));

        hasReviewed[_id][msg.sender] = true;

        BusinessProfile storage profile =
            businessProfiles[c.owner];
        profile.totalReviews++;
        profile.totalRatingPoints += _rating;
        profile.reputationScore += uint256(_rating) * 5;

        emit ReviewPosted(_id, msg.sender, _rating);
    }

    // ─────────────────────────────────────────────────
    // CAMPAIGN UPDATES
    // ─────────────────────────────────────────────────

    /// @notice Business posts an update for investors
    function postUpdate(
        uint256 _id,
        string calldata _message,
        uint256 _currentRevenue
    ) external campaignExists(_id) onlyCampaignOwner(_id) {
        Campaign storage c = campaigns[_id];
        require(
            c.status == Status.Funded ||
            c.status == Status.Repaying ||
            c.status == Status.Active,
            "Cannot post update"
        );
        require(
            bytes(_message).length > 0,
            "Message cannot be empty"
        );

        campaignUpdates[_id].push(Update({
            message: _message,
            timestamp: block.timestamp,
            currentRevenue: _currentRevenue
        }));

        businessProfiles[c.owner].reputationScore += 5;

        emit UpdatePosted(_id, _message, block.timestamp);
    }

    // ─────────────────────────────────────────────────
    // EARLY EXIT MARKETPLACE
    // ─────────────────────────────────────────────────

    /// @notice Investor lists their position for sale
    function listForExit(
        uint256 _campaignId,
        uint256 _askPrice
    ) external campaignExists(_campaignId) {
        require(
            investments[_campaignId][msg.sender].amount > 0,
            "Not an investor in this campaign"
        );
        require(_askPrice > 0, "Ask price must be greater than 0");
        require(
            campaigns[_campaignId].status == Status.Repaying,
            "Campaign not in repayment"
        );

        exitListings[totalExitListings] = ExitListing({
            seller: msg.sender,
            campaignId: _campaignId,
            askPrice: _askPrice,
            active: true,
            listedAt: block.timestamp
        });

        emit ExitListed(
            totalExitListings,
            msg.sender,
            _campaignId,
            _askPrice
        );

        totalExitListings++;
    }

    /// @notice Buy an investor exit listing
    function buyExit(
        uint256 _listingId
    ) external payable {
        require(
            _listingId < totalExitListings,
            "Listing does not exist"
        );
        ExitListing storage listing = exitListings[_listingId];
        require(listing.active, "Listing not active");
        require(
            msg.value >= listing.askPrice,
            "Insufficient payment"
        );
        require(
            msg.sender != listing.seller,
            "Cannot buy your own listing"
        );

        uint256 campaignId = listing.campaignId;
        Investment storage sellerInv =
            investments[campaignId][listing.seller];
        Investment storage buyerInv =
            investments[campaignId][msg.sender];

        // Transfer investment position to buyer
        if (buyerInv.amount == 0) {
            campaignInvestors[campaignId].push(msg.sender);
            investorPortfolio[msg.sender].push(campaignId);
            if (!isInvestor[msg.sender]) {
                isInvestor[msg.sender] = true;
                totalInvestors++;
            }
        }

        buyerInv.investor = msg.sender;
        buyerInv.amount += sellerInv.amount;
        buyerInv.sharePercent += sellerInv.sharePercent;
        buyerInv.timestamp = block.timestamp;

        // Clear seller position
        sellerInv.amount = 0;
        sellerInv.sharePercent = 0;

        listing.active = false;

        // Pay seller
        payable(listing.seller).transfer(listing.askPrice);

        // Refund excess if overpaid
        if (msg.value > listing.askPrice) {
            payable(msg.sender).transfer(
                msg.value - listing.askPrice
            );
        }

        emit ExitCompleted(_listingId, listing.seller, msg.sender);
    }

    /// @notice Seller cancels their exit listing
    function cancelExitListing(
        uint256 _listingId
    ) external {
        require(
            _listingId < totalExitListings,
            "Listing does not exist"
        );
        ExitListing storage listing = exitListings[_listingId];
        require(listing.active, "Listing not active");
        require(
            msg.sender == listing.seller,
            "Not the listing seller"
        );
        listing.active = false;
        emit ExitCancelled(_listingId);
    }

    // ─────────────────────────────────────────────────
    // REFUNDS
    // ─────────────────────────────────────────────────

    /// @notice Refund all investors
    function _refundAllInvestors(uint256 _id) internal {
        address[] memory investors = campaignInvestors[_id];
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 amount = investments[_id][investor].amount;
            if (amount > 0) {
                investments[_id][investor].amount = 0;
                payable(investor).transfer(amount);
                emit RefundIssued(_id, investor, amount);
            }
        }
    }

    /// @notice Anyone can trigger refund after deadline passes
    function refundExpiredCampaign(
        uint256 _id
    ) external campaignExists(_id) {
        Campaign storage c = campaigns[_id];
        require(c.status == Status.Active, "Campaign not active");
        require(
            block.timestamp > c.fundingDeadline,
            "Deadline not passed"
        );
        require(
            c.raisedAmount < c.goalAmount,
            "Goal was reached"
        );
        c.status = Status.Cancelled;
        _refundAllInvestors(_id);
        emit CampaignCancelled(_id);
    }

    // ─────────────────────────────────────────────────
    // PLATFORM OWNER
    // ─────────────────────────────────────────────────

    function updateRaiseFee(
        uint256 _newFee
    ) external onlyPlatformOwner {
        require(_newFee <= 500, "Max 5 percent fee");
        raiseFeePercent = _newFee;
    }

    function updateRepaymentFee(
        uint256 _newFee
    ) external onlyPlatformOwner {
        require(_newFee <= 200, "Max 2 percent fee");
        repaymentFeePercent = _newFee;
    }

    function updateTreasury(
        address _newTreasury
    ) external onlyPlatformOwner {
        require(_newTreasury != address(0), "Invalid address");
        treasury = _newTreasury;
    }

    function updateMinimumInvestment(
        uint256 _newMin
    ) external onlyPlatformOwner {
        minimumInvestment = _newMin;
    }

    function updateDefaultPeriod(
        uint256 _newPeriod
    ) external onlyPlatformOwner {
        require(_newPeriod >= 30 days, "Min 30 days");
        defaultPeriod = _newPeriod;
    }

    function verifyBusiness(
        address _business
    ) external onlyPlatformOwner {
        businessProfiles[_business].isVerified = true;
        businessProfiles[_business].reputationScore += 100;
    }

    function removeBlacklistBusiness(
        address _business
    ) external onlyPlatformOwner {
        businessProfiles[_business].isBlacklisted = false;
    }

    // ─────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────

    function getCampaign(
        uint256 _id
    ) external view campaignExists(_id) returns (Campaign memory) {
        return campaigns[_id];
    }

    function getAllCampaigns() external view returns (
        Campaign[] memory
    ) {
        Campaign[] memory all = new Campaign[](totalCampaigns);
        for (uint256 i = 0; i < totalCampaigns; i++) {
            all[i] = campaigns[i];
        }
        return all;
    }

    function getCampaignsByCategory(
        Category _category
    ) external view returns (Campaign[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < totalCampaigns; i++) {
            if (campaigns[i].category == _category) count++;
        }
        Campaign[] memory filtered = new Campaign[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < totalCampaigns; i++) {
            if (campaigns[i].category == _category) {
                filtered[idx] = campaigns[i];
                idx++;
            }
        }
        return filtered;
    }

    function getActiveCampaigns() external view returns (
        Campaign[] memory
    ) {
        uint256 count = 0;
        for (uint256 i = 0; i < totalCampaigns; i++) {
            if (campaigns[i].status == Status.Active) count++;
        }
        Campaign[] memory active = new Campaign[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < totalCampaigns; i++) {
            if (campaigns[i].status == Status.Active) {
                active[idx] = campaigns[i];
                idx++;
            }
        }
        return active;
    }

    function getInvestment(
        uint256 _id,
        address _investor
    ) external view returns (Investment memory) {
        return investments[_id][_investor];
    }

    function getCampaignInvestors(
        uint256 _id
    ) external view campaignExists(_id) returns (address[] memory) {
        return campaignInvestors[_id];
    }

    function getInvestorPortfolio(
        address _investor
    ) external view returns (uint256[] memory) {
        return investorPortfolio[_investor];
    }

    function getBusinessCampaigns(
        address _business
    ) external view returns (uint256[] memory) {
        return businessCampaigns[_business];
    }

    function getBusinessProfile(
        address _business
    ) external view returns (BusinessProfile memory) {
        return businessProfiles[_business];
    }

    function getBusinessAverageRating(
        address _business
    ) external view returns (uint256) {
        BusinessProfile storage p = businessProfiles[_business];
        if (p.totalReviews == 0) return 0;
        return p.totalRatingPoints / p.totalReviews;
    }

    function getRepaymentHistory(
        uint256 _id
    ) external view campaignExists(_id) returns (
        RepaymentRecord[] memory
    ) {
        return repaymentHistory[_id];
    }

    function getCampaignReviews(
        uint256 _id
    ) external view campaignExists(_id) returns (Review[] memory) {
        return campaignReviews[_id];
    }

    function getCampaignUpdates(
        uint256 _id
    ) external view campaignExists(_id) returns (Update[] memory) {
        return campaignUpdates[_id];
    }

    function getMilestones(
        uint256 _id
    ) external view campaignExists(_id) returns (
        Milestone[] memory
    ) {
        return milestones[_id];
    }

    function getActiveExitListings() external view returns (
        ExitListing[] memory
    ) {
        uint256 count = 0;
        for (uint256 i = 0; i < totalExitListings; i++) {
            if (exitListings[i].active) count++;
        }
        ExitListing[] memory active = new ExitListing[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < totalExitListings; i++) {
            if (exitListings[i].active) {
                active[idx] = exitListings[i];
                idx++;
            }
        }
        return active;
    }

    function getFundingProgress(
        uint256 _id
    ) external view campaignExists(_id) returns (uint256) {
        Campaign storage c = campaigns[_id];
        if (c.goalAmount == 0) return 0;
        return (c.raisedAmount * 100) / c.goalAmount;
    }

    function getRepaymentProgress(
        uint256 _id
    ) external view campaignExists(_id) returns (uint256) {
        Campaign storage c = campaigns[_id];
        uint256 targetReturn;
        if (c.returnModel == ReturnModel.RevenueShare) {
            targetReturn = (c.raisedAmount * c.returnPercent) / 100;
        } else {
            targetReturn = c.raisedAmount +
                (c.raisedAmount * c.returnPercent) / 100;
        }
        if (targetReturn == 0) return 0;
        return (c.totalRepaid * 100) / targetReturn;
    }

    function getMonthlyInstallment(
        uint256 _id
    ) external view campaignExists(_id) returns (uint256) {
        Campaign storage c = campaigns[_id];
        if (c.raisedAmount == 0) return 0;
        uint256 totalOwed;
        if (c.returnModel == ReturnModel.FixedReturn) {
            totalOwed = c.raisedAmount +
                (c.raisedAmount * c.returnPercent) / 100;
        } else {
            totalOwed =
                (c.raisedAmount * c.returnPercent) / 100;
        }
        return totalOwed / c.repaymentMonths;
    }

    function getPlatformStats() external view returns (
        uint256 campaigns_,
        uint256 volume_,
        uint256 investors_
    ) {
        return (
            totalCampaigns,
            totalPlatformVolume,
            totalInvestors
        );
    }

    function isExpired(
        uint256 _id
    ) external view campaignExists(_id) returns (bool) {
        return block.timestamp > campaigns[_id].fundingDeadline &&
               campaigns[_id].status == Status.Active;
    }

    function canBeDefaulted(
        uint256 _id
    ) external view campaignExists(_id) returns (bool) {
        Campaign storage c = campaigns[_id];
        if (c.status != Status.Repaying) return false;
        if (c.lastRepaymentTime == 0) return false;
        return block.timestamp > c.lastRepaymentTime + defaultPeriod;
    }

    // ── Internal Helpers ──────────────────────────────

    function _totalMilestonePercent(
        uint256 _id
    ) internal view returns (uint256 total) {
        for (uint256 i = 0; i < milestones[_id].length; i++) {
            total += milestones[_id][i].fundPercent;
        }
    }
}
