pragma solidity ^0.4.4;


contract Remittance {

    struct PendingTransfer {
        address sender;
        address intermediary;
        address recipient;
        bytes32 passwordHash;
        uint amount;
        uint deadlineBlockNumber;
    }
    mapping(bytes32 => PendingTransfer) public pendingTransfers;
    bool killed;

    modifier groupOnly(mapping(address => bool) group) {
        require(group[msg.sender] == true);
        _;
    }

    modifier positiveAmount() {
        require(msg.value > 0);
        _;
    }

    modifier alive() {
        require(!killed);
        _;
    }

    mapping(address => bool) owners;
    mapping(address => bool) public whitelistedSenders;

    function Remittance() {
        owners[msg.sender] = true;
    }

    function addOwner(address owner) public groupOnly(owners) alive {
        owners[owner] = true;
    }

    function whitelistSender(address sender) public groupOnly(owners) alive {
        whitelistedSenders[sender] = true;
    }

    function submitTransfer(address recipient,
                            address intermediary,
                            bytes32 passwordHash,
                            uint ttl)
                            public
                            groupOnly(whitelistedSenders)
                            positiveAmount
                            alive
                            payable
                            returns(bytes32 uuid) {
        // transfers are unique by sender, recipient and amount
        uuid = keccak256(recipient, msg.sender, msg.value);
        pendingTransfers[uuid] = PendingTransfer(
            msg.sender,
            intermediary,
            recipient,
            passwordHash,
            msg.value,
            block.number + ttl);
        return uuid;
    }

    function releaseTransfer(bytes32 transferUUID, string password) public alive {
        PendingTransfer memory pendingTransfer = pendingTransfers[transferUUID];
        // only the recipient can release the transfer to the intermediary (like MULTISIG)
        require(msg.sender == pendingTransfer.recipient);
        // given he has the passoword
        require(keccak256(password) == pendingTransfer.passwordHash);
        // TODO: check with condition and delete if expired?
        require(block.number < pendingTransfer.deadlineBlockNumber);
        pendingTransfer.intermediary.transfer(pendingTransfer.amount);
        delete pendingTransfers[transferUUID];
    }

    function kill() public groupOnly(owners) alive {
        killed = true;
    }
}
