const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("LocalRaise V2", function () {
  let localraise, owner, treasury, business, alice, bob, charlie;
  const GOAL = ethers.parseEther("1.0");
  const DAYS_30 = 30;
  const MONTHS_12 = 12;
  const RETURN_20 = 20;
  const MIN_INVEST = ethers.parseEther("0.001");

  beforeEach(async () => {
    [owner, treasury, business, alice, bob, charlie] =
      await ethers.getSigners();
    const LocalRaise = await ethers.getContractFactory("LocalRaise");
    localraise = await LocalRaise.deploy(treasury.address);
  });

  // ── Campaign Creation ────────────────────────────

  it("Business can create a revenue share campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Ramesh Chai Shop", "Expanding", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const c = await localraise.getCampaign(0);
    expect(c.businessName).to.equal("Ramesh Chai Shop");
  });

  it("Business can create a fixed return campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Kirana Store", "Festival stock", "Mumbai",
      1, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const c = await localraise.getCampaign(0);
    expect(c.returnModel).to.equal(1);
  });

  it("Cannot create campaign with empty name", async () => {
    await expect(
      localraise.connect(business).createCampaign(
        "", "desc", "loc",
        0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
      )
    ).to.be.revertedWith("Business name required");
  });

  it("Cannot create campaign below 7 days deadline", async () => {
    await expect(
      localraise.connect(business).createCampaign(
        "Test", "desc", "loc",
        0, 0, GOAL, 3, MONTHS_12, RETURN_20
      )
    ).to.be.revertedWith("Min 7 days funding period");
  });

  it("Cannot create campaign above 36 months repayment", async () => {
    await expect(
      localraise.connect(business).createCampaign(
        "Test", "desc", "loc",
        0, 0, GOAL, DAYS_30, 40, RETURN_20
      )
    ).to.be.revertedWith("Max 36 months repayment");
  });

  it("Blacklisted address cannot create campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, 7, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, {
      value: GOAL
    });
    await time.increase(61 * 24 * 60 * 60);
    await localraise.markAsDefaulted(0);
    await expect(
      localraise.connect(business).createCampaign(
        "New Shop", "desc", "loc",
        0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
      )
    ).to.be.revertedWith("Address is blacklisted");
  });

  // ── Milestones ───────────────────────────────────

  it("Owner can add milestones to active campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(business).addMilestone(
      0, "Buy equipment", 50
    );
    await localraise.connect(business).addMilestone(
      0, "Hire staff", 50
    );
    const ms = await localraise.getMilestones(0);
    expect(ms.length).to.equal(2);
  });

  it("Total milestone percent cannot exceed 100", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(business).addMilestone(
      0, "First", 60
    );
    await expect(
      localraise.connect(business).addMilestone(0, "Second", 50)
    ).to.be.revertedWith("Total milestone percent exceeds 100");
  });

  it("Milestone releases funds to business when completed", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(business).addMilestone(
      0, "Buy equipment", 100
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    const before = await ethers.provider.getBalance(business.address);
    await localraise.connect(business).completeMilestone(0, 0);
    const after = await ethers.provider.getBalance(business.address);
    expect(after).to.be.gt(before);
  });

  it("Must complete previous milestone before next", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(business).addMilestone(
      0, "First", 50
    );
    await localraise.connect(business).addMilestone(
      0, "Second", 50
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await expect(
      localraise.connect(business).completeMilestone(0, 1)
    ).to.be.revertedWith("Complete previous milestone first");
  });

  // ── Investment ───────────────────────────────────

  it("Investor can invest above minimum", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    const inv = await localraise.getInvestment(0, alice.address);
    expect(inv.amount).to.equal(GOAL);
  });

  it("Cannot invest below minimum investment", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await expect(
      localraise.connect(alice).invest(0, {
        value: ethers.parseEther("0.0001")
      })
    ).to.be.revertedWith("Below minimum investment");
  });

  it("Owner cannot invest in own campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await expect(
      localraise.connect(business).invest(0, { value: GOAL })
    ).to.be.revertedWith("Owner cannot invest in own campaign");
  });

  it("Share percent is correct for investor", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, {
      value: ethers.parseEther("0.5")
    });
    const inv = await localraise.getInvestment(0, alice.address);
    expect(inv.sharePercent).to.equal(5000);
  });

  it("Platform fee sent to treasury on funding", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const before = await ethers.provider.getBalance(treasury.address);
    await localraise.connect(alice).invest(0, { value: GOAL });
    const after = await ethers.provider.getBalance(treasury.address);
    expect(after).to.be.gt(before);
  });

  // ── Default Protection ───────────────────────────

  it("Campaign can be marked defaulted after default period", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, 7, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await time.increase(61 * 24 * 60 * 60);
    await localraise.markAsDefaulted(0);
    const c = await localraise.getCampaign(0);
    expect(c.status).to.equal(5);
  });

  it("Business is blacklisted after default", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, 7, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await time.increase(61 * 24 * 60 * 60);
    await localraise.markAsDefaulted(0);
    const profile = await localraise.getBusinessProfile(
      business.address
    );
    expect(profile.isBlacklisted).to.equal(true);
  });

  it("Cannot mark defaulted before default period", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await expect(
      localraise.markAsDefaulted(0)
    ).to.be.revertedWith("Default period not passed yet");
  });

  it("Reputation score resets to zero on default", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, 7, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(business).distributeRevenue(
      0, "Month 1", { value: ethers.parseEther("0.1") }
    );
    await time.increase(61 * 24 * 60 * 60);
    await localraise.markAsDefaulted(0);
    const profile = await localraise.getBusinessProfile(
      business.address
    );
    expect(profile.reputationScore).to.equal(0);
  });

  it("Platform owner can remove blacklist", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, 7, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await time.increase(61 * 24 * 60 * 60);
    await localraise.markAsDefaulted(0);
    await localraise.removeBlacklist(business.address);
    const profile = await localraise.getBusinessProfile(
      business.address
    );
    expect(profile.isBlacklisted).to.equal(false);
  });

  it("canBeDefaulted returns true after period", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, 7, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await time.increase(61 * 24 * 60 * 60);
    expect(await localraise.canBeDefaulted(0)).to.equal(true);
  });

  // ── Reviews ──────────────────────────────────────

  it("Investor can leave a review after funding", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(business).distributeRevenue(
      0, "Month 1", { value: ethers.parseEther("0.1") }
    );
    await localraise.connect(alice).leaveReview(
      0, 5, "Great business, paid on time!"
    );
    const reviews = await localraise.getCampaignReviews(0);
    expect(reviews.length).to.equal(1);
    expect(reviews[0].rating).to.equal(5);
  });

  it("Non investor cannot leave a review", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(business).distributeRevenue(
      0, "Month 1", { value: ethers.parseEther("0.1") }
    );
    await expect(
      localraise.connect(bob).leaveReview(0, 5, "Great!")
    ).to.be.revertedWith("Not an investor in this campaign");
  });

  it("Cannot leave review twice", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(business).distributeRevenue(
      0, "Month 1", { value: ethers.parseEther("0.1") }
    );
    await localraise.connect(alice).leaveReview(0, 5, "Great!");
    await expect(
      localraise.connect(alice).leaveReview(0, 4, "Again")
    ).to.be.revertedWith("Already reviewed this campaign");
  });

  it("Rating must be between 1 and 5", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(business).distributeRevenue(
      0, "Month 1", { value: ethers.parseEther("0.1") }
    );
    await expect(
      localraise.connect(alice).leaveReview(0, 6, "Bad rating")
    ).to.be.revertedWith("Rating must be 1 to 5");
  });

  it("Average rating calculated correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, {
      value: ethers.parseEther("0.6")
    });
    await localraise.connect(bob).invest(0, {
      value: ethers.parseEther("0.4")
    });
    await localraise.connect(business).distributeRevenue(
      0, "Month 1", { value: ethers.parseEther("0.1") }
    );
    await localraise.connect(alice).leaveReview(0, 4, "Good");
    await localraise.connect(bob).leaveReview(0, 2, "Okay");
    const avg = await localraise.getBusinessAverageRating(
      business.address
    );
    expect(avg).to.equal(3);
  });

  // ── Campaign Updates ─────────────────────────────

  it("Business can post updates", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(business).postUpdate(
      0, "Sales going great this month!", 500
    );
    const updates = await localraise.getCampaignUpdates(0);
    expect(updates.length).to.equal(1);
    expect(updates[0].message).to.equal(
      "Sales going great this month!"
    );
  });

  it("Non owner cannot post update", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await expect(
      localraise.connect(alice).postUpdate(0, "Fake update", 0)
    ).to.be.revertedWith("Not campaign owner");
  });

  it("Update cannot have empty message", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await expect(
      localraise.connect(business).postUpdate(0, "", 0)
    ).to.be.revertedWith("Message cannot be empty");
  });

  it("Posting update increases reputation score", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(business).postUpdate(
      0, "Great month!", 500
    );
    const profile = await localraise.getBusinessProfile(
      business.address
    );
    expect(profile.reputationScore).to.equal(5);
  });

  it("Multiple updates stored correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(business).postUpdate(
      0, "Month 1 update", 300
    );
    await localraise.connect(business).postUpdate(
      0, "Month 2 update", 400
    );
    const updates = await localraise.getCampaignUpdates(0);
    expect(updates.length).to.equal(2);
  });

  // ── Early Exit ───────────────────────────────────

  it("Investor can list position for exit", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(alice).listForExit(0, ethers.parseEther("0.9"));
    expect(await localraise.totalExitListings()).to.equal(1);
  });
  it("Non investor cannot list for exit", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await expect(
      localraise.connect(bob).listForExit(
        0, ethers.parseEther("0.5")
      )
    ).to.be.revertedWith("Not an investor in this campaign");
  });

  it("Buyer gets investment position on exit purchase", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    const askPrice = ethers.parseEther("0.9");
    await localraise.connect(alice).listForExit(0, askPrice);
    await localraise.connect(bob).buyExit(0, { value: askPrice });
    const bobInv = await localraise.getInvestment(0, bob.address);
    expect(bobInv.amount).to.equal(GOAL);
  });

  it("Seller receives payment on exit", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    const askPrice = ethers.parseEther("0.9");
    await localraise.connect(alice).listForExit(0, askPrice);
    const before = await ethers.provider.getBalance(alice.address);
    await localraise.connect(bob).buyExit(0, { value: askPrice });
    const after = await ethers.provider.getBalance(alice.address);
    expect(after).to.be.gt(before);
  });

  it("Seller can cancel exit listing", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(alice).listForExit(
      0, ethers.parseEther("0.9")
    );
    await localraise.connect(alice).cancelExitListing(0);
    const listing = await localraise.exitListings(0);
    expect(listing.active).to.equal(false);
  });

  it("Cannot buy own exit listing", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(alice).listForExit(
      0, ethers.parseEther("0.9")
    );
    await expect(
      localraise.connect(alice).buyExit(0, {
        value: ethers.parseEther("0.9")
      })
    ).to.be.revertedWith("Cannot buy your own listing");
  });

  // ── Repayment ────────────────────────────────────

  it("Revenue share distribution reaches investors", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    const before = await ethers.provider.getBalance(alice.address);
    await localraise.connect(business).distributeRevenue(
      0, "Month 1", { value: ethers.parseEther("0.1") }
    );
    const after = await ethers.provider.getBalance(alice.address);
    expect(after).to.be.gt(before);
  });

  it("Fixed installment reaches investors", async () => {
    await localraise.connect(business).createCampaign(
      "Kirana Store", "desc", "Mumbai",
      1, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    const before = await ethers.provider.getBalance(alice.address);
    await localraise.connect(business).repayInstallment(
      0, "Month 1", { value: ethers.parseEther("0.1") }
    );
    const after = await ethers.provider.getBalance(alice.address);
    expect(after).to.be.gt(before);
  });

  it("Repayment count increments correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Kirana Store", "desc", "Mumbai",
      1, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(business).repayInstallment(
      0, "Month 1", { value: ethers.parseEther("0.1") }
    );
    await localraise.connect(business).repayInstallment(
      0, "Month 2", { value: ethers.parseEther("0.1") }
    );
    const c = await localraise.getCampaign(0);
    expect(c.repaymentCount).to.equal(2);
  });

  // ── Refund ───────────────────────────────────────

  it("Investors refunded on campaign cancel", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, {
      value: ethers.parseEther("0.5")
    });
    const before = await ethers.provider.getBalance(alice.address);
    await localraise.connect(business).cancelCampaign(0);
    const after = await ethers.provider.getBalance(alice.address);
    expect(after).to.be.gt(before);
  });

  it("Anyone can trigger refund after deadline", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, 7, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, {
      value: ethers.parseEther("0.3")
    });
    await time.increase(8 * 24 * 60 * 60);
    const before = await ethers.provider.getBalance(alice.address);
    await localraise.connect(bob).refundExpiredCampaign(0);
    const after = await ethers.provider.getBalance(alice.address);
    expect(after).to.be.gt(before);
  });

  // ── Platform Owner ───────────────────────────────

  it("Platform owner can verify a business", async () => {
    await localraise.verifyBusiness(business.address);
    const profile = await localraise.getBusinessProfile(
      business.address
    );
    expect(profile.isVerified).to.equal(true);
  });

  it("Platform owner can update minimum investment", async () => {
    await localraise.updateMinimumInvestment(
      ethers.parseEther("0.01")
    );
    expect(await localraise.minimumInvestment()).to.equal(
      ethers.parseEther("0.01")
    );
  });

  it("Platform owner can update default period", async () => {
    await localraise.updateDefaultPeriod(45 * 24 * 60 * 60);
    expect(await localraise.defaultPeriod()).to.equal(
      45 * 24 * 60 * 60
    );
  });

  it("Cannot set default period below 30 days", async () => {
    await expect(
      localraise.updateDefaultPeriod(10 * 24 * 60 * 60)
    ).to.be.revertedWith("Min 30 days");
  });

  it("Platform stats update after funding", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    const [c, v] = await localraise.getPlatformStats();
    expect(c).to.equal(1);
    expect(v).to.equal(GOAL);
  });
});
