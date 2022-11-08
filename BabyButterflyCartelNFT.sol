// SPDX-License-Identifier: MIT

//  _            _                      _            
// /_)_  /_     /_)  _/__/__  __/|/    / `_  __/__  /
///_)/_|/_//_/ /_)/_//  / /_'/ / //_/ /_,/_|/ / /_'/ 
//         _/                     _/                 

pragma solidity ^0.8.0;

import "./ERC721A.sol";
import "./IRLBTRFLY.sol";
import "./IREWARDSDISTRIBUTOR.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract BabyButterflyCartelNFT is ERC721A, Ownable {
    using Strings for uint256;
    using SafeERC20 for IERC20;

    uint256 price;
    uint256 priceBtrfly;
    uint16 maxSupply;
    //redacted cartel butterfly address
    address Btrfly;
    IRLBTRFLY public irlbtrfly;
    IREWARDSDISTRIBUTOR public irewardsdistributor;
    
    //test addys
    //[Contracts.BTRFLYV2]: '0x4bc4bba990fe31d529d987f7b8ccf79f1626e559',
    address RLBTRFLYAddress = 0xB4Ce286398C3EeBDE71c63A6A925D7823821c1Ee;
    address IREWARDSDISTRIBUTORAddress = 0xd756DfC1a5AFd5e36Cf88872540778841B318894;
    //real addys
    //[Contracts.BTRFLYV2]: '0xc55126051B22eBb829D00368f4B12Bde432de5Da',
    //[Contracts.RLBTRFLY]: '0x742B70151cd3Bc7ab598aAFF1d54B90c3ebC6027',
    //[Contracts.RewardDistributor]: '0xd7807E5752B368A6a64b76828Aaff0750522a76E',

    //Treasury rewards distrib values 
    uint public rlbutterflyPrincipalBalance;
    uint256 public allocatedRLBTRFLYRewards;
    uint256 public totalhiddenhandrewards;
    //timer
    uint256 public initialTime;

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
    
    constructor(uint16 supply, address btrfly) ERC721A("Baby Butterfly Cartel", "BBC") {
        price = 0.025 ether; //1eth = 40 BTRFLY
        priceBtrfly = 0.025 ether;
        maxSupply = supply;
        Btrfly = btrfly;
        irlbtrfly = IRLBTRFLY(RLBTRFLYAddress);
        irewardsdistributor = IREWARDSDISTRIBUTOR(IREWARDSDISTRIBUTORAddress);
        rlbutterflyPrincipalBalance = 0;
        initialTime = block.timestamp;

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
//1  lock btrfly from this contract to RLBTRFLY
     //send BTRFLY to IRLBTRFLY
    function BTRFLYlock(uint256 amount) external onlyOwner {
        irlbtrfly.lock(address(this), amount);
    }
    //withdrawexpired locks to compound every unlock peroid
    function BTRFLYwithdrawExpiredLocksTo() external onlyOwner{
        irlbtrfly.withdrawExpiredLocksTo(address(this));
        //unlockable
    }

//2 Automatically unlock rewards with timer every 2 weeks.
//address token,
//address account,
//uint256 amount,
//bytes32[] _merkleProof
    function irewardsdistributorclaim(address token, address account, uint256 amount, bytes32[] _merkleProof)  external onlyOwner{
        //get total rewards from reward distributor 
        uint256 nowTime = block.timestamp-initialTime;// time between deployment of contract and now. time since the unix epoch
        console.log(nowTime);
        if (nowTime > 1209600) { //2weeks
            totalhiddenhandrewards = irewardsdistributor.claim(address(msg.sender)); //eth
            console.log("Eth sent to contract ready to distribute please claim your eth rewards");
            return totalhiddenhandrewards;
        }
        //call function using timer peroidically & WHEN BTRFLYlock =TRUE
    }

//3 user can claim rewards 
    function claimrewardsperNFT() external callerIsUser{
        address _owner = msg.sender;
        uint256 numberOfOwnedNFT = balanceOf(_owner);
        //return numberOfOwnedNFT;
        //check much NFT's person owned

        allocatedRLBTRFLYRewards = ((totalhiddenhandrewards/maxSupply)*numberOfOwnedNFT);
        //divide total rewards by number of nfts then multiply per per person

        //IERC20(Btrfly).safeTransferFrom(msg.sender, address(this), allocatedRLBTRFLYRewards);
        //payable(msg.sender).transfer(address(this).balance);
        _owner.transfer(msg.allocatedRLBTRFLYRewards);
        //safe transfer allocated reward
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
