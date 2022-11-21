// SPDX-License-Identifier: MIT

//  _            _                      _            
// /_)_  /_     /_)  _/__/__  __/|/    / `_  __/__  /
///_)/_|/_//_/ /_)/_//  / /_'/ / //_/ /_,/_|/ / /_'/ 
//         _/                     _/                 

pragma solidity ^0.8.0;

import "./ERC721A.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./IRLBTRFLY.sol";
import "./IRewardDistributor.sol";
//import "https://github.com/redacted-cartel/contracts-v2/blob/relocker-audit-findings-proxy/contracts/core/Relocker.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";


contract BabyButterflyCartelNFT is ERC721A, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using SafeERC20 for IERC20;

    uint256 price;
    uint256 priceBtrfly;
    uint16 maxSupply;
    //redacted cartel butterfly address
    address Btrfly;
    IRLBTRFLY public irlbtrfly;
    IRewardDistributor public irewardsdistributor;
    
    //test addys
    //[Contracts.BTRFLYV2]: '0x4bc4bba990fe31d529d987f7b8ccf79f1626e559',
    address RLBTRFLYAddress = 0xB4Ce286398C3EeBDE71c63A6A925D7823821c1Ee;
    address IREWARDSDISTRIBUTORAddress = 0xd756DfC1a5AFd5e36Cf88872540778841B318894;
    //real addys
    //[Contracts.BTRFLYV2]: '0xc55126051B22eBb829D00368f4B12Bde432de5Da',
    //[Contracts.RLBTRFLY]: '0x742B70151cd3Bc7ab598aAFF1d54B90c3ebC6027',
    //[Contracts.RewardDistributor]: '0xd7807E5752B368A6a64b76828Aaff0750522a76E',

    //Treasury rewards distrib values 
    // rewardPerBBC tracks the cumulative amount of ETH awarded for each BBC since the protocol's inception.
    uint public rewardPerBBC;

    // ethprincipalBalance tracks the treasury's principal stETH balance.
    uint public ethprincipalBalance;//BTRFLY

    // allocatedEthRewards tracks the current amount of ETH that has been allocated to god owners.
    uint public allocatedEthRewards;

    // updateCallerReward expresses, in basis points, the percentage of newRewards paid to the function
    // caller, as an incentive to pay the gas prices for calling update functions.
    uint public updateCallerReward;

    uint public v2Rewards;//BTRFLY rewards  https://app.redacted.finance/1/rewards/%7BwalletAddress%7D
    uint public totalhiddenhandrewards;//ETH rewards https://hhand.xyz/reward/0/0x9f74662ad05840ba35d111930501c617920dd68e
    //Btrfly -> locked into RLBTRFLY = V2 rewards + Hidden rewards 
    //timer
    //uint256 public initialTime;

    uint256 public constant MaxPublicMint = 2;
    uint256 public constant MaxWhitelistMint = 5;

    string private  baseTokenUri;
    string public   placeholderTokenUri;
    string private  hhapi;
    string private  v2api;

    //deploy smart contract, toggle WL, toggle WL when done, toggle publicSale 
    bool public isRevealed;
    bool public publicSale;
    bool public whiteListSale;
    bool public pause;
    bool public teamMinted;

    bytes32 private merkleRoot;

    mapping(address => uint256) public totalPublicMint;
    mapping(address => uint256) public totalWhitelistMint;


    //mapping(address => Claim) public claimstruct;
    //address[] private claimfunctiontuple;


    // maps NFTtokenId to epochs rewards
    mapping (address => uint256) public v2Reward; //2 weeks\
    mapping (address => uint256) public hiddenHandRewards; 

    // claimedEpochs stores the amount of rewards per BBC that each address has claimed thus far.
    mapping(address => uint) public claimedEpochs;

    event RewardPerBBCUpdated(uint _rpb, address indexed _callerAddress);
    event Relock(address indexed account, uint256 amount);
    error ZeroAmount();
    
    
    constructor(uint16 supply, address btrfly) ERC721A("Baby Butterfly Cartel", "BBC") {
        price = 0.025 ether; //1eth = 40 BTRFLY 10 btrfly
        priceBtrfly = 0.025 ether;
        maxSupply = supply;
        Btrfly = btrfly;
        ethprincipalBalance = 0;
        allocatedEthRewards = 0;
        rewardPerBBC = 0;
        // set caller reward to 1%
        updateCallerReward = 100;
        //contract interface
        irlbtrfly = IRLBTRFLY(RLBTRFLYAddress);
        irewardsdistributor = IRewardDistributor(IREWARDSDISTRIBUTORAddress);
        
    }

        //btrfly.approve(irlbtrfly, type(uint256).max);
    //}


    //stops botting from contract
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "BBC :: Cannot be called by a contract");
        _;
    }   
    
    //change prices
    function changePrice(uint256 _newPrice) public onlyOwner{
        price = _newPrice;
    }

    function changepriceBtrfly(uint256 _newPrice) public onlyOwner{
        priceBtrfly = _newPrice;
    }
    //WL mints
    function whitelistMint(bytes32[] memory _merkleProof, uint256 _quantity) external payable callerIsUser{
        require(whiteListSale, "BBC :: Minting is on Pause");
        require((totalSupply() + _quantity) <= maxSupply, "BBC :: Cannot mint beyond max supply");
        require((totalWhitelistMint[msg.sender] + _quantity)  <= MaxWhitelistMint, "BBC :: Cannot mint beyond whitelist max mint!");
        require(msg.value >= (price * _quantity), "BBC :: Payment is below the price");
        //create leaf node
        bytes32 sender = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, merkleRoot, sender), "BBC :: You are not whitelisted");

        totalWhitelistMint[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    }

    function whitelistmintWithBtrfly(bytes32[] memory _merkleProof, uint256 _quantity, uint256 _cost) external callerIsUser{
        require(whiteListSale, "BBC :: Minting is on Pause");
        require((totalSupply() + _quantity) <= maxSupply, "BBC :: Cannot mint beyond max supply");
        require((totalWhitelistMint[msg.sender] + _quantity)  <= MaxWhitelistMint, "BBC :: Cannot mint beyond whitelist max mint!");
        require(_cost  >= (price * _quantity), "BBC :: Payment is below the price");
        //create leaf node
        bytes32 sender = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, merkleRoot, sender), "BBC :: You are not whitelisted");

        totalWhitelistMint[msg.sender] += _quantity;
        IERC20(Btrfly).safeTransferFrom(msg.sender, address(this), _cost);
        _safeMint(msg.sender, _quantity);
    }

    //Public mints
    function mint(uint256 _quantity) external payable callerIsUser{
        require(publicSale, "BBC :: Not Yet Active.");
        require((totalSupply() + _quantity) <= maxSupply, "BBC :: Beyond Max Supply");
        require((totalPublicMint[msg.sender] +_quantity) <= MaxPublicMint, "BBC :: Already minted 3 times!");
        require(msg.value >= (price * _quantity), "BBC :: Below ");

        totalPublicMint[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    }
    
    function mintWithBtrfly(uint256 _quantity, uint256 _cost) external callerIsUser{
        require(publicSale, "BBC :: Not Yet Active.");
        require((totalSupply() + _quantity) <= maxSupply, "BBC :: Beyond Max Supply");
        require((totalPublicMint[msg.sender] +_quantity) <= MaxPublicMint, "BBC :: Already minted 200 times!");
        require(_cost >= (priceBtrfly  * _quantity), "BBC :: Below ");

        totalPublicMint[msg.sender] += _quantity;
        IERC20(Btrfly).safeTransferFrom(msg.sender, address(this), _cost);
        _safeMint(msg.sender, _quantity);
    }

    function teamMint() external onlyOwner{
        require(!teamMinted, "BBC :: Team already minted");
        teamMinted = true;
        _safeMint(msg.sender, 20);
    }
  
//Treasury functions
//1
    function depositBTRFLYlock(uint256 _btrflyAmt) external onlyOwner {
        irlbtrfly.lock(address(this), _btrflyAmt);
        ethprincipalBalance = ethprincipalBalance;

    }
    
    function BTRFLYwithdrawExpiredLocksTo() external onlyOwner{
        irlbtrfly.withdrawExpiredLocksTo(address(this));
        //unlockable or call relock proxy 
        //https://github.com/redacted-cartel/contracts-v2/blob/relocker-audit-findings-proxy/contracts/core/Relocker.sol 
    }
//2 claim
/**

    function setclaimstruct(Common.Claim[] calldata claims, uint256 amount) pure internal returns (Claim[] memory) {
        owner = msg.sender;
        Claim[] memory claims;
        claims[0] = Claim(token, account, amount, merkleProof);
        return claims;
        //irewardsdistributor.claim(claims);
        //Common.Claim[] calldata claims
    }
*/

    function claim(Common.Claim[] calldata claims) external{ //2weeks
        irewardsdistributor.claim(claims);
    }

    function claimAndLock(Common.Claim[] calldata claims, uint256 _btrflyAmt) external{//16weeks
    //
        if (_btrflyAmt == 0) revert ZeroAmount();

        irewardsdistributor.claim(claims);
        IERC20(Btrfly).safeTransferFrom(msg.sender, address(this), _btrflyAmt);
        irlbtrfly.lock(msg.sender, _btrflyAmt);

        emit Relock(msg.sender, _btrflyAmt);
    }
/**
    //set tuple for claim
    //function setclaimstruct(address token, address account, uint256 amount, bytes32[] calldata merkleProof) pure internal returns (Claim[] memory) {
        //owner = msg.sender;
        //Claim[] memory claims;
        //claims[0] = Claim(token, account, amount, merkleProof);
       //return claims;
        //irewardsdistributor.claim(claims);
        //Common.Claim[] calldata claims
    }
    function EOAclaimableglobalrewards() external callerIsUser {
        //EOA  
        //takes in the claim struct array
        //return hhapi;
        //return v2api;
        //calls the rewards distrib claim function passing that paramiter 
        //irewardsdistributor.claim(setclaimstruct(Claim(token, account, amount, merkleProof)));
        //updates balance for each address for the two rewards thru mapping each nft to its address
        //rewards is directly transftered to NFT owner 
        //uint256 principalBalance;
    }

    function checkclaimablerewards() external callerIsUser {
        //EOA  
        //takes in the claim struct array
        //return hhapi;
        //calls the rewards distrib claim function passing that paramiter 
        //irewardsdistributor.claim();
        //irewardsdistributor.claim(setclaimstruct(token, account, amount, merkleProof));
        //updates balance for each address for the two rewards thru mapping each nft to its address
        //rewards is directly transftered to NFT owner 
        //ownerBbcCount[msg.sender]++;
        //uint256 principalBalance;

    }


//3 distribute
    /**
        @notice this function updates rewardPerBBC based on the relationship between Eth prin bal
        and actual eth in the contract
    */
    function updateETHRewardPerBBC() public nonReentrant {
        uint256 ethBal = address(this).balance;
        // If eth available in the contract, update rewardPerBBC, add newRewards to allocatedEthRewards.
        if (ethBal > (ethprincipalBalance + allocatedEthRewards)) {
        uint newRewards = ethBal - (ethprincipalBalance + allocatedEthRewards);
        uint callerReward = newRewards * updateCallerReward / 10000;
        newRewards = newRewards - callerReward;
        rewardPerBBC = rewardPerBBC + newRewards / totalSupply();
        allocatedEthRewards = allocatedEthRewards + newRewards;
        emit RewardPerBBCUpdated(rewardPerBBC, msg.sender);

        if(callerReward > 0){
            payable(msg.sender).transfer(callerReward);

            }
        }
    }

    /**
        @notice getPendingEthReward returns the amount of ETH that has accrued to the user
        and has yet to be claimed.
    */
    function getPendingETHReward(address _user) public view returns (uint256)
    {
        return (balanceOf(_user) * (rewardPerBBC - claimedEpochs[_user]));
    }
    
    /**
        @notice internal helper function for claimEthRewards
    */
    function _claimEthRewards(address _user) internal nonReentrant{
        uint256 currentRewards = getPendingETHReward(_user);
        if (currentRewards > 0) {
        allocatedEthRewards = allocatedEthRewards - currentRewards;
        claimedEpochs[_user] = rewardPerBBC;
        payable(msg.sender).transfer(currentRewards);
        }
    }

    /**
        @notice _claimEthRewards is called to claim rewards on behalf of a user.
    */
    function claimEthRewards(address _user) external{
        require(balanceOf(_user) > 0, "Can only claim if balance of user > 0");
        _claimEthRewards(_user);
    }

/**
//2 Automatically unlock rewards with timer every 2 weeks.

    function getrewards() external onlyOwner {
        //what is the merkleproof 
        //mapping(address => Reward) public rewards;
        irewardsdistributor.rewards(address(this));
    }
    function getmerkleProof() external onlyOwner {
        //merkleProof,
        //reward.merkleRoot,//root
        // keccak256(abi.encodePacked(account, amount))//leaf
        //https://hhand.xyz/reward/0/0x9f74662ad05840ba35d111930501c617920dd68e
        //irewardsdistributor.rewards(address(this));
    }

    //https://github.com/redacted-cartel/contracts-v2/blob/relocker-audit-findings-proxy/contracts/core/Relocker.sol
    //https://etherscan.io/address/0x025c6da5bd0e6a5dd1350fda9e3b6a614b205a1f#code// ape airdrop
 
    function irewardsdistributorclaim (address token, address account, uint256 amount, bytes32[] calldata merkleProof)  external onlyOwner{
        return hhapi;
        return v2api; 
        return bytes(hhapi).length > 0 ? string(abi.encodePacked(hhapi.toString(), " ")):"";

        irewardsdistributor.claim(setclaimstruct(token, account, amount, merkleProof)); //eth
            //read the amount recieced and assign it to a uint256
            //console.log("Eth sent to contract ready to distribute please claim your eth rewards");
        }
        //call function using timer peroidically & WHEN BTRFLYlock =TRUE
    }
    
//has this nft claimed its rewards 
//mapping of token ID >>.has claimed bool statement

//EOA calls claim function every 2 weeks
//EOA calls relock every 16 weeks
//every 2 weeks, call the claim function from EOA for HH rewards + V2 Rewards available 
//choice not claim & just let it compund from the 16 week relocks. 
//every 16 weeks rewards claimed before relocking and automatically distributed not compounded
//principle is relocked
//rewards is directly transftered to NFT owner 

     //Treasury rewards distrib values 
    //uint public principalBalance;//BTRFLY
    //uint public v2Rewards;//BTRFLY rewards  https://app.redacted.finance/1/rewards/%7BwalletAddress%7D
    //uint256 public totalhiddenhandrewards;//ETH rewards https://hhand.xyz/reward/0/0x9f74662ad05840ba35d111930501c617920dd68e
    //Btrfly -> locked into RLBTRFLY = V2 rewards + Hidden rewards 
    // maps NFTtokenId to epochs rewards
    //mapping (address => uint256) public rewards; //2 weeks
    //uint256 public totalepochrewards; //6weeks
    //brings butterfly & eth into contract
    //front end passes
    //https://hhand.xyz/reward/0/0x9f74662ad05840ba35d111930501c617920dd68e
    //irewardsdistributor.rewards(address(this));

//3 user can claim rewards 
    function claimepochrewardsperNFT(uint256[] calldata tokenIds) external callerIsUser{
        uint256 tokenId;
        epochrewards -= tokenIds.length;
        address _owner = msg.sender;
        uint256 numberOfOwnedNFT = balanceOf(_owner);
        //return numberOfOwnedNFT;
        //check much NFT's person owned
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            //Stake memory staked = vault[tokenId];
        }
        allocatedRLBTRFLYRewards = ((epochrewards/maxSupply)*numberOfOwnedNFT);
        //divide total rewards by number of nfts then multiply per per person
        return allocatedRLBTRFLYRewards;

        //IERC20(Btrfly).safeTransferFrom(msg.sender, address(this), allocatedRLBTRFLYRewards);
        //payable(msg.sender).transfer(address(this).balance);//eth & BTRFLY
        _owner.transfer(msg.allocatedRLBTRFLYRewards);
        //safe transfer allocated reward
    }
        function claimepochrewardsperNFT(uint256[] calldata tokenIds) external callerIsUser{
        uint256 tokenId;
        epochrewards -= tokenIds.length;
        address _owner = msg.sender;
        uint256 numberOfOwnedNFT = balanceOf(_owner);
        //return numberOfOwnedNFT;
        //check much NFT's person owned
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            //Stake memory staked = vault[tokenId];
        }
        allocatedRLBTRFLYRewards = ((epochrewards/maxSupply)*numberOfOwnedNFT);
        //divide total rewards by number of nfts then multiply per per person
        return allocatedRLBTRFLYRewards;

        //IERC20(Btrfly).safeTransferFrom(msg.sender, address(this), allocatedRLBTRFLYRewards);
        //payable(msg.sender).transfer(address(this).balance);//eth & BTRFLY
        _owner.transfer(msg.allocatedRLBTRFLYRewards);
        //safe transfer allocated reward
    }
*/

//nft metadata

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenUri;
    }

    //return uri for certain token
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        uint256 trueId = tokenId + 1;

        if(!isRevealed){
            return placeholderTokenUri;
        }
        //string memory baseURI = _baseURI();
        return bytes(baseTokenUri).length > 0 ? string(abi.encodePacked(baseTokenUri, trueId.toString(), ".json")) : "";
    }
    
    ///@dev walletOf() function shouldn't be called on-chain due to gas consumption
    function walletOf() external view returns(uint256[] memory){
        address _owner = msg.sender;
        uint256 numberOfOwnedNFT = balanceOf(_owner);
        uint256[] memory ownerIds = new uint256[](numberOfOwnedNFT);

        for(uint256 index = 0; index < numberOfOwnedNFT; index++){
            ownerIds[index] = tokenOfOwnerByIndex(_owner, index);
        }

        return ownerIds;
    }

    //onlyowner functions
    //api
    function sethhapi(string memory _hhapi) external onlyOwner{
        hhapi = _hhapi;
        //https://hhand.xyz/reward/0/account
    }

    function setv2api(string memory _v2api) external onlyOwner{
        v2api = _v2api;
        //https://app.redacted.finance/1/rewards/%7BwalletAddress%7D
    }
    /**
        @notice setUpdateCallerReward updates the reward percentage paid to the function caller for
        calling updateRewardPerBBC.
        @param _amt The amount to set the reward to, in basis points (i.e. 100 = 1%)
    */
    function setUpdateCallerReward(uint _amt) external onlyOwner{
        require(_amt <= 100, "hardcode max caller reward is 1%");
        updateCallerReward = _amt;
    }

    //nft
    function setTokenUri(string memory _baseTokenUri) external onlyOwner{
        baseTokenUri = _baseTokenUri;
    }

    function setPlaceHolderUri(string memory _placeholderTokenUri) external onlyOwner{
        placeholderTokenUri = _placeholderTokenUri;
    }

    function togglePause() external onlyOwner{
        pause = !pause;
    }

    function togglePublicSale() external onlyOwner{
        publicSale = !publicSale;
    }

    function toggleReveal() external onlyOwner{
        isRevealed = !isRevealed;
    }

    //withdrawl eth & bTRFLY
    function withdraw() external onlyOwner{
        payable(msg.sender).transfer(address(this).balance);
    }

    function collectBtrfly() public onlyOwner{
        uint256 bal = IERC20(Btrfly).balanceOf(address(this));
        require(bal > 0, "No Btrfly to collect");
        IERC20(Btrfly).safeTransfer(owner(), bal);
    }
}
