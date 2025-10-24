import { expect } from "chai";
import { ethers } from "hardhat";

describe("Legacy6Coin + RelicNFT", function () {
  it("staking retains voting power and burn mints relic", async function () {
    const [deployer, user] = await ethers.getSigners();

    const Coin = await ethers.getContractFactory("Legacy6Coin");
    const coin = await Coin.deploy();
    await coin.deployed();

    // relic contract is deployed inside the coin constructor
    const relicAddress = await coin.relicNFT();
    const Relic = await ethers.getContractFactory("RelicNFT");
    const relic = Relic.attach(relicAddress);

    // transfer 50 L6C to user (within per-transfer 66 L6C limit)
    const fifty = ethers.utils.parseEther("50");
    await coin.transfer(user.address, fifty);

    // create a proposal as deployer (deployer is a witness by constructor)
    await coin.createProposal("Proposal #1");

    // user stakes 20 L6C
    const twenty = ethers.utils.parseEther("20");
    await coin.connect(user).stake(twenty);

    // user votes for proposal 0
    await coin.connect(user).vote(0, true);

    const proposal = await coin.getProposal(0);
    const liquid = await coin.balanceOf(user.address);
    const staked = await coin.stakedBalance(user.address);
    const expected = liquid.add(staked);

    expect(proposal.votesFor).to.equal(expected);

    // user burns 1 L6C to get relic (minimum enforced)
    const one = ethers.utils.parseEther("1");
    await coin.connect(user).burnForRelic(one);
    expect(await coin.hasRelic(user.address)).to.equal(true);

    // first minted token id should be 0 (owned by user)
    expect(await relic.ownerOf(0)).to.equal(user.address);
  });
});
