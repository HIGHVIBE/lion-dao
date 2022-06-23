/* eslint-disable jest/valid-expect */
const { expect } = require("chai");
const { ethers } = require("hardhat");
const keccak256 = require('keccak256');
const { MerkleTree } = require('merkletreejs');

//acc1 can mint in all 3 stages
//acc2 can only mint in stage2 and stage3
//acc3 can only mint in stage3


describe("Generative Unit Test", function () {
  let Generative
  let generative
  let owner, acc1, acc2, acc3
  let merkleTree1
  let merkleTree2

  // eslint-disable-next-line no-undef
  before(async function () {

    const unrevealedUri = "unrevealed uri";
    const nestPeriods = [0, 2, 4];
    const nestUri = ["uri1", "uri2", "uri3"];

    [owner, acc1, acc2, acc3] = await ethers.getSigners();

    const stage1List = ["0x464b10f3E2AB3e49B32d1D21feBafbbf0a4059D9"];
    const stage2List = ["0x464b10f3E2AB3e49B32d1D21feBafbbf0a4059D9"];
    stage1List.push(acc1.address);
    stage2List.push(acc1.address);
    stage2List.push(acc2.address);

    const leafNodes1 = stage1List.map(addr => keccak256(addr));
    merkleTree1 = new MerkleTree(leafNodes1, keccak256, { sortPairs: true });
    const root1Hash = "0x" + merkleTree1.getRoot().toString('hex');

    const leafNodes2 = stage2List.map(addr => keccak256(addr));
    merkleTree2 = new MerkleTree(leafNodes2, keccak256, { sortPairs: true });
    const root2Hash = "0x" + merkleTree2.getRoot().toString('hex');

    Generative = await ethers.getContractFactory("GENERATIVE");
    generative = await Generative.deploy(
      unrevealedUri, root1Hash, nestPeriods, nestUri, root2Hash, owner.address, 1000
    );
    await generative.deployed();

    await generative.reveal(true);
    await generative.startStage1();
  })

  beforeEach(async function () {

  })

  it("should not let acc1 to mint without inadequate funds", async function () {
    const keccakAddress1 = keccak256(acc1.address);
    const stage1Acc1Proof = merkleTree1.getHexProof(keccakAddress1)
    await expect(generative.connect(acc1).mint(stage1Acc1Proof,
      { value: ethers.utils.parseUnits("0", "wei") })).to.be.reverted;
  })

  it("should let acc1 mint once with enough funds", async function () {

    const keccakAddress1 = keccak256(acc1.address);
    const stage1Acc1Proof = merkleTree1.getHexProof(keccakAddress1)
    const stage1Price = await generative.stage1Cost();
    const mintStage1Txn = await generative.connect(acc1).mint(stage1Acc1Proof,
      { value: ethers.utils.parseUnits(stage1Price.toString(), "wei") });
    await mintStage1Txn.wait();
  });

  it("should not let acc1 to mint more than once in stage1", async function () {
    const keccakAddress1 = keccak256(acc1.address);
    const stage1Acc1Proof = merkleTree1.getHexProof(keccakAddress1)
    const stage1Price = await generative.stage1Cost();
    await expect(generative.connect(acc1).mint(stage1Acc1Proof,
      { value: ethers.utils.parseUnits(stage1Price.toString(), "wei") })).to.be.reverted;
  })

  it("should not let acc2 to mint in stage1", async function () {
    const keccakAddress2 = keccak256(acc2.address);
    const stage1Acc2Proof = merkleTree1.getHexProof(keccakAddress2)
    const stage1Price = await generative.stage1Cost();
    await expect(generative.connect(acc1).mint(stage1Acc2Proof,
      { value: ethers.utils.parseUnits(stage1Price.toString(), "wei") })).to.be.reverted;
  })

  it("should not let owner start stage2 before the required time has passed", async function () {
    await ethers.provider.send("evm_increaseTime", [0]);
    await expect(generative.startStage2()).to.be.reverted;
  })

  it("should not let non-owner user to start stage2 before the required time has passed",
    async function () {
      await ethers.provider.send("evm_increaseTime", [60]);
      await expect(generative.connect(acc1).startStage2()).to.be.reverted;
    })

  it("should let owner start stage2 after the required time has passed", async function () {
    await ethers.provider.send("evm_increaseTime", [60]);
    const txn = await generative.startStage2();
    await txn.wait()
  })

  it("should not let acc1 to mint in stage2 without adequate funds", async function () {
    const keccakAddress1 = keccak256(acc1.address)
    const stage2Acc1Proof = merkleTree2.getHexProof(keccakAddress1)
    await expect(generative.connect(acc1).mint(stage2Acc1Proof,
      { value: ethers.utils.parseUnits("0", "wei") })).to.be.reverted;
  })

  it("should let acc1 to mint in stage2 with adequate funds", async function () {
    const keccakAddress1 = keccak256(acc1.address)
    const stage2Acc1Proof = merkleTree2.getHexProof(keccakAddress1)
    const stage2Price = await generative.stage2Cost();
    await generative.connect(acc1).mint(stage2Acc1Proof,
      { value: ethers.utils.parseUnits(stage2Price.toString(), "wei") });
  })

  it("should not let acc1 to mint more than once in stage2 with adequate funds",
    async function () {
      const keccakAddress1 = keccak256(acc1.address)
      const stage2Acc1Proof = merkleTree2.getHexProof(keccakAddress1)
      const stage2Price = await generative.stage2Cost();
      await expect(generative.connect(acc1).mint(stage2Acc1Proof,
        { value: ethers.utils.parseUnits(stage2Price.toString(), "wei") })).to.be.reverted;
    })

  it("should not let acc2 to mint in stage2 without adequate funds", async function () {
    const keccakAddress2 = keccak256(acc2.address)
    const stage2Acc2Proof = merkleTree2.getHexProof(keccakAddress2)
    await expect(generative.connect(acc2).mint(stage2Acc2Proof,
      { value: ethers.utils.parseUnits("0", "wei") })).to.be.reverted;
  })

  it("should let acc2 to mint in stage2 with adequate funds", async function () {
    const keccakAddress2 = keccak256(acc2.address)
    const stage2Acc2Proof = merkleTree2.getHexProof(keccakAddress2)
    const stage2Price = await generative.stage2Cost();
    await generative.connect(acc2).mint(stage2Acc2Proof,
      { value: ethers.utils.parseUnits(stage2Price.toString(), "wei") });
  })

  it("should not let acc2 to mint more than once in stage2 with adequate funds",
    async function () {
      const keccakAddress2 = keccak256(acc2.address)
      const stage2Acc2Proof = merkleTree2.getHexProof(keccakAddress2)
      const stage2Price = await generative.stage2Cost();
      await expect(generative.connect(acc2).mint(stage2Acc2Proof,
        { value: ethers.utils.parseUnits(stage2Price.toString(), "wei") })).to.be.reverted;
    })

  it("should not let acc3 to mint in stage2", async function () {
    const keccakAddress3 = keccak256(acc3.address)
    const stage2Acc3Proof = merkleTree2.getHexProof(keccakAddress3)
    const stage2Price = await generative.stage2Cost();
    await expect(generative.connect(acc2).mint(stage2Acc3Proof,
      { value: ethers.utils.parseUnits(stage2Price.toString(), "wei") })).to.be.reverted;
  })

  it("should let only the owner to start stage3 after the required time has passed",
    async function () {
      await expect(generative.startStage3()).to.be.reverted;
      await ethers.provider.send("evm_increaseTime", [60]);
      await expect(generative.connect(acc1).startStage3()).to.be.reverted;
      const txn = await generative.startStage3();
      await txn.wait();
    })

  it("should let all accounts to let only once in stage3 with adequate funds",
    async function () {
      const stage3Price = await generative.stage3Cost();

      await expect(generative.connect(acc1).mint([],
        { value: ethers.utils.parseUnits("0", "wei") })).to.be.reverted;
      await expect(generative.connect(acc2).mint([],
        { value: ethers.utils.parseUnits("0", "wei") })).to.be.reverted;
      await expect(generative.connect(acc3).mint([],
        { value: ethers.utils.parseUnits("0", "wei") })).to.be.reverted;

      await generative.connect(acc1).mint([],
        { value: ethers.utils.parseUnits(stage3Price.toString(), "wei") })
      await generative.connect(acc2).mint([],
        { value: ethers.utils.parseUnits(stage3Price.toString(), "wei") })
      await generative.connect(acc3).mint([],
        { value: ethers.utils.parseUnits(stage3Price.toString(), "wei") })

      await expect(generative.connect(acc1).mint([],
        { value: ethers.utils.parseUnits(stage3Price.toString(), "wei") })).to.be.reverted;
      await expect(generative.connect(acc2).mint([],
        { value: ethers.utils.parseUnits(stage3Price.toString(), "wei") })).to.be.reverted;
      await expect(generative.connect(acc3).mint([],
        { value: ethers.utils.parseUnits(stage3Price.toString(), "wei") })).to.be.reverted;

    })
});
