const CarAsset = artifacts.require("CarAsset");
const CarsToken = artifacts.require("CarsToken");
const PlayerNames = artifacts.require("PlayerNames");
const GameRewards = artifacts.require("GameRewards");
const GMVotes = artifacts.require("GMVotes");

module.exports = async function (deployer) {
  await deployer.deploy(CarsToken);
  await deployer.deploy(CarAsset, CarsToken.address);
  await deployer.deploy(PlayerNames);
  await deployer.deploy(GameRewards, CarsToken.address);
  await deployer.deploy(GMVotes);
};
