import { expect } from "chai";
import { ethers } from "hardhat";

describe("Test Initialize transactions.", function () {
  it("Test initialize deposit transactions.", async function () {
    const [owner] = await ethers.getSigners();

    const CUSD = await ethers.getContractFactory("cUSD");
    const cUSD = await CUSD.deploy(100, "cUSD", 0, "cUSD");
    await cUSD.deployed();


    const WakalaEscrow = await ethers.getContractFactory("WakalaEscrow");
    const wakalaEscrow = await WakalaEscrow.deploy(cUSD.address, 1);
    await wakalaEscrow.deployed();

    expect(await wakalaEscrow.getNextTransactionIndex()).to.equal(0);

    expect(await wakalaEscrow.initializeDepositTransaction(100000000))
      .to.emit("WakalaEscrow", "TransactionInitEvent")
          .withArgs(0, owner.getAddress());


    expect(await wakalaEscrow.getNextTransactionIndex()).to.equal(1);
  });
});

describe("Test get transactions counter value.", function () {
  it("Test", async function () {
    const [owner] = await ethers.getSigners();

    const CUSD = await ethers.getContractFactory("cUSD");
    const cUSD = await CUSD.deploy(100, "cUSD", 0, "cUSD");
    await cUSD.deployed();


    const WakalaEscrow = await ethers.getContractFactory("WakalaEscrow");
    const wakalaEscrow = await WakalaEscrow.deploy(cUSD.address, 1);
    await wakalaEscrow.deployed();

    expect(await wakalaEscrow.countSuccessfulTransactions()).to.equal(0);

  });
});

describe("Test Initialize transactions.", function () {
  it("Test initialize withdrawal transactions.", async function () {
    const [owner] = await ethers.getSigners();

    const CUSD = await ethers.getContractFactory("cUSD");
    const cUSD = await CUSD.deploy(100, "cUSD", 0, "cUSD");
    await cUSD.deployed();


    const WakalaEscrow = await ethers.getContractFactory("WakalaEscrow");
    const wakalaEscrow = await WakalaEscrow.deploy(cUSD.address, 1);
    await wakalaEscrow.deployed();

    await cUSD.approve(wakalaEscrow.address, 10);

    expect(await wakalaEscrow.getNextTransactionIndex()).to.equal(0);

    expect(await wakalaEscrow.initializeWithdrawalTransaction(5))
      .to.emit("WakalaEscrow", "TransactionInitEvent")
          .withArgs(0, owner.getAddress());


    expect(await wakalaEscrow.getNextTransactionIndex()).to.equal(1);
  });
});