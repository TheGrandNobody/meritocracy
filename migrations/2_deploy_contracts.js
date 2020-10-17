var ValueFeed = artifacts.require("ValueFeed");
var ValueToken = artifacts.require("ValueToken");
var TestToken = artifacts.require("./TestToken.sol");

module.exports = function(deployer) {
    deployer.deploy(TestToken)
    deployer.deploy(ValueToken).then(function(){
        return deployer.deploy(ValueFeed, ValueToken.address)
});
};
