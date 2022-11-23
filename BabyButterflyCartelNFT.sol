// SPDX-License-Identifier: MIT

//  _            _                      _            
// /_)_  /_     /_)  _/__/__  __/|/    / `_  __/__  /
///_)/_|/_//_/ /_)/_//  / /_'/ / //_/ /_,/_|/ / /_'/ 
//         _/                     _/                 

pragma solidity ^0.8.0;

import "./ERC721A.sol";
import "./IRLBTRFLY.sol";
import "./IRewardDistributor.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

    uint256 public constant MaxPublicMint = 2;
    uint256 public constant MaxWhitelistMint = 5;

    string private  baseTokenUri;
    string public   placeholderTokenUri;

    //deploy smart contract, toggle WL, toggle WL when done, toggle publicSale 
    bool public isRevealed;
    bool public publicSale;
    bool public whiteListSale;
    bool public pause;
    bool public teamMinted;

    bytes32 private merkleRoot;

    mapping(address => uint256) public totalPublicMint;
    mapping(address => uint256) public totalWhitelistMint;

    // claimedEpochs stores the amount of rewards per BBC that each address has claimed thus far.
    mapping(address => uint) public claimedEpochs;

    event RewardPerBBCUpdated(uint _rpb, address indexed _callerAddress);
    event Relock(address indexed account, uint256 amount);
    error ZeroAmount();
    
    
    constructor(uint16 supply, address btrfly) ERC721A("Baby Butterfly Cartel", "BBC") {
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
    }
//2 claim

    function claim(Common.Claim[] calldata claims) external{ //2weeks
        irewardsdistributor.claim(claims);
    }

    function claimAndLock(Common.Claim[] calldata claims, uint256 _btrflyAmt) external{//16weeks
        if (_btrflyAmt == 0) revert ZeroAmount();

        irewardsdistributor.claim(claims);
        IERC20(Btrfly).safeTransferFrom(msg.sender, address(this), _btrflyAmt);
        irlbtrfly.lock(msg.sender, _btrflyAmt);

        emit Relock(msg.sender, _btrflyAmt);
    }

//3 distribute
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

    function getPendingETHReward(address _user) public view returns (uint256)
    {
        return (balanceOf(_user) * (rewardPerBBC - claimedEpochs[_user]));
    }
    
    function _claimEthRewards(address _user) internal nonReentrant{
        uint256 currentRewards = getPendingETHReward(_user);
        if (currentRewards > 0) {
            allocatedEthRewards = allocatedEthRewards - currentRewards;
            claimedEpochs[_user] = rewardPerBBC;
            payable(msg.sender).transfer(currentRewards);
        }
    }

    function claimEthRewards(address _user) external{
        require(balanceOf(_user) > 0, "Can only claim if balance of user > 0");
        _claimEthRewards(_user);
    }

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
