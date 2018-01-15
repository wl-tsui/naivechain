pragma solidity ^0.4.19;

contract PlasmaChainManager {
    bytes constant PersonalMessagePrefixBytes = "\x19Ethereum Signed Message:\n68";
    uint32 constant blockNumberLength = 4;
    uint32 constant previousHashLength = 32;
    uint32 constant merkleRootLength = 32;
    uint32 constant sigRLength = 32;
    uint32 constant sigSLength = 32;
    uint32 constant sigVLength = 1;
    uint32 constant blockHeaderLength = 133;
    uint32 constant signedMessageLength = 68;

    struct BlockHeader {
        uint32 blockNumber;
        bytes32 previousHash;
        bytes32 merkleRoot;
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    struct DepositRecord {
        uint32 n;
        uint32 ctr;
    }

    address public owner;
    uint32 public lastBlockNumber;
    uint32 public depositCounter;
    mapping(address => bool) public operators;
    mapping(uint256 => BlockHeader) public headers;
    mapping(address => DepositRecord[]) public depositRecords;

    function PlasmaChainManager() public {
        owner = msg.sender;
        lastBlockNumber = 0;
        depositCounter = 64;
    }

    function extract32(bytes data, uint pos) pure internal returns (bytes32 result) {
        for (uint256 i = 0; i < 32; i++) {
            result ^= (bytes32(0xff00000000000000000000000000000000000000000000000000000000000000)&data[i+pos])>>(i*8);
        }
    }

    function extract4(bytes data, uint pos) pure internal returns (bytes4 result) {
        for (uint256 i = 0; i < 4; i++) {
            result ^= (bytes4(0xff000000)&data[i+pos])>>(i*8);
        }
    }

    function extract1(bytes data, uint pos) pure internal returns (bytes1 result) {
        for (uint256 i = 0; i < 1; i++) {
            result ^= (bytes1(0xff)&data[i+pos])>>(i*8);
        }
    }

    function setOperator(address operator, bool status) public returns (bool success) {
        require(msg.sender == owner);
        operators[operator] = status;
        return true;
    }

    event HeaderSubmittedEvent(address signer, uint32 blockNumber);

    function submitBlockHeader(bytes header) public returns (bool success) {
        require(operators[msg.sender]);
        require(header.length == blockHeaderLength);
        uint32 blockNumber = uint32(extract4(header, 0));
        bytes32 previousHash = extract32(header, 4);
        bytes32 merkleRoot = extract32(header, 36);
        bytes32 sigR = extract32(header, 68);
        bytes32 sigS = extract32(header, 100);
        uint8 sigV = uint8(extract1(header, 132));

        // Check the block number.
        require(blockNumber == lastBlockNumber + 1);

        // Check the signature.
        bytes32 blockHash = keccak256(PersonalMessagePrefixBytes, blockNumber,
            previousHash, merkleRoot);
        if (sigV < 27) {
            sigV += 27;
        }
        address signer = ecrecover(blockHash, sigV, sigR, sigS);
        require(msg.sender == signer);

        // Append the new header.
        BlockHeader memory newHeader = BlockHeader({
            blockNumber: blockNumber,
            previousHash: previousHash,
            merkleRoot: merkleRoot,
            r: sigR,
            s: sigS,
            v: sigV
        });
        headers[blockNumber] = newHeader;

        // Increment the block number by 1 and reset the deposit counter.
        lastBlockNumber += 1;
        depositCounter = 64;
        HeaderSubmittedEvent(signer, blockNumber);
        return true;
    }

    event DepositEvent(address from, uint256 amount, uint32 indexed n, uint32 ctr);

    function deposit() payable public returns (bool success) {
        require(msg.value == 1 ether);

        DepositRecord memory newDeposit = DepositRecord({
            n: lastBlockNumber,
            ctr: depositCounter
        });
        depositRecords[msg.sender].push(newDeposit);
        depositCounter += 1;
        DepositEvent(msg.sender, msg.value, newDeposit.n, newDeposit.ctr);
        return true;
    }
}