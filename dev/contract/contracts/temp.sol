pragma solidity ^0.4.24;

// external modules
// import "./SafeMath.sol";
// import "./RLPEncoding.sol";
// import "./StemCore.sol";
// import "./StemRelay.sol";
// import "./StemChallenge.sol";
// import "./StemCreation.sol";



library ECRecovery {

  /**
   * @dev Recover signer address from a message by using his signature
   * @param hash bytes32 message, the hash is the signed message. What is recovered is the signer address.
   * @param sig bytes signature, the signature is generated using web3.eth.sign()
   */
  function recover(bytes32 hash, bytes sig) public pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        //Check the signature length
        if (sig.length != 65) {
            return (address(0));
        }

        // Divide the signature in r, s and v variables
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
            // v := and(mload(add(sig, 65)), 255)
        }

        // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
        if (v < 27) {
            v += 27;
        }

        // If the version is correct return the signer address
        if (v != 27 && v != 28) {
            return (address(0));
        } else {
            return ecrecover(hash, v, r, s);
        }
    }

}

library Merkle {
    /*
     * Storage
     */


    /*
     * Internal functions
     */

    /**
     * @dev Checks that a leaf hash is contained in a root hash.
     * @param leaf Leaf hash to verify.
     * @param index Position of the leaf hash in the Merkle tree.
     * @param rootHash Root of the Merkle tree.
     * @param proof A Merkle proof demonstrating membership of the leaf hash.
     * @return True of the leaf hash is in the Merkle tree. False otherwise.
    */
    function checkMembership(bytes32 leaf, uint256 index, bytes32 rootHash, bytes proof)
        internal
        pure
        returns (bool)
    {
        require(proof.length % 32 == 0);

        bytes32 proofElement;
        bytes32 computedHash = leaf;
        uint256 j = index;
        // NOTE: we're skipping the first 32 bytes of `proof`, which holds the size of the dynamically sized `bytes`
        for (uint256 i = 32; i <= proof.length; i += 32) {
            assembly {
                proofElement := mload(add(proof, i))
            }
            if (j % 2 == 0) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
            j = j / 2;
        }

        return computedHash == rootHash;
    }
}

library RLP {
    /*
     * Storage
     */

    uint internal constant DATA_SHORT_START = 0x80;
    uint internal constant DATA_LONG_START = 0xB8;
    uint internal constant LIST_SHORT_START = 0xC0;
    uint internal constant LIST_LONG_START = 0xF8;

    uint internal constant DATA_LONG_OFFSET = 0xB7;
    uint internal constant LIST_LONG_OFFSET = 0xF7;

    struct RLPItem {
        uint _unsafe_memPtr;    // Pointer to the RLP-encoded bytes.
        uint _unsafe_length;    // Number of bytes. This is the full length of the string.
    }

    struct Iterator {
        RLPItem _unsafe_item;   // Item that's being iterated over.
        uint _unsafe_nextPtr;   // Position of the next item in the list.
    }


    /*
     * Internal functions
     */

    /**
     * @dev Creates an RLPItem from an array of RLP encoded bytes.
     * @param self The RLP encoded bytes.
     * @return An RLPItem.
     */
    function toRLPItem(bytes memory self)
        internal
        pure
        returns (RLPItem memory)
    {
        uint len = self.length;
        if (len == 0) {
            return RLPItem(0, 0);
        }
        uint memPtr;
        assembly {
            memPtr := add(self, 0x20)
        }
        return RLPItem(memPtr, len);
    }

    /**
     * @dev Creates an RLPItem from an array of RLP encoded bytes.
     * @param self The RLP encoded bytes.
     * @param strict Will throw if the data is not RLP encoded.
     * @return An RLPItem
     */
    function toRLPItem(bytes memory self, bool strict)
        internal
        pure
        returns (RLPItem memory)
    {
        RLPItem memory item = toRLPItem(self);
        if (strict) {
            uint len = self.length;
            if (_payloadOffset(item) > len) {
                revert();
            }
            if (_itemLength(item._unsafe_memPtr) != len) {
                revert();
            }
            if (!_validate(item)) {
                revert();
            }
        }
        return item;
    }

    /**
     * @dev Check if the RLP item is null.
     * @param self The RLP item.
     * @return 'true' if the item is null.
     */
    function isNull(RLPItem memory self)
        internal
        pure
        returns (bool ret)
    {
        return self._unsafe_length == 0;
    }

    /**
     * @dev Check if the RLP item is a list.
     * @param self The RLP item.
     * @return 'true' if the item is a list.
     */
    function isList(RLPItem memory self)
        internal
        pure
        returns (bool ret)
    {
        if (self._unsafe_length == 0) {
            return false;
        }
        uint memPtr = self._unsafe_memPtr;
        assembly {
            ret := iszero(lt(byte(0, mload(memPtr)), 0xC0))
        }
    }

    /**
     * @dev Check if the RLP item is data.
     * @param self The RLP item.
     * @return 'true' if the item is data.
     */
    function isData(RLPItem memory self)
        internal
        pure
        returns (bool ret)
    {
        if (self._unsafe_length == 0) {
            return false;
        }
        uint memPtr = self._unsafe_memPtr;
        assembly {
            ret := lt(byte(0, mload(memPtr)), 0xC0)
        }
    }

    /**
     * @dev Check if the RLP item is empty (string or list).
     * @param self The RLP item.
     * @return 'true' if the item is null.
     */
    function isEmpty(RLPItem memory self)
        internal
        pure
        returns (bool ret)
    {
        if (isNull(self)) {
            return false;
        }
        uint b0;
        uint memPtr = self._unsafe_memPtr;
        assembly {
            b0 := byte(0, mload(memPtr))
        }
        return (b0 == DATA_SHORT_START || b0 == LIST_SHORT_START);
    }

    /**
     * @dev Get the number of items in an RLP encoded list.
     * @param self The RLP item.
     * @return The number of items.
     */
    function items(RLPItem memory self)
        internal
        pure
        returns (uint)
    {
        if (!isList(self)) {
            return 0;
        }
        uint b0;
        uint memPtr = self._unsafe_memPtr;
        assembly {
            b0 := byte(0, mload(memPtr))
        }
        uint pos = memPtr + _payloadOffset(self);
        uint last = memPtr + self._unsafe_length - 1;
        uint itms;
        while (pos <= last) {
            pos += _itemLength(pos);
            itms++;
        }
        return itms;
    }

    /**
     * @dev Create an iterator.
     * @param self The RLP item.
     * @return An 'Iterator' over the item.
     */
    function iterator(RLPItem memory self)
        internal
        pure
        returns (Iterator memory it)
    {
        if (!isList(self)) {
            revert();
        }
        uint ptr = self._unsafe_memPtr + _payloadOffset(self);
        it._unsafe_item = self;
        it._unsafe_nextPtr = ptr;
    }

    /**
     * @dev Return the RLP encoded bytes.
     * @param self The RLPItem.
     * @return The bytes.
     */
    function toBytes(RLPItem memory self)
        internal
        pure
        returns (bytes memory bts)
    {
        uint len = self._unsafe_length;
        if (len == 0) {
            return;
        }
        bts = new bytes(len);
        _copyToBytes(self._unsafe_memPtr, bts, len);
    }

    /**
     * @dev Decode an RLPItem into bytes. This will not work if the RLPItem is a list.
     * @param self The RLPItem.
     * @return The decoded string.
     */
    function toData(RLPItem memory self)
        internal
        pure
        returns (bytes memory bts)
    {
        if (!isData(self)) {
            revert();
        }
        uint rStartPos;
        uint len;
        (rStartPos, len) = _decode(self);
        bts = new bytes(len);
        _copyToBytes(rStartPos, bts, len);
    }

    /**
     * @dev Get the list of sub-items from an RLP encoded list.
     * Warning: This is inefficient, as it requires that the list is read twice.
     * @param self The RLP item.
     * @return Array of RLPItems.
     */
    function toList(RLPItem memory self)
        internal
        pure
        returns (RLPItem[] memory list)
    {
        if (!isList(self)) {
            revert();
        }
        uint numItems = items(self);
        list = new RLPItem[](numItems);
        Iterator memory it = iterator(self);
        uint idx;
        while (_hasNext(it)) {
            list[idx] = _next(it);
            idx++;
        }
    }

    /**
     * @dev Decode an RLPItem into an ascii string. This will not work if the RLPItem is a list.
     * @param self The RLPItem.
     * @return The decoded string.
     */
    function toAscii(RLPItem memory self)
        internal
        pure
        returns (string memory str)
    {
        if (!isData(self)) {
            revert();
        }
        uint rStartPos;
        uint len;
        (rStartPos, len) = _decode(self);
        bytes memory bts = new bytes(len);
        _copyToBytes(rStartPos, bts, len);
        str = string(bts);
    }

    /**
     * @dev Decode an RLPItem into a uint. This will not work if the RLPItem is a list.
     * @param self The RLPItem.
     * @return The decoded string.
     */
    function toUint(RLPItem memory self)
        internal
        pure
        returns (uint data)
    {
        if (!isData(self)) {
            revert();
        }
        uint rStartPos;
        uint len;
        (rStartPos, len) = _decode(self);
        if (len > 32) {
            revert();
        }
        assembly {
            data := div(mload(rStartPos), exp(256, sub(32, len)))
        }
    }

    /**
     * @dev Decode an RLPItem into a boolean. This will not work if the RLPItem is a list.
     * @param self The RLPItem.
     * @return The decoded string.
     */
    function toBool(RLPItem memory self)
        internal
        pure
        returns (bool data)
    {
        if (!isData(self)) {
            revert();
        }
        uint rStartPos;
        uint len;
        (rStartPos, len) = _decode(self);
        if (len != 1) {
            revert();
        }
        uint temp;
        assembly {
            temp := byte(0, mload(rStartPos))
        }
        if (temp > 1) {
            revert();
        }
        return temp == 1 ? true : false;
    }

    /**
     * @dev Decode an RLPItem into a byte. This will not work if the RLPItem is a list.
     * @param self The RLPItem.
     * @return The decoded string.
     */
    function toByte(RLPItem memory self)
        internal
        pure
        returns (byte data)
    {
        if (!isData(self)) {
            revert();
        }
        uint rStartPos;
        uint len;
        (rStartPos, len) = _decode(self);
        if (len != 1) {
            revert();
        }
        uint temp;
        assembly {
            temp := byte(0, mload(rStartPos))
        }
        return byte(temp);
    }

    /**
     * @dev Decode an RLPItem into an int. This will not work if the RLPItem is a list.
     * @param self The RLPItem.
     * @return The decoded string.
     */
    function toInt(RLPItem memory self)
        internal
        pure
        returns (int data)
    {
        return int(toUint(self));
    }

    /**
     * @dev Decode an RLPItem into a bytes32. This will not work if the RLPItem is a list.
     * @param self The RLPItem.
     * @return The decoded string.
     */
    function toBytes32(RLPItem memory self)
        internal
        pure
        returns (bytes32 data)
    {
        return bytes32(toUint(self));
    }

    /**
     * @dev Decode an RLPItem into an address. This will not work if the RLPItem is a list.
     * @param self The RLPItem.
     * @return The decoded string.
     */
    function toAddress(RLPItem memory self)
        internal
        pure
        returns (address data)
    {
        if (!isData(self)) {
            revert();
        }
        uint rStartPos;
        uint len;
        (rStartPos, len) = _decode(self);
        if (len != 20) {
            revert();
        }
        assembly {
            data := div(mload(rStartPos), exp(256, 12))
        }
    }


    /*
     * Private functions
     */

    /**
     * @dev Returns the next RLP item for some iterator.
     * @param self The iterator.
     * @return The next RLP item.
     */
    function _next(Iterator memory self)
        private
        pure
        returns (RLPItem memory subItem)
    {
        if (_hasNext(self)) {
            uint ptr = self._unsafe_nextPtr;
            uint itemLength = _itemLength(ptr);
            subItem._unsafe_memPtr = ptr;
            subItem._unsafe_length = itemLength;
            self._unsafe_nextPtr = ptr + itemLength;
        } else {
            revert();
        }
    }

    /**
     * @dev Returns the next RLP item for some iterator and validates it.
     * @param self The iterator.
     * @return The next RLP item.
     */
    function _next(Iterator memory self, bool strict)
        private
        pure
        returns (RLPItem memory subItem)
    {
        subItem = _next(self);
        if (strict && !_validate(subItem)) {
            revert();
        }
        return;
    }

    /**
     * @dev Checks if an iterator has a next RLP item.
     * @param self The iterator.
     * @return True if the iterator has an RLP item. False otherwise.
     */
    function _hasNext(Iterator memory self)
        private
        pure
        returns (bool)
    {
        RLPItem memory item = self._unsafe_item;
        return self._unsafe_nextPtr < item._unsafe_memPtr + item._unsafe_length;
    }

    /**
     * @dev Determines the payload offset of some RLP item.
     * @param self RLP item to query.
     * @return The payload offset for that item.
     */
    function _payloadOffset(RLPItem memory self)
        private 
        pure
        returns (uint)
    {
        if (self._unsafe_length == 0) {
            return 0;
        }
        uint b0;
        uint memPtr = self._unsafe_memPtr;
        assembly {
            b0 := byte(0, mload(memPtr))
        }
        if (b0 < DATA_SHORT_START) {
            return 0;
        }
        if (b0 < DATA_LONG_START || (b0 >= LIST_SHORT_START && b0 < LIST_LONG_START)) {
            return 1;
        }
        if (b0 < LIST_SHORT_START) {
            return b0 - DATA_LONG_OFFSET + 1;
        }
        return b0 - LIST_LONG_OFFSET + 1;
    }

    /**
     * @dev Determines the length of an RLP item.
     * @param memPtr Pointer to the start of the item.
     * @return Length of the item.
     */
    function _itemLength(uint memPtr)
        private
        pure
        returns (uint len)
    {
        uint b0;
        assembly {
            b0 := byte(0, mload(memPtr))
        }
        if (b0 < DATA_SHORT_START) {
            len = 1;
        }
        else if (b0 < DATA_LONG_START) {
            len = b0 - DATA_SHORT_START + 1;
        }
        else if (b0 < LIST_SHORT_START) {
            assembly {
                let bLen := sub(b0, 0xB7) // bytes length (DATA_LONG_OFFSET)
                let dLen := div(mload(add(memPtr, 1)), exp(256, sub(32, bLen))) // data length
                len := add(1, add(bLen, dLen)) // total length
            }
        }
        else if (b0 < LIST_LONG_START) {
            len = b0 - LIST_SHORT_START + 1;
        }
        else {
            assembly {
                let bLen := sub(b0, 0xF7) // bytes length (LIST_LONG_OFFSET)
                let dLen := div(mload(add(memPtr, 1)), exp(256, sub(32, bLen))) // data length
                len := add(1, add(bLen, dLen)) // total length
            }
        }
    }

    /**
     * @dev Determines the start position and length of some RLP item.
     * @param self RLP item to query.
     * @return A pointer to the beginning of the item and the length of that item.
     */
    function _decode(RLPItem memory self)
        private
        pure
        returns (uint memPtr, uint len)
    {
        if (!isData(self)) {
            revert();
        }
        uint b0;
        uint start = self._unsafe_memPtr;
        assembly {
            b0 := byte(0, mload(start))
        }
        if (b0 < DATA_SHORT_START) {
            memPtr = start;
            len = 1;
            return;
        }
        if (b0 < DATA_LONG_START) {
            len = self._unsafe_length - 1;
            memPtr = start + 1;
        } else {
            uint bLen;
            assembly {
                bLen := sub(b0, 0xB7) // DATA_LONG_OFFSET
            }
            len = self._unsafe_length - 1 - bLen;
            memPtr = start + bLen + 1;
        }
        return;
    }

    /**
     * @dev Copies some data to a certain target.
     * @param btsPtr Pointer to the data to copy.
     * @param tgt Place to copy.
     * @param btsLen How many bytes to copy.
     */
    function _copyToBytes(uint btsPtr, bytes memory tgt, uint btsLen)
        private
        pure
    {
        // Exploiting the fact that 'tgt' was the last thing to be allocated,
        // we can write entire words, and just overwrite any excess.
        assembly {
            {
                let i := 0 // Start at arr + 0x20
                let words := div(add(btsLen, 31), 32)
                let rOffset := btsPtr
                let wOffset := add(tgt, 0x20)
                /*tag_loop:
                    jumpi(end, eq(i, words))
                    {
                        let offset := mul(i, 0x20)
                        mstore(add(wOffset, offset), mload(add(rOffset, offset)))
                        i := add(i, 1)
                    }
                    jump(tag_loop)
                end:
                    mstore(add(tgt, add(0x20, mload(tgt))), 0)*/
                for {} lt(eq(i, words), 1) {}{
                    let offset := mul(i, 0x20)
                    mstore(add(wOffset, offset), mload(add(rOffset, offset)))
                    i := add(i, 1)
                }
                mstore(add(tgt, add(0x20, mload(tgt))), 0)
            }
        }
    }

    /**
     * @dev Checks that an RLP item is valid.
     * @param self RLP item to validate.
     * @return True if the RLP item is well-formed. False otherwise.
     */
    function _validate(RLPItem memory self)
        private
        pure
        returns (bool ret)
    {
        // Check that RLP is well-formed.
        uint b0;
        uint b1;
        uint memPtr = self._unsafe_memPtr;
        assembly {
            b0 := byte(0, mload(memPtr))
            b1 := byte(1, mload(memPtr))
        }
        if (b0 == DATA_SHORT_START + 1 && b1 < DATA_SHORT_START) {
            return false;
        }
        return true;
    }
}

library RLPEncoding {
    /*
     * Internal functions
     */

    /**
     * @dev RLP encodes a byte string.
     * @param self The byte string to encode.
     * @return The RLP encoded string in bytes.
     */
    function encodeBytes(bytes memory self) internal pure returns (bytes memory) {
        bytes memory encoded;
        if (self.length == 1 && uint8(self[0]) <= 128) {
            encoded = self;
        } else {
            encoded = concat(encodeLength(self.length, 128), self);
        }
        return encoded;
    }

    /**
     * @dev RLP encodes a list of RLP encoded byte byte strings.
     * @param self The list of RLP encoded byte strings.
     * @return The RLP encoded list of items in bytes.
     */
    function encodeList(bytes[] memory self) internal pure returns (bytes memory) {
        bytes memory list = flatten(self);
        return concat(encodeLength(list.length, 192), list);
    }

    /**
     * @dev RLP encodes a string.
     * @param self The string to encode.
     * @return The RLP encoded string in bytes.
     */
    function encodeString(string memory self) internal pure returns (bytes memory) {
        return encodeBytes(bytes(self));
    }

    /**
     * @dev RLP encodes an address.
     * @param self The address to encode.
     * @return The RLP encoded address in bytes.
     */
    function encodeAddress(address self) internal pure returns (bytes memory) {
        bytes memory inputBytes;
        assembly {
            let m := mload(0x40)
            mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, self))
            mstore(0x40, add(m, 52))
            inputBytes := m
        }
        return encodeBytes(inputBytes);
    }

    /**
     * @dev RLP encodes a uint.
     * @param self The uint to encode.
     * @return The RLP encoded uint in bytes.
     */
    function encodeUint(uint self) internal pure returns (bytes memory) {
        return encodeBytes(toBinary(self));
    }

    /**
     * @dev RLP encodes an int.
     * @param self The int to encode.
     * @return The RLP encoded int in bytes.
     */
    function encodeInt(int self) internal pure returns (bytes memory) {
        return encodeUint(uint(self));
    }

    /**
     * @dev RLP encodes a bool.
     * @param self The bool to encode.
     * @return The RLP encoded bool in bytes.
     */
    function encodeBool(bool self) internal pure returns (bytes memory) {
        bytes memory encoded = new bytes(1);
        encoded[0] = (self ? bytes1(0x01) : bytes1(0x80));
        return encoded;
    }


    /*
     * Private functions
     */

    /**
     * @dev Encode the first byte, followed by the `len` in binary form if `length` is more than 55.
     * @param len The length of the string or the payload.
     * @param offset 128 if item is string, 192 if item is list.
     * @return RLP encoded bytes.
     */
    function encodeLength(uint len, uint offset) private pure returns (bytes memory) {
        bytes memory encoded;
        if (len < 56) {
            encoded = new bytes(1);
            encoded[0] = byte(uint8(len) + uint8(offset));
        } else {
            uint lenLen;
            uint i = 1;
            while (len / i != 0) {
                lenLen++;
                i *= 256;
            }

            encoded = new bytes(lenLen + 1);
            encoded[0] = byte(uint8(lenLen) + uint8(offset) + 55);
            for(i = 1; i <= lenLen; i++) {
                encoded[i] = byte(uint8((len / (256**(lenLen-i))) % 256));
            }
        }
        return encoded;
    }

    /**
     * @dev Encode integer in big endian binary form with no leading zeroes.
     * @notice TODO: This should be optimized with assembly to save gas costs.
     * @param _x The integer to encode.
     * @return RLP encoded bytes.
     */
    function toBinary(uint _x) private pure returns (bytes memory) {
        bytes memory b = new bytes(32);
        assembly {
            mstore(add(b, 32), _x)
        }
        uint i = 0;
        for (; i < 32; i++) {
            if (b[i] != 0) {
                break;
            }
        }
        bytes memory res = new bytes(32 - i);
        for (uint j = 0; j < res.length; j++) {
            res[j] = b[i++];
        }
        return res;
    }

    /**
     * @dev Copies a piece of memory to another location.
     * @notice From: https://github.com/Arachnid/solidity-stringutils/blob/master/src/strings.sol.
     * @param _dest Destination location.
     * @param _src Source location.
     * @param _len Length of memory to copy.
     */
    function memcpy(uint _dest, uint _src, uint _len) private pure {
        uint dest = _dest;
        uint src = _src;
        uint len = _len;

        for(; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    /**
     * @dev Flattens a list of byte strings into one byte string.
     * @notice From: https://github.com/sammayo/solidity-rlp-encoder/blob/master/RLPEncode.sol.
     * @param _list List of byte strings to flatten.
     * @return The flattened byte string.
     */
    function flatten(bytes[] memory _list) private pure returns (bytes memory) {
        if (_list.length == 0) {
            return new bytes(0);
        }

        uint len;
        uint i = 0;
        for (; i < _list.length; i++) {
            len += _list[i].length;
        }

        bytes memory flattened = new bytes(len);
        uint flattenedPtr;
        assembly { flattenedPtr := add(flattened, 0x20) }

        for(i = 0; i < _list.length; i++) {
            bytes memory item = _list[i];

            uint listPtr;
            assembly { listPtr := add(item, 0x20)}

            memcpy(flattenedPtr, listPtr, item.length);
            flattenedPtr += _list[i].length;
        }

        return flattened;
    }

    /**
     * @dev Concatenates two bytes.
     * @notice From: https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol.
     * @param _preBytes First byte string.
     * @param _postBytes Second byte string.
     * @return Both byte string combined.
     */
    //function concat(bytes memory _preBytes, bytes memory _postBytes) private pure returns (bytes memory) {
    function concat(bytes memory _preBytes, bytes memory _postBytes) public pure returns (bytes memory) {
        bytes memory tempBytes;

        assembly {
            tempBytes := mload(0x40)

            let length := mload(_preBytes)
            mstore(tempBytes, length)

            let mc := add(tempBytes, 0x20)
            let end := add(mc, length)

            for {
                let cc := add(_preBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            length := mload(_postBytes)
            mstore(tempBytes, add(length, mload(tempBytes)))

            mc := end
            end := add(mc, length)

            for {
                let cc := add(_postBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            mstore(0x40, and(
              add(add(end, iszero(add(length, mload(_preBytes)))), 31),
              not(31)
            ))
        }

        return tempBytes;
    }
}

library SafeMath {
  
  /**
  * @dev Multiplies two numbers, reverts on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }
    
    uint256 c = a * b;
    require(c / a == b);
    
    return c;
  }
  
  /**
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    
    return c;
  }
  
  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;
    
    return c;
  }
  
  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    
    return c;
  }
  
  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}

library StemChallenge {
    using RLP for bytes;
    using RLP for RLP.RLPItem;
    using RLPEncoding for address;
    using RLPEncoding for uint256;
    using RLPEncoding for bytes[];
    using SafeMath for uint256;

    event BlockChallenge(address challengeTarget, uint256 blkNum);
    event RemoveBlockChallenge(uint challengeIndex);
    /**
    * @dev Process new child block challenge
    * @param _encodedAddresses  Msg sender and the challenge target
    * @param _inspecBlock  The block containing the inspec tx (structure: creator/txTreeRoot/stateTreeRoot)
    * @param _inspecBlockSignature  The block signature signed by the block producer
    * @param _inspecTxHash  The tx hash provided by the challenger(default 0x0)
    * @param _inspecState   The state of the target address after the inspec tx
    * @param _indices  0._inspecTxIndex The tx index in the merkle tree; 1._inspecStateIndex The state index in the merkle tree
    * @param _inclusionProofs 0. The proof showing _inspecTxHash is included in _inspecBlock; 1._stateInclusionProof The proof showing _inspecState is in _inspecBlock
     */
    function processChallenge(StemCore.ChainStorage storage self, bytes _encodedAddresses, bytes _inspecBlock, bytes _inspecBlockSignature, bytes32 _inspecTxHash, bytes _inspecState, bytes _indices, bytes _inclusionProofs) 
    public {
        // make sure it is within challenge submission period
        require(block.timestamp.sub(self.childBlocks[self.lastChildBlockNum].timestamp) <= self.childBlockChallengeSubmissionPeriod, "Not in challenge submission period");

        RLP.RLPItem[] memory addresses = _encodedAddresses.toRLPItem().toList();
        RLP.RLPItem[] memory indices = _indices.toRLPItem().toList();
        RLP.RLPItem[] memory proofs = _inclusionProofs.toRLPItem().toList();
        // Challenge target must exist.
        require(self.isExistedUsers[addresses[1].toAddress()] || self.isExistedOperators[addresses[1].toAddress()], "The challenge target doesn't exist!");

        if (_inspecBlock.length > 0) {
            // decode _inspecBlock
            StemCore.InspecBlock memory decodedBlock = decode(_inspecBlock);
            require(self.isExistedOperators[decodedBlock.creator], "The block is not created by existing operators");
            require(decodedBlock.creator == ECRecovery.recover(keccak256(_inspecBlock), _inspecBlockSignature), "Invalid signature");
            require(Merkle.checkMembership(_inspecTxHash, indices[0].toUint(), decodedBlock.txTreeRoot, proofs[0].toData()), "Failed to prove the inclusion of the tx");
            // get the hash of the state
            require(Merkle.checkMembership(keccak256(_inspecState), indices[1].toUint(), decodedBlock.balanceTreeRoot, proofs[1].toData()), "Failed to prove the inclusion of the state");
            //TODO consider the case that _inspecTxHash is nil
            createChildBlockChallenge(self, addresses[0].toAddress(), addresses[1].toAddress(), _inspecTxHash, _inspecState);
        } else {
            createChildBlockChallenge(self, addresses[0].toAddress(), addresses[1].toAddress(), bytes32(0), "");
        }
    }

    /**
    * @dev Create new child block challenge
    * @param _challengerAddress The address of the challenger
    * @param _challengeTarget The challenge target
    * @param _inspecTxHash  The tx hash provided by the challenger(default 0x0)
    * @param _inspecState   The state of the target address after the inspec tx
     */
    function createChildBlockChallenge(StemCore.ChainStorage storage self, address _challengerAddress, address _challengeTarget, bytes32 _inspecTxHash, bytes _inspecState) internal {
        StemCore.ChildBlockChallenge memory newChallenge = StemCore.ChildBlockChallenge({
            challengerAddress: _challengerAddress,
            challengeTarget: _challengeTarget,
            inspecTxHash: _inspecTxHash,
            inspecState: _inspecState
        });
        uint192 challengeId = getBlockChallengeId(_challengerAddress, _challengeTarget, self.lastChildBlockNum);
        self.childBlockChallenges[challengeId] = newChallenge;
        self.childBlockChallengeId.push(challengeId);
        emit BlockChallenge(_challengeTarget, self.lastChildBlockNum);
    }

   /**
    * @dev Clear existing child block challenges
    */
    function clearExistingBlockChallenges(StemCore.ChainStorage storage self) internal {
        for (uint i = 0; i < self.childBlockChallengeId.length; i++) {
            // return challenge bond to the challengers
            self.childBlockChallenges[self.childBlockChallengeId[i]].challengerAddress.transfer(self.blockChallengeBond);
            delete self.childBlockChallenges[self.childBlockChallengeId[i]];
        }
        delete self.childBlockChallengeId;
    }

     /**
    * @dev get an ID for the input block challenge
    * @param _challengerAddress Is the challenger's address
    * @param _challengeTarget Is the target account to challenge
    * @param _blkNum Is the child block number to challenge
    * @return the id of the input block challenge
    */
    function getBlockChallengeId(address _challengerAddress, address _challengeTarget, uint256 _blkNum) internal pure returns (uint192) {
       return computeId(keccak256(abi.encodePacked(_challengerAddress, _challengeTarget)), _blkNum);
    }

    /**
    * @dev get Id for the input info
    * @param _infoHash A hash of the information
    * @param _pos Extra info
    * @return computed ID
    */
    function computeId(bytes32 _infoHash, uint256 _pos) internal pure returns (uint192)
    {
        return uint192((uint256(_infoHash) >> 105) | (_pos << 152));
    }

    /**
    * @dev Handle the response to block challenges. If the response is valid, remove the corresponding challenge
    * @param _challengeIndex The index of the challenge(TODO: change it the challenge ID)
    * @param _recentTxs Txs during the last interval
    * @param _signatures Tx signatures
    * @param _indices   The indices of the leaves in the merkle trees (tx tree/previous State tree/new state tree)
    * @param _preState  RLP encoded previous state (account:balance:nonce)
    * @param _inclusionProofs The inclusion proofs of rencentTxs/previous State/Current State
     */
    function handleResponseToChallenge(StemCore.ChainStorage storage self, uint _challengeIndex, bytes _recentTxs, bytes _signatures, bytes _indices, bytes _preState, bytes _inclusionProofs, address _msgSender) public {
        //require(block.timestamp.sub(self.childBlocks[self.lastChildBlockNum].timestamp) <= self.childBlockChallengePeriod, "Not in challenge period");
        require(self.childBlockChallengeId.length > _challengeIndex, "Invalid challenge index");
        // 0: txLeafIndex, 1: preStateLeafIndex, 2: stateLeafIndex
        RLP.RLPItem[] memory indices = _indices.toRLPItem().toList();
        RLP.RLPItem[] memory proofs = _inclusionProofs.toRLPItem().toList();
        // verify the state of target account before applying recent txs
        //verifyPreState(self, _preState, proofs[1].toData(), indices[1].toUint());
        require(Merkle.checkMembership(keccak256(_recentTxs), indices[0].toUint(), self.childBlocks[self.lastChildBlockNum].txTreeRoot, proofs[0].toData()), "Failed to prove the inclusion of the txs");
        // verify recent txs and get the expected current balance
        bytes memory actualState = verifyRecentTxs(self, _challengeIndex, _preState, _recentTxs.toRLPItem().toList(), _signatures.toRLPItem().toList());

        // encode actualState
        require(Merkle.checkMembership(keccak256(actualState), indices[1].toUint(), self.childBlocks[self.lastChildBlockNum].balanceTreeRoot, proofs[2].toData()), "Failed to prove the inclusion of the state");

        // respond to the block challenge successfully
        //_msgSender.transfer(self.blockChallengeBond);
        // for test only
        _msgSender = 0x583031D1113aD414F02576BD6afaBfb302140225;
        _msgSender.transfer(self.blockChallengeBond);
        removeChildBlockChallengeByIndex(self, _challengeIndex);
        emit RemoveBlockChallenge(_challengeIndex);
    }

     /**
    * @dev verify the inclusion of target state in the last confirmed state tree
    * @param _preState The state of target account in last confirmed child block
    * @param _preStateInclusionProof The merkle proof for the inclusion of the state
    * @param _preStateIndex The index of the state in the state tree
    */
    function verifyPreState(StemCore.ChainStorage storage self, bytes _preState, bytes _preStateInclusionProof, uint256 _preStateIndex) internal view {
        uint256 lastConfirmedBlkNum = StemCore.getLastConfirmedChildBlockNumber(self);
        require(Merkle.checkMembership(keccak256(_preState), _preStateIndex, self.childBlocks[lastConfirmedBlkNum].balanceTreeRoot, _preStateInclusionProof));
        // TODO compare preState balance with the balance at last confirmed block (operaters[account] or users[account])
    }

     /**
    * @dev Verify txs of target account during last interval
    * @param _challengeIndex The index of the challenge
    * @param _preState The state of target account at the beginning of last interval
    * @param _splitRecentTxs The transactions of target account during last interval
    * @param _splitSignatures The signatures of the tx senders
    * @return the balance of target account after applying all txs
    */
    function verifyRecentTxs(StemCore.ChainStorage storage self, uint _challengeIndex, bytes _preState, RLP.RLPItem[] memory _splitRecentTxs, RLP.RLPItem[] memory _splitSignatures) internal view returns(bytes) {

        StemCore.ChildBlockChallenge memory challenge = self.childBlockChallenges[self.childBlockChallengeId[_challengeIndex]];

        require(_splitRecentTxs.length == _splitSignatures.length);

        RLP.RLPItem[] memory decodedPreState = _preState.toRLPItem().toList();
        require(challenge.challengeTarget == decodedPreState[0].toAddress());

        uint256 tempBalance = decodedPreState[1].toUint();
        uint256 tempNonce = decodedPreState[2].toUint();
        uint256 inspecTxCount = 0;
        RLP.RLPItem[] memory decodedInspecState;
        for (uint i = 0; i < _splitRecentTxs.length; i++) {
            tempBalance = _verifySingleTx(tempBalance, tempNonce, challenge.challengeTarget, _splitRecentTxs[i], _splitSignatures[i]);
            tempNonce = tempNonce.add(1);
            //TODO consider the case that inspecTxHash is nil
            if (challenge.inspecTxHash == keccak256(_splitRecentTxs[i].toBytes())) {
                inspecTxCount = inspecTxCount.add(1);
                //TODO: require tempBalance to be in a reasonable range
                decodedInspecState = challenge.inspecState.toRLPItem().toList();
                require(tempBalance == decodedInspecState[1].toUint());
            }
        }

        // require recent txs to include inspec tx
        if (challenge.inspecTxHash != bytes32(0)) { 
            require(inspecTxCount == uint256(1));
        }
        // TODO compare tempBalance with the balance of the target account (operaters[account] or users[account])
        return _encodeState(challenge.challengeTarget, tempBalance, tempNonce);
    }

    /**
    * @dev RLP encode account, balance and nonce into an account state
    * @param _account Account
    * @param _balance Balance
    * @param _nonce  Nonce
    * @return the bytes of the RLP encoded state
     */
    function _encodeState(address _account, uint256 _balance, uint256 _nonce) internal pure returns(bytes) {
        bytes[] memory stateArray = new bytes[](3);
        stateArray[0] = _account.encodeAddress();
        stateArray[1] = _balance.encodeUint();
        stateArray[2] = _nonce.encodeUint();
        return stateArray.encodeList();
    }

    /**
    * @dev Verify the signature and amount of a single tx
    * @param _balanceBeforeTx The balance of target account before tx
    * @param _nonceBeforeTx The nonce of target account before tx
    * @param _targetAccount The account the challenger wants to examine
    * @param _tx The transaction
    * @param _signature The signature of the tx sender
    * @return the balance of target account after tx
    */
    function _verifySingleTx(uint256 _balanceBeforeTx, uint256 _nonceBeforeTx, address _targetAccount, RLP.RLPItem memory _tx, RLP.RLPItem memory _signature) internal pure returns(uint256) {

        RLP.RLPItem[] memory txItems = _tx.toList();
        address from = txItems[0].toAddress();
        address to = txItems[1].toAddress();
        uint256 amount = txItems[2].toUint();
        uint256 nonce = txItems[5].toUint();
        require(_nonceBeforeTx <= nonce, "Invalid nonce");

        require(_targetAccount == from || _targetAccount == to, "The target account is neither a sender nor a receiver");

        // verify the signature
        require(from == ECRecovery.recover(keccak256(_tx.toBytes()), _signature.toData()), "Invalid signature");
        if (_targetAccount == from) {
            uint256 cost = computeCost(txItems);
            require(_balanceBeforeTx >= cost, "Balance not enough");
            return _balanceBeforeTx.sub(cost);
        } else {
            return _balanceBeforeTx.add(amount);
        }
    }

    /**
    * @dev Compute the cost of a tx
    * @param _txItems The tx
     */
    function computeCost(RLP.RLPItem[] memory _txItems) internal pure returns(uint256) {
        uint256 amount = _txItems[2].toUint();
        uint256 gasPrice = _txItems[3].toUint();
        uint256 gasLimit = _txItems[4].toUint();
        return amount.add(gasPrice.mul(gasLimit));
    }

    /**
    * @dev Remove child block challenge by its index
    * @param _index The index of the challenge
    */
    function removeChildBlockChallengeByIndex(StemCore.ChainStorage storage self, uint _index) internal {
        require(_index < self.childBlockChallengeId.length, "Invalid challenge index");
        self.childBlockChallengeId[_index] = self.childBlockChallengeId[self.childBlockChallengeId.length - 1];
        delete self.childBlockChallengeId[self.childBlockChallengeId.length - 1];
        self.childBlockChallengeId.length--;
    }

     /**
    * @dev Decode the RLP encoded inspec block
    * @param _inspecBlock RLP(creator, txTreeRoot, balanceTreeRoot)
     */
    function decode(bytes _inspecBlock) internal pure returns (StemCore.InspecBlock)
    {
        RLP.RLPItem[] memory inputs = _inspecBlock.toRLPItem().toList();
        StemCore.InspecBlock memory decodedBlock;

        decodedBlock.creator = inputs[0].toAddress();
        decodedBlock.txTreeRoot = inputs[1].toBytes32();
        decodedBlock.balanceTreeRoot = inputs[2].toBytes32();
        return decodedBlock;
    }
}

library StemCore {
    using SafeMath for uint256;

    struct ChildBlock{
        address submitter;
        bytes32 balanceTreeRoot;
        bytes32 txTreeRoot;
        uint256 timestamp;
    }

    struct ChildBlockChallenge{
        address challengerAddress;
        address challengeTarget;
        bytes32 inspecTxHash;
        bytes inspecState;
    }

    struct Deposit{
        uint256 amount;
        uint256 blkNum;
        bool    isOperator;
        address refundAccount;
    }

    struct Exit{
        uint256 amount;
        uint256 blkNum;
        bool    isOperator;
        bool    executed;
    }

     struct InspecBlock {
        address creator;
        bytes32 txTreeRoot;
        bytes32 balanceTreeRoot;
    }

    struct ChainStorage {
        uint8   MIN_LENGTH_OPERATOR;
        uint8   MAX_LENGTH_OPERATOR;
        uint256 CHILD_BLOCK_INTERVAL;
        bool    IS_NEW_OPERATOR_ALLOWED;

        /** @dev subchain info */
        address   owner;
        bytes32   subchainName;
        bytes32[] staticNodes;
        uint256   totalDeposit;
        uint256   creatorDeposit;
        uint256   creatorMinDeposit;

        /** @dev subchain related */
        uint256 curDepositBlockNum;
        uint256 nextDepositBlockIncrement;
        uint256 curExitBlockNum;
        uint256 nextExitBlockIncrement;
        uint256 nextChildBlockNum;
        uint256 lastChildBlockNum;
        mapping(uint256 => ChildBlock) childBlocks;
        uint256 childBlockChallengePeriod;
        uint256 childBlockChallengeSubmissionPeriod;
        bool    isBlockSubmissionBondReleased;
        uint256 blockSubmissionBond;
        uint256 blockChallengeBond;
        uint192[] childBlockChallengeId;
        mapping(uint192 => ChildBlockChallenge) childBlockChallenges;

        /** @dev Operator related */
        address[] operatorIndices;
        mapping(address => uint256) operators;
        mapping(address => uint256) operatorFee;
        mapping(address => bool)    isExistedOperators;
        uint256 operatorMinDeposit;
        uint256 operatorExitBond;

        /** @dev User related */
        address[] userIndices;
        mapping(address => uint256) users;
        mapping(address => bool)    isExistedUsers;
        uint256 userMinDeposit;
        uint256 userExitBond;

        /** @dev deposit and exit related */
        mapping(address => address) refundAddress;
        mapping(address => Deposit) deposits;
        address[] depositsIndices;
        mapping(address => Exit) exits;
        address[] exitsIndices;

        /** @dev backup params */
        uint256   feeBackup;
        uint256   totalDepositBackup;
        address[] accountsBackup;
        uint256[] balancesBackup;

    }

    event AddOperatorRequest(address account, uint256 depositBlockNum, uint256 amount);
    event UserDepositRequest(address account, uint256 depositBlockNum, uint256 amount);
    event OperatorExitRequest(address account, uint256 exitBlockNum, uint256 amount);
    event UserExitRequest(address account, uint256 exitBlockNum, uint256 amount);

    /**
    * @dev  create an AddOperator request
    * @param _operator      Operator address
    * @param _refundAccount The account to get the fund back
    * @param _msgSender     msg.sender
    * @param _msgValue      msg.value
    */
    function createAddOperatorRequest(ChainStorage storage self, address _operator, address _refundAccount, address _msgSender, uint256 _msgValue) public {
        require(_msgSender == _refundAccount || _msgSender == self.owner, "Requests should be sent by the operator or the creator");
        require(self.IS_NEW_OPERATOR_ALLOWED, "Adding new operator is not allowed");
        require(self.isExistedOperators[_operator] == false, "Repeated operator");
        require(self.isExistedUsers[_operator] == false, "This address has been registered as a user");
        require(self.deposits[_operator].amount == 0, "Another request exists for this address");
        require(isValidAddOperator(self, _operator, _msgValue), "Unable to add this operator");
        require(self.operatorIndices.length < self.MAX_LENGTH_OPERATOR, "Reach the maximum number of operators");
        require(existUnresolvedRequest(self, _operator) == false, "Another unresolved request exists for this address");

        self.curDepositBlockNum = processDepositBlockNum(self);
        self.depositsIndices.push(_operator);
        self.deposits[_operator] = Deposit({
            amount: _msgValue,
            blkNum: self.curDepositBlockNum,
            isOperator: true,
            refundAccount: _refundAccount
        });

        emit AddOperatorRequest(
            _operator,
            self.curDepositBlockNum,
            _msgValue
        );
    }

     /**
    * @dev  create an userDeposit request
    * @param _user      user address
    * @param _refundAccount The account to get the fund back
    * @param _msgSender     msg.sender
    * @param _msgValue      msg.value
    */
    function createUserDepositRequest(ChainStorage storage self, address _user, address _refundAccount, address _msgSender, uint256 _msgValue) public {
        require(_msgSender == _refundAccount || _msgSender == self.owner, "Requests should be sent by the user or the creator");
        require(self.isExistedOperators[_user] == false, "This address has been registered as an operator");
        require(self.deposits[_user].amount == 0 || (self.deposits[_user].amount > 0 && self.deposits[_user].isOperator == false), "An addOperator request exists for this address");
        require(isValidUserDeposit(self, _user, _msgValue), "Unable to deposit for this user");
        require(existUnresolvedRequest(self, _user) == false, "Another unresolved request exists for this user");

        // merge this request with existing deposit/exit requests that have the same execution period
        uint256 depositAmount = _msgValue;
        if (self.deposits[_user].blkNum > self.nextChildBlockNum) {
            // merge current deposit request with a previous deposit request
            self.deposits[_user].amount = self.deposits[_user].amount.add(_msgValue);
            emit UserDepositRequest(
                _user,
                self.deposits[_user].blkNum,
                self.deposits[_user].amount
            );
            return;
        } else if (self.exits[_user].blkNum > self.nextChildBlockNum) {
            // merge current deposit request with a previous exit request
            if (self.exits[_user].amount < depositAmount) {
                depositAmount = depositAmount.sub(self.exits[_user].amount);
                self.refundAddress[_user].transfer(self.exits[_user].amount.add(self.userExitBond));
                delete self.exits[_user];
            } else if (self.exits[_user].amount > depositAmount) {
                self.exits[_user].amount = self.exits[_user].amount.sub(depositAmount);
                self.refundAddress[_user].transfer(depositAmount);
                emit UserExitRequest(
                    _user,
                    self.exits[_user].blkNum,
                    self.exits[_user].amount
                );
                return;
            } else {
                // exit request and deposit request cancel out each other
                self.refundAddress[_user].transfer(depositAmount.add(self.userExitBond));
                delete self.exits[_user];
                emit UserExitRequest(
                    _user,
                    self.exits[_user].blkNum,
                    uint256(0)
                );
                return;
            }
        }

        // create new deposit
        self.curDepositBlockNum = processDepositBlockNum(self);
        self.depositsIndices.push(_user);
        self.deposits[_user] = Deposit({
                amount: depositAmount,
                blkNum: self.curDepositBlockNum,
                isOperator: false,
                refundAccount: _refundAccount
            });

        emit UserDepositRequest(
            _user,
            self.curDepositBlockNum,
            depositAmount
        );
    }

     /**
     * @dev Verify that the operator is valid and that the deposit is sufficient
     * @param _operator The operator of the subchain
     * @param _deposit The deposit of the operator.
     * @return true if the operator is valid
     */
    function isValidAddOperator(ChainStorage storage self, address _operator, uint256 _deposit) public view returns(bool){
        require(_operator != address(0), "Invalid address");
        require(_deposit >= self.operatorMinDeposit, "Insufficient deposit amount");

        return true;
    }

    /**
    * @dev Verify that the user is valid and that the deposit is sufficient
    * @param _user The user of the subchain
    * @param _deposit The deposit of the user.
    * @return true if the user is valid
    */
    function isValidUserDeposit(ChainStorage storage self, address _user, uint256 _deposit) public view returns(bool){
        require(_user != address(0), "Invalid user address");
        require(_deposit >= self.userMinDeposit, "Insufficient user deposit value");

        return true;
    }

    /**
    * @dev Process next deposit block number
    * @return next deposit block number
    */
    function processDepositBlockNum(ChainStorage storage self) internal returns(uint256) {
        // Only allow a limited number of deposits per child block. 1 <= nextDepositBlockIncrement < CHILD_BLOCK_INTERVAL.
        require(self.nextDepositBlockIncrement < self.CHILD_BLOCK_INTERVAL);
        require(self.curDepositBlockNum < self.nextChildBlockNum.add(self.CHILD_BLOCK_INTERVAL));

        // get next deposit block number.
        uint256 blknum = getDepositBlockNumber(self);
        self.nextDepositBlockIncrement++;

        return blknum;
    }

    /**
    * @dev Calculates the next deposit block.
    * @return Next deposit block number.
    */
    function getDepositBlockNumber(ChainStorage storage self) public view returns (uint256)
    {
        return self.nextChildBlockNum.add(self.nextDepositBlockIncrement);
    }

    /**
    * @dev Delete deposit index by account
    * @param _account The account to deposit
     */
    function deleteDepositsIndicesByAccount(ChainStorage storage self, address _account) internal {
        for (uint i = 0; i < self.depositsIndices.length; i++) {
            if (_account == self.depositsIndices[i]) {
                self.depositsIndices[i] = self.depositsIndices[self.depositsIndices.length - 1];
                delete self.depositsIndices[self.depositsIndices.length - 1];
                self.depositsIndices.length--;
            }
        }
    }

    /**
     * @dev Process deposits and exits executed during last period
     */
    function executeDepositsAndExits(ChainStorage storage self) internal {
        address account;
        // execute exits
        for (uint j = 0; j < self.exitsIndices.length; j++) {
            account = self.exitsIndices[j];
            if (self.exits[account].isOperator) {
                executeOperatorExit(self, account);
            } else {
                executeUserExit(self, account);
            }
        }

        // backup after the execution of exits
        self.totalDepositBackup = self.totalDeposit;
        for (j = 0; j < self.depositsIndices.length; j++) {
            account = self.depositsIndices[j];
            if (self.deposits[account].blkNum > self.lastChildBlockNum && self.deposits[account].blkNum < self.nextChildBlockNum) {
                if (self.deposits[account].isOperator) {
                    self.operatorFee[account] = 0;
                    self.isExistedOperators[account] = true;
                    self.operatorIndices.push(account);
                } else {
                    if (self.isExistedUsers[account] == false) {
                        self.isExistedUsers[account] = true;
                        self.userIndices.push(account);
                    }
                }
                self.totalDeposit = self.totalDeposit.add(self.deposits[account].amount);
            }
        }
    }

    /**
    * @dev Create an operator exit request. It's a complete exit.
    * @param _operator The operator account
     */
    function createOperatorExitRequest(ChainStorage storage self, address _operator) public {
        //require(_msgSender == _operator, "Exit requests should be sent by the operator");
        require(self.isExistedOperators[_operator] || self.deposits[_operator].blkNum > self.nextChildBlockNum, "This operator does not exist and does not has any deposit request");
        require(existUnresolvedRequest(self, _operator) == false, "Another unresolved request exists for this operator");
        if (self.isExistedOperators[_operator]) {
            if (isLastChildBlockConfirmed(self)) {
                // last block is confirmed
                require(self.operators[_operator] >= self.operatorMinDeposit, "Invalid deposit amount");
            } else {
                uint index = self.accountsBackup.length;
                for (uint i = 0; i < self.accountsBackup.length; i++) {
                    if (self.accountsBackup[i] == _operator) {
                        index = i;
                        break;
                    }
                }
                require(self.operators[_operator] >= self.operatorMinDeposit || (index < self.accountsBackup.length && self.balancesBackup[index] >= self.operatorMinDeposit) , "Invalid deposit amount");
            }
        }

        // merge with existing deposit or exit requests
        if (self.exits[_operator].blkNum > self.nextChildBlockNum) {
            // an operator exit already exists
            self.refundAddress[_operator].transfer(self.operatorExitBond);
            return;
        } else if (self.deposits[_operator].blkNum > self.nextChildBlockNum) {
            // exit request and deposit request cancel out each other
            // TODO: emit an event to cancel deposit request
            self.refundAddress[_operator].transfer(self.deposits[_operator].amount.add(self.operatorExitBond));
            deleteDepositsIndicesByAccount(self, _operator);
            delete self.deposits[_operator];
            emit AddOperatorRequest(
                _operator,
                self.deposits[_operator].blkNum,
                uint256(0)
            );
            return;
        }

        self.curExitBlockNum = processExitBlockNum(self);
        self.exitsIndices.push(_operator);
        self.exits[_operator] = Exit({
                amount: self.operators[_operator],
                blkNum: self.curExitBlockNum,
                isOperator: true,
                executed: false
            });

        emit OperatorExitRequest(
            _operator,
            self.curExitBlockNum,
            self.operators[_operator]
        );
    }

    /**
    * @dev Create a user exit request
    * @param _user User account
    * @param _amount Exit amount
     */
    function createUserExitRequest(ChainStorage storage self, address _user, uint256 _amount) public {
        //require(_msgSender == _user, "Exit requests should be sent by the user");
        require(self.isExistedUsers[_user] || self.deposits[_user].blkNum > self.nextChildBlockNum, "This user does not exist and does not has any deposit request");
        require(existUnresolvedRequest(self, _user) == false, "Another unresolved request exists for this user");

        // merge existing deposit or exit requests
        uint256 exitAmount = _amount;
        if (self.exits[_user].blkNum > self.nextChildBlockNum) {
            // merge current exit request with a previous exit request
            self.exits[_user].amount = self.exits[_user].amount.add(exitAmount);
            self.refundAddress[_user].transfer(self.userExitBond);
            emit UserExitRequest(
                _user,
                self.exits[_user].blkNum,
                self.exits[_user].amount
            );
            return;
        } else if (self.deposits[_user].blkNum > self.nextChildBlockNum) {
            // merge current exit request with a previous deposit request
            if (self.deposits[_user].amount < exitAmount) {
                exitAmount = exitAmount.sub(self.deposits[_user].amount);
                self.refundAddress[_user].transfer(self.deposits[_user].amount);
                deleteDepositsIndicesByAccount(self, _user);
                delete self.deposits[_user];
            } else if (self.deposits[_user].amount > exitAmount) {
                self.deposits[_user].amount = self.deposits[_user].amount.sub(exitAmount);
                self.refundAddress[_user].transfer(exitAmount.add(self.userExitBond));
                emit UserDepositRequest(
                    _user,
                    self.deposits[_user].blkNum,
                    self.deposits[_user].amount
                );
                return;
            } else {
                // exit request and deposit request cancel out each other
                // TODO: emit an event to cancel deposit request
                self.refundAddress[_user].transfer(exitAmount.add(self.userExitBond));
                deleteDepositsIndicesByAccount(self, _user);
                delete self.deposits[_user];
                 emit UserDepositRequest(
                    _user,
                    self.deposits[_user].blkNum,
                    uint256(0)
                );
                return;
            }
        }

        require(self.isExistedUsers[_user], "This user does not exist");
        if (isLastChildBlockConfirmed(self)) {
            // last block is confirmed
            require(self.users[_user] >= exitAmount, "Invalid exit amount");
        } else {
            uint index = self.accountsBackup.length;
            for (uint i = 0; i < self.accountsBackup.length; i++) {
                if (self.accountsBackup[i] == _user) {
                    index = i;
                    break;
                }
            }
            require(self.users[_user] >= exitAmount || (index < self.accountsBackup.length && self.balancesBackup[index] >= exitAmount), "Invalid exit amount");
        }

        self.curExitBlockNum = processExitBlockNum(self);
        self.exitsIndices.push(_user);
        self.exits[_user] = Exit({
                amount: exitAmount,
                blkNum: self.curExitBlockNum,
                isOperator: false,
                executed: false
            });

        emit UserExitRequest(
            _user,
            self.curExitBlockNum,
            exitAmount
        );
    }

      /**
    * @dev process next exit block number
    * @return next exit block number
    */
    function processExitBlockNum(ChainStorage storage self) internal returns(uint256) {
        // Only allow a limited number of exits per child block. 1 <= nextExitBlockIncrement < CHILD_BLOCK_INTERVAL.
        require(self.nextExitBlockIncrement < self.CHILD_BLOCK_INTERVAL, "Too many exit blocks");
        require(self.curExitBlockNum < self.nextChildBlockNum.add(self.CHILD_BLOCK_INTERVAL), "Currrent exit block number cannot be too far in the future");

        // get next deposit block number.
        uint256 blknum = getExitBlockNumber(self);
        self.nextExitBlockIncrement++;

        return blknum;
    }

    /**
    * @dev Calculates the next exit block.
    * @return Next exit block number.
    */
    function getExitBlockNumber(ChainStorage storage self) public view returns (uint256)
    {
        return self.nextChildBlockNum.add(self.nextExitBlockIncrement);
    }

    /**
    * @dev Execute operator exit
    * @param _operator The operator account to exit from
    */
    function executeOperatorExit(ChainStorage storage self, address _operator) public {
        if (self.exits[_operator].amount <= 0) {return;}
        // make sure the exit is in execution period
        if (self.exits[_operator].blkNum <= self.lastChildBlockNum || self.exits[_operator].blkNum >= self.nextChildBlockNum) {return;}
        if (!isLastChildBlockConfirmed(self)) {return;}
        if (self.exits[_operator].executed == true) {return;}
        if (self.operators[_operator] < self.operatorMinDeposit) {
            deleteExitsIndicesByAccount(self, _operator);
            delete self.exits[_operator];
        } else {
            self.refundAddress[_operator].transfer(self.operatorFee[_operator].add(self.operators[_operator].add(self.operatorExitBond)));
            delete self.operators[_operator];
            delete self.operatorFee[_operator];
            self.isExistedOperators[_operator] = false;
            deleteOperatorIndicesByAccount(self, _operator);
            self.totalDeposit = self.totalDeposit.sub(self.operators[_operator].add(self.operatorFee[_operator]));
            self.exits[_operator].executed = true;
        }
    }

    /**
    * @dev Delete operator index by the account
    * @param _operator The operator account
     */
    function deleteOperatorIndicesByAccount(ChainStorage storage self, address _operator) internal {
        for (uint i = 0; i < self.operatorIndices.length; i++) {
            if (_operator == self.operatorIndices[i]) {
                self.operatorIndices[i] = self.operatorIndices[self.operatorIndices.length - 1];
                delete self.operatorIndices[self.operatorIndices.length - 1];
                self.operatorIndices.length--;
            }
        }
    }

    /**
    * @dev Execute user exit
    * @param _user The user account to exit from
    */
    function executeUserExit(ChainStorage storage self, address _user) public {
        if(self.exits[_user].amount <= 0) {return;}
        // make sure the exit is in execution period
        if (self.exits[_user].blkNum <= self.lastChildBlockNum || self.exits[_user].blkNum >= self.nextChildBlockNum) {return;}
        if (!isLastChildBlockConfirmed(self)) {return;}
        if (self.exits[_user].executed == true) {return;}
        if (self.exits[_user].amount > self.users[_user]) {
            deleteExitsIndicesByAccount(self, _user);
            delete self.exits[_user];
        } else {
            self.refundAddress[_user].transfer(self.exits[_user].amount.add(self.userExitBond));
            self.users[_user] = self.users[_user].sub(self.exits[_user].amount);
            self.totalDeposit = self.totalDeposit.sub(self.exits[_user].amount);
            self.exits[_user].executed = true;
        }
    }

     /**
    * @dev Delete exit index by the account
    * @param _account The exit account
     */
    function deleteExitsIndicesByAccount(ChainStorage storage self, address _account) internal {
        for (uint i = 0; i < self.exitsIndices.length; i++) {
            if (_account == self.exitsIndices[i]) {
                self.exitsIndices[i] = self.exitsIndices[self.exitsIndices.length - 1];
                delete self.exitsIndices[self.exitsIndices.length - 1];
                self.exitsIndices.length--;
            }
        }
    }

    /**
    * @dev Check whether there is an unresolved (still in or has passed the execution period) deposit/exit
    *      request for the input account
    * @param _account The account to check
    * @return true if there is an unresolved request
    */
    function existUnresolvedRequest(ChainStorage storage self, address _account) public view returns(bool) {
        if (self.exits[_account].amount > 0 && self.exits[_account].blkNum < self.nextChildBlockNum) {
            return true;
        } else if (self.deposits[_account].amount > 0 && self.deposits[_account].blkNum < self.nextChildBlockNum) {
            return true;
        } else {
            return false;
        }
    }

    /**
    * @dev Calculates the block height of last confirmed child block
    * @return The block height of last confirmed child block
    */
    function getLastConfirmedChildBlockNumber(ChainStorage storage self) public view returns(uint256) {
        if (isLastChildBlockConfirmed(self)) {
            return self.lastChildBlockNum;
        } else {
            return self.lastChildBlockNum.sub(self.CHILD_BLOCK_INTERVAL);
        }
    }

    /**
    * @dev Calculates the last submitted child block num.
    * @return The block height of last submitted child block.
    */
    function getLastChildBlockNumber(ChainStorage storage self) public view returns(uint256) {
        return self.nextChildBlockNum.sub(self.CHILD_BLOCK_INTERVAL);
    }

    /**
    * @dev Check whether last submitted child block is confirmed
    * @return true if last submitted child block is confirmed.
    */
    function isLastChildBlockConfirmed(ChainStorage storage self) public view returns(bool) {
        return block.timestamp.sub(self.childBlocks[self.lastChildBlockNum].timestamp) >= self.childBlockChallengePeriod && self.childBlockChallengeId.length == 0;
    }
}

library StemCreation {
    using SafeMath for uint256;

     /**
     * @dev The rootchain constructor creates the rootchain
     * contract, initializing the owner and operators
     * @param _subchainName The name of the subchain
     * @param _genesisInfo [balanceTreeRoot, TxTreeRoot]
     *        The hash of the genesis balance tree root
     *        The hash of the genesis tx tree root
     * @param _staticNodes The static nodes
     * @param _creatorDeposit The deposit of creator
     * @param _ops The operators.
     * @param _opsDeposits The deposits of operators.
     * @param _refundAccounts The mainnet addresses of the operators
     */
    function createSubchain(StemCore.ChainStorage storage self, bytes32 _subchainName, bytes32[] _genesisInfo, bytes32[] _staticNodes, uint256 _creatorDeposit, address[] _ops, uint256[] _opsDeposits, address[]  _refundAccounts, address _msgSender, uint256 _msgValue) public {
        // initialize the storage variables
        init(self);
        require(_ops.length >= self.MIN_LENGTH_OPERATOR && _ops.length <= self.MAX_LENGTH_OPERATOR, "Invalid operators length");
        require(_ops.length == _opsDeposits.length, "Invalid deposits length");
        require(_ops.length == _refundAccounts.length, "Invalid length of refund accounts");
        require(_creatorDeposit >= self.creatorMinDeposit, "Insufficient creator deposit value");

        // Setup the operators' deposits and initial fees
        self.totalDeposit = _creatorDeposit;
        for (uint256 i = 0; i < _ops.length && StemCore.isValidAddOperator(self, _ops[i], _opsDeposits[i]); i++){
            require(self.isExistedOperators[_ops[i]] == false, "Repeated operator");
            self.operators[_ops[i]] = _opsDeposits[i];
            self.operatorFee[_ops[i]] = 0;
            self.totalDeposit = self.totalDeposit.add(_opsDeposits[i]);
            self.isExistedOperators[_ops[i]] = true;
            self.operatorIndices.push(_ops[i]);
            self.refundAddress[_ops[i]] = _refundAccounts[i];
        }
        require(_msgValue >= self.totalDeposit, "You don't give me enough money");
        self.owner = _msgSender;
        self.creatorDeposit = _creatorDeposit;

        // Register subchain info
        self.subchainName = _subchainName;
        self.staticNodes = _staticNodes;
        uint256 submittedBlockNumber = 0;
        //Create the genesis block.
        self.childBlocks[submittedBlockNumber] = StemCore.ChildBlock({
            submitter: _msgSender,
            balanceTreeRoot: _genesisInfo[0],
            txTreeRoot: _genesisInfo[1],
            timestamp: block.timestamp
        });

        // update child block number/deposit block number/exit block number
        self.nextChildBlockNum = 0;
        self.nextChildBlockNum = self.nextChildBlockNum.add(self.CHILD_BLOCK_INTERVAL);
        self.nextDepositBlockIncrement = 1;
        self.curDepositBlockNum = self.nextChildBlockNum.add(self.nextDepositBlockIncrement);
        self.nextExitBlockIncrement = 1;
        self.curExitBlockNum = self.nextChildBlockNum.add(self.nextExitBlockIncrement);
        // By default, all the initial operators' deposit should be processed on the subchain at genesis block. (The genesis block height is 0)
    }

     /**
    * @dev Initialize the contract parameters
     */
    function init(StemCore.ChainStorage storage self) internal {
        self.MIN_LENGTH_OPERATOR = 1;
        self.MAX_LENGTH_OPERATOR = 100;
        self.CHILD_BLOCK_INTERVAL = 1000;
        self.IS_NEW_OPERATOR_ALLOWED = true;
        self.creatorMinDeposit = 1;
        self.childBlockChallengePeriod = 1 hours;//1 days;
        self.childBlockChallengeSubmissionPeriod = 2 hours;//12 hours;
        self.isBlockSubmissionBondReleased = true;
        self.blockSubmissionBond = 1;
        self.blockChallengeBond = 1;
        self.operatorMinDeposit = 3;
        self.operatorExitBond = 1;
        self.userMinDeposit = 2;
        self.userExitBond = 1;
    }
}

library StemRelay {
   using RLP for bytes;
   using RLP for RLP.RLPItem;
   using RLPEncoding for address;
   using RLPEncoding for uint256;
   using RLPEncoding for bytes[];
   using SafeMath for uint256;

   event BlockSubmitted(uint256 blkNum, uint256 timestamp);
   event BlockReversed(uint256 blkNum);

   function handleRelayBlock(StemCore.ChainStorage storage self, uint256 _blkNum, bytes32 _balanceTreeRoot, bytes32 _txTreeRoot, address[] _accounts, uint256[] _updatedBalances, uint256 _fee, address _msgSender) public {
       // make sure last submitted child block is confirmed and release last block submitter's bond
       require(StemCore.isLastChildBlockConfirmed(self), "Last block is not confirmed yet");
       require(_accounts.length == _updatedBalances.length, "The number of accounts and the number of updated balances should be the same");
       require(self.nextChildBlockNum == _blkNum, "Invalid child block number");
       if (!self.isBlockSubmissionBondReleased)
       {
           self.childBlocks[self.lastChildBlockNum].submitter.transfer(self.blockSubmissionBond);
       }

       // operator bond is locked again
       self.isBlockSubmissionBondReleased = false;

       // Create the block.
       self.childBlocks[self.nextChildBlockNum] = StemCore.ChildBlock({
           submitter: _msgSender,
           balanceTreeRoot: _balanceTreeRoot,
           txTreeRoot: _txTreeRoot,
           timestamp: block.timestamp
       });

       // deal with deposits and exits executed during last period
       StemCore.executeDepositsAndExits(self);

       // backup and update some accounts
       updateBalancesAndFee(self, _accounts, _updatedBalances, _fee);

       // Update the next child and deposit blocks.
       self.nextChildBlockNum = self.nextChildBlockNum.add(self.CHILD_BLOCK_INTERVAL);
       self.lastChildBlockNum = self.lastChildBlockNum.add(self.CHILD_BLOCK_INTERVAL);
       if (self.curDepositBlockNum < self.nextChildBlockNum) {
           self.nextDepositBlockIncrement = 1;
           self.curDepositBlockNum = self.nextChildBlockNum.add(self.nextDepositBlockIncrement);
       }
       if (self.curExitBlockNum < self.nextChildBlockNum) {
           self.nextExitBlockIncrement = 1;
           self.curExitBlockNum = self.nextChildBlockNum.add(self.nextExitBlockIncrement);
       }

       emit BlockSubmitted(_blkNum, block.timestamp);

   }

    /**
    * @dev Update balances and fee of operator/user accounts
    * @param _accounts Accounts to be updated
    * @param _updatedBalances Updated balances
    * @param _fee Fee income for each active operator account
    */
   function updateBalancesAndFee(StemCore.ChainStorage storage self, address[] _accounts, uint256[] _updatedBalances, uint256 _fee) internal {
       delete self.accountsBackup;
       delete self.balancesBackup;
       for (uint j = 0; j < _accounts.length; j++) {
           if (self.isExistedOperators[_accounts[j]]) {
               self.accountsBackup.push(_accounts[j]);
               self.balancesBackup.push(self.operators[_accounts[j]]);
               self.operators[_accounts[j]] = _updatedBalances[j];
           } else if (self.isExistedUsers[_accounts[j]]) {
               self.accountsBackup.push(_accounts[j]);
               self.balancesBackup.push(self.users[_accounts[j]]);
               self.users[_accounts[j]] = _updatedBalances[j];
           }
       }

       // backup and update operator fee account
       self.feeBackup = _fee;
       for (j = 0; j < self.operatorIndices.length; j++) {
           self.operatorFee[self.operatorIndices[j]] = self.operatorFee[self.operatorIndices[j]].add(self.feeBackup);
       }
       // The sum of the total balance and fee of a subchain should be within a certain range
       // TODO consider the bond
       require(totalFee(self).add(totalBalance(self)) <= self.totalDeposit && self.totalDeposit < address(this).balance.sub(self.creatorMinDeposit));
   }

   function doReverseBlock(StemCore.ChainStorage storage self, uint256 _blkNum) public {
       require(block.timestamp.sub(self.childBlocks[self.lastChildBlockNum].timestamp) >= self.childBlockChallengePeriod, "Last submitted block is in challenge period");
       //require(self.childBlockChallengeId.length > 0, "No existing child block challenges");
       require(self.lastChildBlockNum == _blkNum, "Invalid child block number");
       delete self.childBlocks[self.lastChildBlockNum];
       self.nextChildBlockNum = self.lastChildBlockNum;
       self.lastChildBlockNum = StemCore.getLastChildBlockNumber(self);

       // reverse the balances updated by last submitted child block
       reverseBalancesAndFee(self);
       reverseOperatorIndices(self);

       // only the first challenger gets the blockSubmissionBond
       /*if (!self.isBlockSubmissionBondReleased)
       {
           self.childBlockChallenges[self.childBlockChallengeId[0]].challengerAddress.transfer(self.blockSubmissionBond);
           self.isBlockSubmissionBondReleased = true;
       }*/
       // clear challenges
       StemChallenge.clearExistingBlockChallenges(self);

       emit BlockReversed(self.nextChildBlockNum);
   }

   /**
    * @dev Reverse the balances and fee updated by last submitted child block
    */
   function reverseBalancesAndFee(StemCore.ChainStorage storage self) internal {
       for (uint i = 0; i < self.accountsBackup.length; i++) {
           if (self.isExistedOperators[self.accountsBackup[i]]) {
               self.operators[self.accountsBackup[i]] = self.balancesBackup[i];
           } else if (self.isExistedUsers[self.accountsBackup[i]]) {
               self.users[self.accountsBackup[i]] = self.balancesBackup[i];
           }
       }
       self.totalDeposit = self.totalDepositBackup;
       delete self.accountsBackup;
       delete self.balancesBackup;

       for (uint j = 0; j < self.operatorIndices.length; j++) {
           self.operatorFee[self.operatorIndices[j]] = self.operatorFee[self.operatorIndices[j]].sub(self.feeBackup);
       }
   }

    /**
    * @dev Reverse the operator indices updated by last submitted child block
    */
   function reverseOperatorIndices(StemCore.ChainStorage storage self) internal {
       address account;
       for (uint j = 0; j < self.depositsIndices.length; j++) {
           account = self.depositsIndices[j];
           if (self.deposits[account].blkNum > self.lastChildBlockNum && self.deposits[account].blkNum < self.nextChildBlockNum) {
               if (self.deposits[account].isOperator) {
                   self.isExistedOperators[account] = false;
                   StemCore.deleteOperatorIndicesByAccount(self, account);
               }
           }
       }
   }

   /**
   * @dev Get the total balance of operator accounts and user accounts
   * @return The total balance
   */
   function totalBalance(StemCore.ChainStorage storage self) public view returns (uint256){
       uint256 amount = 0;
       for (uint i = 0; i < self.operatorIndices.length; i++) {
           amount = amount.add(self.operators[self.operatorIndices[i]]);
       }
       for (uint j = 0; j < self.userIndices.length; j++) {
           amount = amount.add(self.users[self.userIndices[j]]);
       }
       return amount;
   }

   /**
   * @dev Get the total fee of operator accounts
   * @return The total fee
   */
   function totalFee(StemCore.ChainStorage storage self) public view returns (uint256){
       uint256 amount = 0;
       for (uint i = 0; i < self.operatorIndices.length; i++) {
           amount = amount.add(self.operatorFee[self.operatorIndices[i]]);
       }
       return amount;
   }
}

contract StemRootchain {
    using SafeMath for uint256;
    using StemCore for bytes;
    using StemCore for StemCore.ChainStorage;

    StemCore.ChainStorage private data;

    /** events */
     event AddOperatorRequest(address account, uint256 depositBlockNum, uint256 amount);
     event UserDepositRequest(address account, uint256 depositBlockNum, uint256 amount);
     event OperatorExitRequest(address account, uint256 exitBlockNum, uint256 amount);
     event UserExitRequest(address account, uint256 exitBlockNum, uint256 amount);
     event BlockSubmitted(uint256 blkNum, uint256 timestamp);
     event BlockReversed(uint256 blkNum);
     event BlockChallenge(address challengeTarget, uint256 blkNum);
     event RemoveBlockChallenge(uint challengeIndex);

    /** @dev Reverts if called by any account other than the owner. */
    modifier onlyOwner() {
        require(msg.sender == data.owner, "You're not the owner of the contract!");
         _;
    }

    /** @dev Reverts if called by any account other than the operator. */
    modifier onlyOperator() {
        require(data.operators[msg.sender] > 0, "You're not the operator of the contract!");
        _;
    }

    /** @dev Reverts if the message value does not equal to the desired value */
    modifier onlyWithValue(uint256 _value) {
        require(msg.value == _value, "Incorrect amount of input!");
        _;
    }

    /**
     * @dev The rootchain constructor creates the rootchain
     * contract, initializing the owner and operators.
     * @param _subchainName The name of the subchain
     * @param _genesisInfo [_genesisBalanceTreeRoot, _genesisTxTreeRoot]
     *        The hash of the genesis balance tree root
     *        The hash of the genesis tx tree root
     * @param _staticNodes The static nodes
     * @param _creatorDeposit The deposit of creator
     * @param _ops The operators.
     * @param _opsDeposits The deposits of operators.
     * @param _refundAccounts The operators' mainnet addresses
     */
    constructor(bytes32 _subchainName, bytes32[] _genesisInfo, bytes32[] _staticNodes, uint256 _creatorDeposit, address[] _ops, uint256[] _opsDeposits, address[] _refundAccounts)
    public payable {
        StemCreation.createSubchain(data, _subchainName, _genesisInfo, _staticNodes, _creatorDeposit, _ops, _opsDeposits, _refundAccounts, msg.sender, msg.value);
    }

    /**
    * @dev Create a request to add new operator to the subchain
    * @param _operator The operator to be added
    * @param _refundAccount The account where the fund will be returned
    */
    function addOperatorRequest(address _operator, address _refundAccount) public payable {
        data.createAddOperatorRequest(_operator, _refundAccount, msg.sender, msg.value);
    }

    /**
    * @dev Allow user deposit to the subchain
    * @param _user The user account to deposit value
    * @param _refundAccount The account where the fund will be returned
    */
    function userDepositRequest(address _user, address _refundAccount) public payable {
        data.createUserDepositRequest(_user, _refundAccount, msg.sender, msg.value);
    }

    /**
    * @dev Remove inactive deposit request
    * @param _account The associated account of the deposit to be removed
    */
    function removeDepositRequest(address _account) public {
        require(data.deposits[_account].amount > 0, "This deposit does not exist");
        require(data.deposits[_account].blkNum < data.lastChildBlockNum, "This deposit is still active");
        require(data.isLastChildBlockConfirmed(), "Last block is not confirmed yet");
        data.deleteDepositsIndicesByAccount(_account);
        delete data.deposits[_account];
    }

    /**
    * @dev Create a request for operator exit
    * @param _operator The operator account to exit from
    */
    function operatorExitRequest(address _operator) public payable onlyWithValue(data.operatorExitBond) {
        data.createOperatorExitRequest(_operator);
    }

    /**
    * @dev Execute operator exit request
    * @param _operator The operator account to exit from
    */
    function execOperatorExit(address _operator) public {
        data.executeOperatorExit(_operator);
    }
    /**
    * @dev Create a request for user exit
    * @param _user The user account to exit from
    * @param _amount Amount of fund to exit
    */
    function userExitRequest(address _user, uint256 _amount) public payable onlyWithValue(data.userExitBond) {
        data.createUserExitRequest(_user, _amount);
    }

    function execUserExit(address _user) public {
        data.executeUserExit(_user);
    }

    /**
    * @dev Remove inactive exit request
    * @param _account The account to exit from
    */
    function removeExitRequest(address _account) public {
        require(data.exits[_account].amount > 0, "This exit does not exist");
        require(data.exits[_account].blkNum < data.lastChildBlockNum, "This exit is still active");
        require(data.isLastChildBlockConfirmed(), "Last block is not confirmed yet");
        data.deleteExitsIndicesByAccount(_account);
        delete data.exits[_account];
    }

    /**
    * @dev Withdraw fee from an operator fee account
    * @param _operator The operator account to withdraw fee from
    * @param _amount The amount of fee to withdraw
    */
    function feeExit(address _operator, uint256 _amount) public {
        //require(msg.sender == _operator, "Exit requests should be sent from the operator");
        require(data.isLastChildBlockConfirmed(), "Last block is not confirmed yet");
        require(data.operatorFee[_operator] >= _amount, "Invalid exit amount");
        data.refundAddress[_operator].transfer(_amount);
        data.operatorFee[_operator] = data.operatorFee[_operator].sub(_amount);
    }

     /**
     * @dev Allows any operator to submit a child block.
     * @param _blkNum The block number of the submitted block
     * @param _balanceTreeRoot The root of the balance tree of the subchain.
     * @param _txTreeRoot The root of recent tx tree of the subchain.
     * @param _accounts The accounts to be updated
     * @param _updatedBalances The updated balance of the accounts
     * @param _fee The fee income of every operator during last period
     */
     function submitBlock(uint256 _blkNum, bytes32 _balanceTreeRoot, bytes32 _txTreeRoot, address[] _accounts, uint256[] _updatedBalances, uint256 _fee) public payable onlyWithValue(data.blockSubmissionBond) {//onlyOperator onlyWithValue(data.blockSubmissionBond) {
        StemRelay.handleRelayBlock(data, _blkNum, _balanceTreeRoot, _txTreeRoot, _accounts, _updatedBalances, _fee, msg.sender);
     }

    /**
     * @dev Reverse last submitted child block
     * @param _blkNum The child block to delete
     */
    function reverseBlock(uint256 _blkNum) public {
        StemRelay.doReverseBlock(data, _blkNum);
    }

    /**
    * @dev Accept a challenge to the submitted block.
    * @param _challengeTarget The target account to challenge
    * @param _inspecBlock The block header corresponding to the _inspecTxHash
    * @param _inspecBlockSignature The operator's signature in the block
    * @param _inspecTxHash The tx hash which the challenger asks the operator to include in the response
    * @param _inspecState The state of target account in _inspecBlock
    * @param _indices  0._inspecTxIndex The tx index in the merkle tree; 1._inspecStateIndex The state index in the merkle tree
    * @param _inclusionProofs 0. The proof showing _inspecTxHash is included in _inspecBlock; 1._stateInclusionProof The proof showing _inspecState is in _inspecBlock
    */
    function challengeSubmittedBlock(address _challengeTarget, bytes _inspecBlock, bytes _inspecBlockSignature, bytes32 _inspecTxHash, bytes _inspecState, bytes _indices, bytes _inclusionProofs)
    public payable onlyWithValue(data.blockChallengeBond) {
        bytes[] memory bytesArray = new bytes[](2);
        bytesArray[0] = RLPEncoding.encodeAddress(msg.sender);
        bytesArray[1] = RLPEncoding.encodeAddress(_challengeTarget);
        bytes memory encodedAddresses = RLPEncoding.encodeList(bytesArray);
        StemChallenge.processChallenge(data, encodedAddresses, _inspecBlock, _inspecBlockSignature, _inspecTxHash, _inspecState, _indices, _inclusionProofs);
    }

    /**
    * @dev Allows an operator to submit a proof in response to a block challenge.
    * @param _challengeIndex Is the index of the challenge
    * @param _recentTxs The transactions of target account during last interval
    * @param _signatures The signatures of the tx senders
    * @param _indices The leaf indices of the tx tree, preState tree and current state tree
    * @param _preState The state of target account at the beginning of last interval
    * @param _inclusionProofs Inclusion proofs of recentTxs, preState and current state
    */
    //function responseToBlockChallenge(uint _challengeIndex, bytes _recentTxs, bytes _signatures, uint256 _txLeafIndex, bytes _recentTxInclusionProof, bytes _preState, uint256 _preStateIndex, bytes _preStateInclusionProof, uint256 _stateIndex, bytes _stateInclusionProof) public onlyOperator {
    function responseToBlockChallenge(uint _challengeIndex, bytes _recentTxs, bytes _signatures, bytes _indices, bytes _preState, bytes _inclusionProofs) public {//onlyOperator {
        StemChallenge.handleResponseToChallenge(data, _challengeIndex, _recentTxs, _signatures, _indices, _preState, _inclusionProofs, msg.sender);
    }

    /**
     */
    function getChildChainName() public view returns(bytes32) {
       return data.subchainName;
    }

    function getOperatorBalance(address _operator) public view returns(uint256) {
       return data.operators[_operator];
    }

    function getOperatorFee(address _operator) public view returns(uint256) {
       return data.operatorFee[_operator];
    }

    function getUserBalance(address _user) public view returns(uint256) {
       return data.users[_user];
    }

    function isOperatorExisted(address _operator) public view returns(bool) {
        return data.isExistedOperators[_operator];
    }

    function isUserExisted(address _user) public view returns(bool) {
        return data.isExistedUsers[_user];
    }

    function getAccountBackup(uint _index) public view returns(address) {
       return data.accountsBackup[_index];
    }

    function getBalanceBackup(uint _index) public view returns(uint256) {
       return data.balancesBackup[_index];
    }

    function getFeeBackup() public view returns(uint256) {
       return data.feeBackup;
    }

    function getStaticNodes(uint _index) public view returns(bytes32) {
       return data.staticNodes[_index];
    }

    function getOpsLen() public view returns(uint256) {
       return data.operatorIndices.length;
    }

    function getCreatorDeposit() public view returns(uint256) {
       return data.creatorDeposit;
    }

    function getLastChildBlockNum() public view returns(uint256) {
       return data.lastChildBlockNum;
    }

    function getNextChildBlockNum() public view returns(uint256) {
       return data.nextChildBlockNum;
    }

    function getOwner() public view returns(address) {
       return data.owner;
    }

    function getChildBlockTxRootHash(uint256 _blockNum) public view returns(bytes32) {
       return data.childBlocks[_blockNum].txTreeRoot;
    }

    function getChildBlockBalanceRootHash(uint256 _blockNum) public view returns(bytes32) {
       return data.childBlocks[_blockNum].balanceTreeRoot;
    }

    function getChildBlockSubmitter(uint256 _blockNum) public view returns(address) {
       return data.childBlocks[_blockNum].submitter;
    }

    function getCurDepositBlockNum() public view returns(uint256) {
       return data.curDepositBlockNum;
    }

    function getCurExitBlockNum() public view returns(uint256) {
       return data.curExitBlockNum;
    }

    function getTotalDeposit() public view returns(uint256) {
       return data.totalDeposit;
    }

    function getTotalDepositBackup() public view returns(uint256) {
       return data.totalDepositBackup;
    }

    function getDepositsLen() public view returns(uint256) {
       return data.depositsIndices.length;
    }

    function getDepositBlockNum(address _account) public view returns(uint256) {
       return data.deposits[_account].blkNum;
    }

    function getDepositAmount(address _account) public view returns(uint256) {
       return data.deposits[_account].amount;
    }

    function getDepositType(address _account) public view returns(bool) {
       return data.deposits[_account].isOperator;
    }

    function getExitsLen() public view returns(uint256) {
       return data.exitsIndices.length;
    }

    function getExitBlockNum(address _account) public view returns(uint256) {
       return data.exits[_account].blkNum;
    }

    function getExitAmount(address _account) public view returns(uint256) {
       return data.exits[_account].amount;
    }

    function getExitType(address _account) public view returns(bool) {
       return data.exits[_account].isOperator;
    }

    function getExitStatus(address _account) public view returns(bool) {
       return data.exits[_account].executed;
    }

    function getTotalBalance() public view returns(uint256) {
        return StemRelay.totalBalance(data);
    }

    function getTotalFee() public view returns(uint256) {
        return StemRelay.totalFee(data);
    }

    function getContractBalance() public view returns(uint256) {
        return address(this).balance;
    }

    function getChallengeId(uint256 _index) public view returns(uint192) {
        return data.childBlockChallengeId[_index];
    }

    function getChallengeTarget(uint192 _id) public view returns(address) {
        return data.childBlockChallenges[_id].challengeTarget;
    }

    function getChallengeLen() public view returns(uint256) {
        return data.childBlockChallengeId.length;
    }
    /**
    * @dev Get child block's hash
    * @param _blockNum Is the submitted block number
    */
    /*function getChildBlockTimestamp(uint256 _blockNum) public view returns(uint256) {
       return childBlocks[_blockNum].timestamp;
    }*/
}