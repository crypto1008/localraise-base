const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("LocalRaise", function () {
  let localraise, owner, treasury, business, alice, bob, charlie;
  const GOAL = ethers.parseEther("1.0");
  const DAYS_30 = 30;
  const MONTHS_12 = 12;
  const RETURN_20 = 20;

  beforeEach(async () => {
    [owner, treasury, business, alice, bob, charlie] =
      await ethers.getSigners();
    const LocalRaise = await ethers.getContractFactory("LocalRaise");
    localraise = await LocalRaise.deploy(treasury.address);
  });

  // ── Campaign Creation ────────────────────────────

  it("Business can create a revenue share campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Ramesh Chai Shop",
      "Expanding to second location",
      "Dehradun, Uttarakhand",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const c = await localraise.getCampaign(0);
    expect(c.businessName).to.equal("Ramesh Chai Shop");
    expect(c.returnModel).to.equal(0);
  });

  it("Business can create a fixed return campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Suresh Kirana Store",
      "Festival season inventory",
      "Mumbai, Maharashtra",
      1, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const c = await localraise.getCampaign(0);
    expect(c.returnModel).to.equal(1);
  });

  it("Cannot create campaign with empty business name", async () => {
    await expect(
      localraise.connect(business).createCampaign(
        "", "desc", "location",
        0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
      )
    ).to.be.revertedWith("Business name required");
  });

  it("Cannot create campaign with less than 7 days deadline", async () => {
    await expect(
      localraise.connect(business).createCampaign(
        "Test", "desc", "location",
        0, 0, GOAL, 3, MONTHS_12, RETURN_20
      )
    ).to.be.revertedWith("Min 7 days funding period");
  });

  it("Cannot create campaign with more than 36 months repayment", async () => {
    await expect(
      localraise.connect(business).createCampaign(
        "Test", "desc", "location",
        0, 0, GOAL, DAYS_30, 40, RETURN_20
      )
    ).to.be.revertedWith("Max 36 months repayment");
  });

  it("Cannot create campaign with return below 5 percent", async () => {
    await expect(
      localraise.connect(business).createCampaign(
        "Test", "desc", "location",
        0, 0, GOAL, DAYS_30, MONTHS_12, 3
      )
    ).to.be.revertedWith("Min 5 percent return");
  });

  it("Cannot create campaign with return above 200 percent", async () => {
    await expect(
      localraise.connect(business).createCampaign(
        "Test", "desc", "location",
        0, 0, GOAL, DAYS_30, MONTHS_12, 250
      )
    ).to.be.revertedWith("Max 200 percent return");
  });

  it("Business profile activeCampaigns increments on creation", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const profile = await localraise.getBusinessProfile(business.address);
    expect(profile.activeCampaigns).to.equal(1);
  });

  it("Total campaigns count increments correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(business).createCampaign(
      "Kirana Store", "desc", "Mumbai",
      1, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const [campaigns_] = await localraise.getPlatformStats();
    expect(campaigns_).to.equal(2);
  });

  // ── Investment ───────────────────────────────────

  it("Investor can invest in active campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, {
      value: ethers.parseEther("0.5")
    });
    const inv = await localraise.getInvestment(0, alice.address);
    expect(inv.amount).to.equal(ethers.parseEther("0.5"));
  });

  it("Owner cannot invest in own campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await expect(
      localraise.connect(business).invest(0, {
        value: ethers.parseEther("0.5")
      })
    ).to.be.revertedWith("Owner cannot invest in own campaign");
  });

  it("Cannot invest more than goal amount", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await expect(
      localraise.connect(alice).invest(0, {
        value: ethers.parseEther("2.0")
      })
    ).to.be.revertedWith("Exceeds funding goal");
  });

  it("Campaign funded when goal reached and owner receives ETH", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const before = await ethers.provider.getBalance(business.address);
    await localraise.connect(alice).invest(0, { value: GOAL });
    const after = await ethers.provider.getBalance(business.address);
    expect(after).to.be.gt(before);
  });

  it("Platform fee is sent to treasury on funding", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const before = await ethers.provider.getBalance(treasury.address);
    await localraise.connect(alice).invest(0, { value: GOAL });
    const after = await ethers.provider.getBalance(treasury.address);
    expect(after).to.be.gt(before);
  });

  it("Share percent calculated correctly for investors", async () => {
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

  it("Multiple investors share percent adds up correctly", async () => {
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
    const aliceInv = await localraise.getInvestment(0, alice.address);
    const bobInv = await localraise.getInvestment(0, bob.address);
    expect(aliceInv.sharePercent + bobInv.sharePercent).to.equal(10000);
  });

  it("Investor portfolio tracked correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, {
      value: ethers.parseEther("0.5")
    });
    const portfolio = await localraise.getInvestorPortfolio(alice.address);
    expect(portfolio.length).to.equal(1);
  });

  it("Total investors count updates correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, {
      value: ethers.parseEther("0.5")
    });
    await localraise.connect(bob).invest(0, {
      value: ethers.parseEther("0.5")
    });
    const [, , investors_] = await localraise.getPlatformStats();
    expect(investors_).to.equal(2);
  });

  // ── Revenue Share Repayment ──────────────────────

  it("Business can distribute revenue to investors", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    const before = await ethers.provider.getBalance(alice.address);
    await localraise.connect(business).distributeRevenue(
      0, "Month 1 revenue",
      { value: ethers.parseEther("0.1") }
    );
    const after = await ethers.provider.getBalance(alice.address);
    expect(after).to.be.gt(before);
  });

  it("Cannot distribute revenue on fixed return campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Kirana Store", "desc", "Mumbai",
      1, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await expect(
      localraise.connect(business).distributeRevenue(
        0, "test",
        { value: ethers.parseEther("0.1") }
      )
    ).to.be.revertedWith("Not a revenue share campaign");
  });

  it("Revenue repayment history is recorded", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(business).distributeRevenue(
      0, "Month 1",
      { value: ethers.parseEther("0.1") }
    );
    const history = await localraise.getRepaymentHistory(0);
    expect(history.length).to.equal(1);
    expect(history[0].note).to.equal("Month 1");
  });

  it("Investor totalEarned updates after revenue distribution", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(business).distributeRevenue(
      0, "Month 1",
      { value: ethers.parseEther("0.1") }
    );
    const inv = await localraise.getInvestment(0, alice.address);
    expect(inv.totalEarned).to.be.gt(0);
  });

  // ── Fixed Return Repayment ───────────────────────

  it("Business can repay fixed installment", async () => {
    await localraise.connect(business).createCampaign(
      "Kirana Store", "desc", "Mumbai",
      1, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    const before = await ethers.provider.getBalance(alice.address);
    await localraise.connect(business).repayInstallment(
      0, "Month 1 installment",
      { value: ethers.parseEther("0.1") }
    );
    const after = await ethers.provider.getBalance(alice.address);
    expect(after).to.be.gt(before);
  });

  it("Cannot repay installment on revenue share campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await expect(
      localraise.connect(business).repayInstallment(
        0, "test",
        { value: ethers.parseEther("0.1") }
      )
    ).to.be.revertedWith("Not a fixed return campaign");
  });

  it("Fixed repayment history is recorded correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Kirana Store", "desc", "Mumbai",
      1, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(business).repayInstallment(
      0, "Month 1",
      { value: ethers.parseEther("0.1") }
    );
    const history = await localraise.getRepaymentHistory(0);
    expect(history.length).to.equal(1);
  });

  it("Repayment count increments correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Kirana Store", "desc", "Mumbai",
      1, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    await localraise.connect(business).repayInstallment(
      0, "Month 1",
      { value: ethers.parseEther("0.1") }
    );
    await localraise.connect(business).repayInstallment(
      0, "Month 2",
      { value: ethers.parseEther("0.1") }
    );
    const c = await localraise.getCampaign(0);
    expect(c.repaymentCount).to.equal(2);
  });

  // ── Refund and Expiry ────────────────────────────

  it("Investors refunded if campaign cancelled", async () => {
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

  it("Cannot invest after deadline", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, 7, MONTHS_12, RETURN_20
    );
    await time.increase(8 * 24 * 60 * 60);
    await expect(
      localraise.connect(alice).invest(0, {
        value: ethers.parseEther("0.1")
      })
    ).to.be.revertedWith("Funding deadline passed");
  });

  it("Cannot cancel already cancelled campaign", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(business).cancelCampaign(0);
    await expect(
      localraise.connect(business).cancelCampaign(0)
    ).to.be.revertedWith("Can only cancel active campaigns");
  });

  it("isExpired returns true after deadline passes", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, 7, MONTHS_12, RETURN_20
    );
    await time.increase(8 * 24 * 60 * 60);
    expect(await localraise.isExpired(0)).to.equal(true);
  });

  // ── View Functions ───────────────────────────────

  it("getCampaignsByCategory filters correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(business).createCampaign(
      "Auto Rickshaw", "desc", "Delhi",
      2, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const food = await localraise.getCampaignsByCategory(0);
    expect(food.length).to.equal(1);
  });

  it("getActiveCampaigns returns only active ones", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const active = await localraise.getActiveCampaigns();
    expect(active.length).to.equal(1);
  });

  it("Business campaigns list tracked correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(business).createCampaign(
      "Kirana Store", "desc", "Mumbai",
      1, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    const bizCampaigns = await localraise.getBusinessCampaigns(
      business.address
    );
    expect(bizCampaigns.length).to.equal(2);
  });

  it("Monthly installment calculated correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Kirana Store", "desc", "Mumbai",
      1, 1, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    // Fund the campaign first so raisedAmount is set
    await localraise.connect(alice).invest(0, { value: GOAL });
    const installment = await localraise.getMonthlyInstallment(0);
    // Total owed = 1 ETH + 20% = 1.2 ETH / 12 months = 0.1 ETH
    expect(installment).to.equal(ethers.parseEther("0.1"));
  });

  it("Funding progress returns correct percentage", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, {
      value: ethers.parseEther("0.5")
    });
    const progress = await localraise.getFundingProgress(0);
    expect(progress).to.equal(50);
  });

  it("Platform stats update correctly", async () => {
    await localraise.connect(business).createCampaign(
      "Chai Shop", "desc", "Dehradun",
      0, 0, GOAL, DAYS_30, MONTHS_12, RETURN_20
    );
    await localraise.connect(alice).invest(0, { value: GOAL });
    const [campaigns_, volume_] = await localraise.getPlatformStats();
    expect(campaigns_).to.equal(1);
    expect(volume_).to.equal(GOAL);
  });

  // ── Platform Owner ───────────────────────────────

  it("Platform owner can verify a business", async () => {
    await localraise.verifyBusiness(business.address);
    const profile = await localraise.getBusinessProfile(business.address);
    expect(profile.isVerified).to.equal(true);
  });

  it("Verified business gets reputation score boost", async () => {
    await localraise.verifyBusiness(business.address);
    const profile = await localraise.getBusinessProfile(business.address);
    expect(profile.reputationScore).to.equal(100);
  });

  it("Platform owner can update raise fee", async () => {
    await localraise.updateRaiseFee(200);
    expect(await localraise.raiseFeePercent()).to.equal(200);
  });

  it("Cannot set raise fee above 5 percent", async () => {
    await expect(
      localraise.updateRaiseFee(600)
    ).to.be.revertedWith("Max 5 percent fee");
  });

  it("Platform owner can update repayment fee", async () => {
    await localraise.updateRepaymentFee(100);
    expect(await localraise.repaymentFeePercent()).to.equal(100);
  });

  it("Cannot set repayment fee above 2 percent", async () => {
    await expect(
      localraise.updateRepaymentFee(300)
    ).to.be.revertedWith("Max 2 percent fee");
  });

  it("Platform owner can update treasury address", async () => {
    await localraise.updateTreasury(alice.address);
    expect(await localraise.treasury()).to.equal(alice.address);
  });

  it("Cannot set treasury to zero address", async () => {
    await expect(
      localraise.updateTreasury(ethers.ZeroAddress)
    ).to.be.revertedWith("Invalid address");
  });
});
