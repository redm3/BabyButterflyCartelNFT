// SPDX-License-Identifier: MIT
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
    address Btrfly;
    IRLBTRFLY public irlbtrfly;
    IRewardDistributor public irewardsdistributor;
    address RLBTRFLYAddress = 0xB4Ce286398C3EeBDE71c63A6A925D7823821c1Ee;
    address IREWARDSDISTRIBUTORAddress = 0xd756DfC1a5AFd5e36Cf88872540778841B318894;
    uint public rewardPerBBC;
    uint public ethprincipalBalance;
    uint public allocatedEthRewards;
    uint public updateCallerReward;
    uint256 public constant MaxPublicMint = 200;
    uint256 public constant MaxWhitelistMint = 500;
    string private baseTokenUri;
    string public placeholderTokenUri;
    bool public isRevealed;
    bool public publicSale;
    bool public whiteListSale;
    bool public pause;
    bytes32 private merkleRoot;
    mapping(address => uint256) public totalPublicMint;
    mapping(address => uint256) public totalWhitelistMint;
    mapping(address => uint) public claimedEpochs;
    event RewardPerBBCUpdated(uint _rpb, address indexed _callerAddress);
    event Relock(address indexed account, uint256 amount);
    event Received(address, uint);
    error ZeroAmount();
    
    constructor(uint16 supply, address btrfly) ERC721A("Baby Butterfly Cartel", "BBC") {
        priceBtrfly = 1 ether;
        maxSupply = supply;
        Btrfly = btrfly;
        ethprincipalBalance = 0;
        allocatedEthRewards = 0;
        rewardPerBBC = 0;
        updateCallerReward = 100;
        irlbtrfly = IRLBTRFLY(RLBTRFLYAddress);
        irewardsdistributor = IRewardDistributor(IREWARDSDISTRIBUTORAddress);
        IERC20(Btrfly).approve(RLBTRFLYAddress, type(uint256).max);
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "callerIsUser");
        _;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function whitelistmintWithBtrfly(bytes32[] memory _merkleProof, uint256 _quantity, uint256 _costBtrfly) external callerIsUser{
        require(whiteListSale, "Minting Paused");
        require((totalSupply() + _quantity) <= maxSupply, "Beyond max supply");
        require((totalWhitelistMint[msg.sender] + _quantity)  <= MaxWhitelistMint, "Beyond whitelist max mint!");
        require(_costBtrfly  == (priceBtrfly * _quantity), "Payment is too low");
        bytes32 sender = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, merkleRoot, sender), "You aren't whitelisted");

        totalWhitelistMint[msg.sender] += _quantity;
        IERC20(Btrfly).safeTransferFrom(msg.sender, address(this), _costBtrfly);
        _safeMint(msg.sender, _quantity);
    }

    function mintWithBtrfly(uint256 _quantity, uint256 _costBtrfly) external callerIsUser{
        require(publicSale, "Not Yet Active.");
        require((totalSupply() + _quantity) <= maxSupply, "Beyond Max Supply");
        require((totalPublicMint[msg.sender] +_quantity) <= MaxPublicMint, "Already minted");
        require(_costBtrfly == (priceBtrfly  * _quantity), "Below ");

        totalPublicMint[msg.sender] += _quantity;
        IERC20(Btrfly).safeTransferFrom(msg.sender, address(this), _costBtrfly);
        _safeMint(msg.sender, _quantity);
    }

    function depositBTRFLYlock(uint256 _btrflyAmt) external onlyOwner {
        irlbtrfly.lock(msg.sender, _btrflyAmt);
    }
    
    function BTRFLYwithdrawExpiredLocksTo() external onlyOwner{
        irlbtrfly.withdrawExpiredLocksTo(msg.sender);
    }

    function claimAndLock(Common.Claim[] calldata claims, uint256 _btrflyAmt) external{
        if (_btrflyAmt == 0) revert ZeroAmount();

        irewardsdistributor.claim(claims);
        IERC20(Btrfly).safeTransferFrom(msg.sender, address(this), _btrflyAmt);
        irlbtrfly.lock(msg.sender, _btrflyAmt);

        emit Relock(msg.sender, _btrflyAmt);
    }

    function updateETHRewardPerBBC() public nonReentrant {
        uint256 ethBal = address(this).balance;
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
        require(balanceOf(_user) > 0, "0");
        _claimEthRewards(_user);
    }


    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenUri;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        uint256 trueId = tokenId + 1;

        if(!isRevealed){
            return placeholderTokenUri;
        }
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

    function setUpdateCallerReward(uint _amt) external onlyOwner{
        require(_amt <= 100, "reward is 1%");
        updateCallerReward = _amt;
    }

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

    function withdraw() external onlyOwner{
        payable(msg.sender).transfer(address(this).balance);
    }

    function collectBtrfly() public onlyOwner{
        uint256 bal = IERC20(Btrfly).balanceOf(address(this));
        IERC20(Btrfly).safeTransfer(owner(), bal);
    }
}
