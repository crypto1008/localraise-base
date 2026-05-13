// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title LocalRaise
/// @notice Micro-investment platform for local businesses on Base
/// @dev Fund local businesses and earn real returns

contract LocalRaise {

    // ── Platform Config ───────────────────────────────
    address public platformOwner;
    address public treasury;
    uint256 public raiseFeePercent = 150;      // 1.5% on raise
    uint256 public repaymentFeePercent = 50;   // 0.5% on repayment
    uint256 public totalPlatformVolume;
    uint256 public totalCampaigns;
    uint256 public totalInvestors;

    // ── Enums ─────────────────────────────────────────
    enum Category { Food, Retail, Transport }
    enum ReturnModel { RevenueShare, FixedReturn }
    enum Status { Active, Funded, Repaying, Completed, Cancelled, Defaulted }

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

    struct BusinessProfile {
        uint256 totalRaised;
        uint256 totalRepaid;
        uint256 completedCampaigns;
        uint256 activeCampaigns;
        uint256 reputationScore;
        bool isVerified;
    }

    // ── Storage ───────────────────────────────────────
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => Investment)) public investments;
    mapping(uint256 => address[]) public campaignInvestors;
    mapping(uint256 => RepaymentRecord[]) public repaymentHistory;
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
    event CampaignFunded(
        uint256 indexed id,
        uint256 totalRaised
    );
    event RevenueDistributed(
        uint256 indexed campaignId,
        uint256 totalAmount,
        uint256 perInvestorShare
    );
    event InstallmentRepaid(
        uint256 indexed campaignId,
        uint256 amount,
        uint256 repaymentCount
    );
    event CampaignCompleted(uint256 indexed id);
    event CampaignCancelled(uint256 indexed id);
    event RefundIssued(
        uint256 indexed campaignId,
        address indexed investor,
        uint256 amount
    );

    // ── Modifiers ─────────────────────────────────────
    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Not platform owner");
        _;
    }

    modifier onlyCampaignOwner(uint256 _id) {
        require(msg.sender == campaigns[_id].owner, "Not campaign owner");
        _;
    }

    modifier campaignExists(uint256 _id) {
        require(_id < totalCampaigns, "Campaign does not exist");
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

    /// @notice Business creates a new funding campaign
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
    ) external {
        require(bytes(_businessName).length > 0, "Business name required");
        require(bytes(_description).length > 0, "Description required");
        require(bytes(_location).length > 0, "Location required");
        require(_goalAmount > 0, "Goal must be greater than 0");
        require(_fundingDeadlineDays >= 7, "Min 7 days funding period");
        require(_fundingDeadlineDays <= 90, "Max 90 days funding period");
        require(_repaymentMonths >= 3, "Min 3 months repayment");
        require(_repaymentMonths <= 36, "Max 36 months repayment");
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
            createdAt: block.timestamp
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

    /// @notice Cancel campaign before it gets funded
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

        // Refund all investors
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

        emit CampaignCancelled(_id);
    }

    // ─────────────────────────────────────────────────
    // INVESTMENT
    // ─────────────────────────────────────────────────

    /// @notice Invest in a campaign
    function invest(
        uint256 _id
    ) external payable campaignExists(_id) {
        Campaign storage c = campaigns[_id];
        require(c.status == Status.Active, "Campaign not active");
        require(
            block.timestamp <= c.fundingDeadline,
            "Funding deadline passed"
        );
        require(msg.value > 0, "Must invest ETH");
        require(
            c.raisedAmount + msg.value <= c.goalAmount,
            "Exceeds funding goal"
        );
        require(
            msg.sender != c.owner,
            "Owner cannot invest in own campaign"
        );

        // First time investor in this campaign
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

        // Recalculate share percentages for all investors
        _updateSharePercents(_id);

        // Check if goal reached
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

        // Calculate platform fee
        uint256 fee = (c.raisedAmount * raiseFeePercent) / 10000;
        uint256 payout = c.raisedAmount - fee;

        // Send fee to treasury
        payable(treasury).transfer(fee);

        // Send funds to business owner
        payable(c.owner).transfer(payout);

        // Update platform stats
        totalPlatformVolume += c.raisedAmount;
        businessProfiles[c.owner].totalRaised += c.raisedAmount;
        businessProfiles[c.owner].activeCampaigns--;

        // Move to repaying status
        c.status = Status.Repaying;

        emit CampaignFunded(_id, c.raisedAmount);
    }

    /// @notice Update share percentages after each investment
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
    // REPAYMENT — REVENUE SHARE MODEL
    // ─────────────────────────────────────────────────

    /// @notice Business distributes monthly revenue to investors
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
        require(msg.value > 0, "Must send ETH to distribute");

        // Platform fee on repayment
        uint256 fee = (msg.value * repaymentFeePercent) / 10000;
        uint256 distributable = msg.value - fee;
        payable(treasury).transfer(fee);

        // Distribute to investors proportionally
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

        repaymentHistory[_id].push(RepaymentRecord({
            amount: msg.value,
            timestamp: block.timestamp,
            note: _note
        }));

        businessProfiles[c.owner].totalRepaid += msg.value;
        businessProfiles[c.owner].reputationScore += 10;

        // Check if target return reached
        uint256 targetReturn = (c.raisedAmount * c.returnPercent) / 100;
        if (c.totalRepaid >= targetReturn) {
            _completeCampaign(_id);
        }

        emit RevenueDistributed(_id, msg.value, distributable);
    }

    // ─────────────────────────────────────────────────
    // REPAYMENT — FIXED RETURN MODEL
    // ─────────────────────────────────────────────────

    /// @notice Business pays monthly installment to investors
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

        // Platform fee
        uint256 fee = (msg.value * repaymentFeePercent) / 10000;
        uint256 distributable = msg.value - fee;
        payable(treasury).transfer(fee);

        // Distribute to investors
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

        repaymentHistory[_id].push(RepaymentRecord({
            amount: msg.value,
            timestamp: block.timestamp,
            note: _note
        }));

        businessProfiles[c.owner].totalRepaid += msg.value;
        businessProfiles[c.owner].reputationScore += 10;

        // Fixed return: repay principal + returnPercent
        uint256 totalOwed = c.raisedAmount +
            (c.raisedAmount * c.returnPercent) / 100;
        if (c.totalRepaid >= totalOwed) {
            _completeCampaign(_id);
        }

        emit InstallmentRepaid(_id, msg.value, c.repaymentCount);
    }

    /// @notice Mark campaign as completed
    function _completeCampaign(uint256 _id) internal {
        Campaign storage c = campaigns[_id];
        c.status = Status.Completed;
        businessProfiles[c.owner].completedCampaigns++;
        businessProfiles[c.owner].reputationScore += 50;
        emit CampaignCompleted(_id);
    }

    // ─────────────────────────────────────────────────
    // REFUND — EXPIRED CAMPAIGNS
    // ─────────────────────────────────────────────────

    /// @notice Refund investors if funding deadline passed
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

        emit CampaignCancelled(_id);
    }

    // ─────────────────────────────────────────────────
    // PLATFORM OWNER FUNCTIONS
    // ─────────────────────────────────────────────────

    /// @notice Update platform fee
    function updateRaiseFee(
        uint256 _newFee
    ) external onlyPlatformOwner {
        require(_newFee <= 500, "Max 5 percent fee");
        raiseFeePercent = _newFee;
    }

    /// @notice Update repayment fee
    function updateRepaymentFee(
        uint256 _newFee
    ) external onlyPlatformOwner {
        require(_newFee <= 200, "Max 2 percent fee");
        repaymentFeePercent = _newFee;
    }

    /// @notice Update treasury wallet
    function updateTreasury(
        address _newTreasury
    ) external onlyPlatformOwner {
        require(_newTreasury != address(0), "Invalid address");
        treasury = _newTreasury;
    }

    /// @notice Verify a business
    function verifyBusiness(
        address _business
    ) external onlyPlatformOwner {
        businessProfiles[_business].isVerified = true;
        businessProfiles[_business].reputationScore += 100;
    }

    // ─────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────

    function getCampaign(
        uint256 _id
    ) external view campaignExists(_id) returns (Campaign memory) {
        return campaigns[_id];
    }

    function getAllCampaigns() external view returns (Campaign[] memory) {
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

    function getActiveCampaigns() external view returns (Campaign[] memory) {
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

    function getRepaymentHistory(
        uint256 _id
    ) external view campaignExists(_id) returns (RepaymentRecord[] memory) {
        return repaymentHistory[_id];
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
        uint256 totalOwed;
        if (c.returnModel == ReturnModel.FixedReturn) {
            totalOwed = c.raisedAmount +
                (c.raisedAmount * c.returnPercent) / 100;
        } else {
            totalOwed = (c.raisedAmount * c.returnPercent) / 100;
        }
        return totalOwed / c.repaymentMonths;
    }

    function getPlatformStats() external view returns (
        uint256 campaigns_,
        uint256 volume_,
        uint256 investors_
    ) {
        return (totalCampaigns, totalPlatformVolume, totalInvestors);
    }

    function isExpired(
        uint256 _id
    ) external view campaignExists(_id) returns (bool) {
        return block.timestamp > campaigns[_id].fundingDeadline &&
               campaigns[_id].status == Status.Active;
    }
}
