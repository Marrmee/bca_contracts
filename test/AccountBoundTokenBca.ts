import { ethers } from "hardhat";
import { BigNumber, Contract, Signer } from "ethers";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { getAddress } from "@ethersproject/address";
import { AccountBoundTokenBca } from "../typechain/AccountBoundTokenBca";
import { AccountBoundTokenBcaFactory } from "../typechain/AccountBoundTokenBcaFactory";
import { string } from "hardhat/internal/core/params/argumentTypes";

chai.use(solidity);

const { expect } = chai;

const BASE_URI = "https://token-cdn-domain/";

describe("AccountBoundTokenBCA", () => {
  let abt: AccountBoundTokenBca,
    deployer: Signer,
    admin1: Signer,
    admin2: Signer,
    vault: Signer,
    addresses: Signer[];

  const setupProductNft = async () => {
    [deployer, admin1, admin2, vault, ...addresses] = await ethers.getSigners();
    abt = await new AccountBoundTokenBcaFactory(deployer).deploy(
      BASE_URI, [await addresses[0].getAddress(), await addresses[1].getAddress()]
      );
    await abt.deployed();
  };

  describe("Deployment", async () => {
    beforeEach(setupProductNft)

    it("should deploy", async () => {
      expect(abt).to.be.ok;
    });
  })

  describe("Set the membership price", async () => {
    beforeEach(setupProductNft)

    it("sets the price", async () => {
      await abt.connect(addresses[0]).setEthPriceForMembership(5);
      const newPrice = await abt.MEMBERSHIP_COST();
      expect(newPrice).to.equal(ethers.utils.parseEther("2.5"));
    });
  })

  describe("Grant membership, mint an ABT and remove member", async () => {
    beforeEach(setupProductNft)
  
    it("adds a member by granting the member role", async () => {
      const memberAddress = await addresses[3].getAddress();
      const addMember = await abt.connect(addresses[0]).giveMemberRole(memberAddress);
      expect(addMember).to.emit(abt, "MemberAdded").withArgs(
        memberAddress, await abt.MEMBER_ROLE()
      );
    });

    it("mints an ABT", async () => {
      const formerMemberAddress = await addresses[4].getAddress();
      await abt.connect(addresses[0]).giveMemberRole(formerMemberAddress);
      const tokenBalanceBeforeMint = await abt.tokenIdsByAddresses(formerMemberAddress);
      const override = {value: ethers.utils.parseEther("8")}
      await abt.connect(addresses[4]).memberMint(override);
      const tokenBalanceAfterMint = await abt.tokenIdsByAddresses(formerMemberAddress);
      expect(tokenBalanceAfterMint).to.equal(tokenBalanceBeforeMint.add(1));
    });

    it("emits mint completed", async () => {
      const memberAddress = await addresses[3].getAddress();
      await abt.connect(addresses[0]).giveMemberRole(memberAddress);
      const override = {value: ethers.utils.parseEther("8")}
      const mintToken = await abt.connect(addresses[3]).memberMint(override);
      expect(mintToken).to.emit(abt, "MintCompleted").withArgs(
        memberAddress, await abt.currentTokenId(), await abt.tokenURI(await abt.currentTokenId())
      );
    });

    it("removes member and burns the associated ABT", async () => {
      const formerMemberAddress = await addresses[4].getAddress();
      await abt.connect(addresses[0]).giveMemberRole(formerMemberAddress);
      const override = {value: ethers.utils.parseEther("8")}
      await abt.connect(addresses[4]).memberMint(override);
      const tokenBalanceBeforeRemoval = await abt.tokenIdsByAddresses(formerMemberAddress);
      await abt.connect(addresses[0]).removeMember(formerMemberAddress);
      const tokenBalanceAfterRemoval = await abt.tokenIdsByAddresses(formerMemberAddress);
      expect(tokenBalanceBeforeRemoval).to.equal(tokenBalanceAfterRemoval.add(1));
    });

    it("emits an event after removing a member", async () => {
      const formerMemberAddress = await addresses[4].getAddress();
      await abt.connect(addresses[0]).giveMemberRole(formerMemberAddress);
      const override = {value: ethers.utils.parseEther("8")}
      await abt.connect(addresses[4]).memberMint(override);
      const removeMember = await abt.connect(addresses[0]).removeMember(formerMemberAddress);
      const tokenBalanceAfterRemoval = await abt.tokenIdsByAddresses(formerMemberAddress);
      expect(removeMember).to.emit(abt, "MemberRemoved").withArgs(
        formerMemberAddress, tokenBalanceAfterRemoval,
      );
    });
  });

  describe("Ether payments", async () => {
    beforeEach(setupProductNft)

    it("refunds if too much ETH is sent", async () => {
      await abt.connect(addresses[0]).setEthPriceForMembership(5);
      const memberAddress = await addresses[7].getAddress();
      await abt.connect(addresses[0]).giveMemberRole(memberAddress);
      const override = {value: ethers.utils.parseEther("6.5")}
      const mint = await abt.connect(addresses[7]).memberMint(override);
      const receipt = await mint.wait()
      const gasSpent = receipt.gasUsed.mul(receipt.effectiveGasPrice) 
      expect(await addresses[7].getBalance()).to.equal(ethers.utils.parseEther("9997.5").sub(gasSpent))
    });

    it("reverts if not enough ETH is sent", async () => {
      const memberAddress = await addresses[4].getAddress();
      await abt.connect(addresses[0]).giveMemberRole(memberAddress);
      const override = {value: ethers.utils.parseEther("1")}
      await expect(abt.connect(addresses[4]).memberMint(override)
      ).to.be.revertedWith("Need to send more ETH");
    });
  });

  describe("Withdrawal of ether", async () => {
    beforeEach(setupProductNft)

    it("withdraws ether stored in contract", async() => {
      const memberAddress = await addresses[4].getAddress();
      await abt.connect(addresses[0]).giveMemberRole(memberAddress);
      const override = {value: ethers.utils.parseEther("8")}
      await abt.connect(addresses[4]).memberMint(override);
      const provider = ethers.provider;
      const balanceContractBeforeWithdrawal = await abt.provider.getBalance(abt.address);
      await abt.connect(addresses[0]).withdrawEther();
      const balanceContractAfterWithdrawal = await abt.provider.getBalance(abt.address);
      expect(balanceContractBeforeWithdrawal).to.equal(balanceContractAfterWithdrawal.add(ethers.utils.parseEther("2.5")));
    });
  });
});