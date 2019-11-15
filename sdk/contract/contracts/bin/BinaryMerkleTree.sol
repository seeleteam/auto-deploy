pragma solidity 0.4.24;

/// @title implementation of Binary Merkle Tree
/// @author Dariusz Zacharczuk
/// @notice recruitment script
contract BinaryMerkleTree {

  enum NodeTypes { Leaf, Node, Root }

  /// @dev this is tree root hash
  bytes32 public root;


  /// @dev this is item in our tree, `parent` is pointer to next item, `  nodeType` will tell us what king of node this is
  struct TreeItem {
    bytes32 parent;
    NodeTypes nodeType;
  }

  /// @dev this is our simple Merkle Tree
  /// @notice looks "small"? well.. it does the job. Merkle tree (as well as any other hash tree) are just items/nodes
  /// connected from one to another by pointer (sometimes not only one). Solidity has this great feature of mapping data,
  /// and this is just perfect data type for building any kind of trees or lists structures.
  mapping (bytes32 => TreeItem) public tree;

  /// @dev this are our data, in real product we probably keep them eg in IPFS, but just for this example,
  /// I will keep them in the contract. Key is of course a hash of data.
  /// Since I have them, I will use this to validate uniqueness of the data
  mapping (bytes32 => uint256) public leafs;


  /// @dev event will be emitted after creation of each leaf
  //event LogCreateLeaf(uint256 data, bytes32 dataHash);
  event LogCreateLeaf(bytes32 data, bytes32 dataHash);

  /// @dev event will be emitted on each item creation
  event LogCreateTreeItem(bytes32 hash, bytes32 left, bytes32 right);

  event LogCreateRoot(bytes32 root);

  /// @notice events are ususally about state change in contract, this event helped me with debugging process
  /// it just inform us how many items we have in each level 
  event LogLevelNodes(uint256 count);


  constructor() public {
  }

  /// @dev this is entry point for creating merkle tree. In real product, you probably will keep data externally
  /// and input for creating a tree would be only hashes of the data, but I wanted to demonstrate whole process.
  /// Limitation of this example: you can't pass big amount of data,
  /// because you will run out of gas while processing them. You also need to pass different/unique values.
  ///
  /// @param _data Array of unique numbers
  /*function createTree(uint256[] _data)
  public
  returns (bool)
  {
    require(_data.length > 1, "Number of items must be greater than 1");
    require(root == bytes32(0), "This implementation allow to create a tree only once");

    validateData(_data);

    // first step - create data hashes
    bytes32[] memory h;
    uint256 index;
    (h, index) = createLeafs(_data);

    emit LogLevelNodes(index);

    // for this example purposes I will create a loop here, but this is not good solution for real product
    // unless you are 100% sure that you will never ever - even in 100 years ;-) - have large amount of data
    // otherwise your contract will be useless, because you will never be able to create tree (gas limitation)
    // in real implementation it might be better to use eg. this pattern:
    // 1. call `createTreeLevel()` externally with your hashes
    // 2. watch for events from DAPP and save generated hashes
    // 3. with results from point 2. if we have any hashes left, go to 1. if not go to 4.
    // 4. we don't have any hashes, then our tree is ready
    // This is just a proposition of better and more complex solution, implementation always depends of requirements.

    // now let's generate our tree with easy fast way, just for recruitment demonstration

    // keep this loop going until we create every level of the tree
    do {
      (h, index) = createTreeLevel(h, index);
      emit LogLevelNodes(index);
    } while (index > 0);

    return true;
  }*/

  function createTree(bytes32[] memory _data)
  public
  returns (bool)
  {
    require(_data.length > 1, "Number of items must be greater than 1");
    require(root == bytes32(0), "This implementation allow to create a tree only once");

    //validateData(_data);

    // first step - create data hashes
    bytes32[] memory h;
    uint256 index;
    (h, index) = createLeafs(_data);

    emit LogLevelNodes(index);

    // for this example purposes I will create a loop here, but this is not good solution for real product
    // unless you are 100% sure that you will never ever - even in 100 years ;-) - have large amount of data
    // otherwise your contract will be useless, because you will never be able to create tree (gas limitation)
    // in real implementation it might be better to use eg. this pattern:
    // 1. call `createTreeLevel()` externally with your hashes
    // 2. watch for events from DAPP and save generated hashes
    // 3. with results from point 2. if we have any hashes left, go to 1. if not go to 4.
    // 4. we don't have any hashes, then our tree is ready
    // This is just a proposition of better and more complex solution, implementation always depends of requirements.

    // now let's generate our tree with easy fast way, just for recruitment demonstration

    // keep this loop going until we create every level of the tree
    do {
      (h, index) = createTreeLevel(h, index);
      emit LogLevelNodes(index);
    } while (index > 0);

    return true;
  }


  /// @dev because I use zero, when I have odd number of hashes in tree level, I don't want to use zeros as input data
  /// @return true if all our data are ok, throw otherwise
  function validateData(uint[] _data)
  private
  pure
  returns (bool){

    for (uint i=0; i < _data.length; i++) {
      require(_data[i] > 0, "You cannot use zeros in this demonstration");
    }

    return true;
  }

  /// @dev it does this ceil(a/2)
  function div2ceil(uint a)
  public
  pure
  returns (uint) {
    return ((a + (a % 2)) / 2);
  }

  /// I create it to check, if I can save some gas, if I use memory table instead of `leafs` state,
  /// to check, if all data is unique, but it turns out, it uses more gas.
  /* function inArray(bytes32[] memory array, bytes32 v)
  public
  pure
  returns (bool yes){
    for (uint i=0; !yes && i < array.length; i++) {
      if (array[i] == v) yes = true;
    }
  } // */

  /// @dev this function create bottom level or the tree
  /// @param _data array of input data
  /// @return array of hashes for created tree level and count of that array
  /*function createLeafs(uint256[] _data)
  private
  returns (bytes32[] memory, uint256){

    // here we will save all leafs hashes
    bytes32[] memory tmp = new bytes32[](_data.length);
    uint256 index = 0;

    // loop for generating hashes for all input data
    for (uint i=0; i < _data.length; i++) {

      bytes32 h = keccak256(abi.encodePacked(_data[i]));


      require(leafs[h] == 0, "This example require unique data");
      //require(!inArray(tmp, h), "This example require unique data");  // this uses more gas


      tmp[index] = h;
      index++;

      // save data to the contract state
      leafs[h] = _data[i];

      // and create our first tree level
      tree[h] = TreeItem({parent: bytes32(0), nodeType: NodeTypes.Leaf});
      emit LogCreateLeaf(_data[i], h);
    }


    return (tmp, index);
  }*/

  function createLeafs(bytes32[] memory _data)
  private
  returns (bytes32[] memory, uint256){

    // here we will save all leafs hashes
    bytes32[] memory tmp = new bytes32[](_data.length);
    uint256 index = 0;

    // loop for generating hashes for all input data
    for (uint i=0; i < _data.length; i++) {

      bytes32 h = _data[i];


      //require(leafs[h] == 0, "This example require unique data");
      //require(!inArray(tmp, h), "This example require unique data");  // this uses more gas


      tmp[index] = h;
      index++;

      // save data to the contract state
      //leafs[h] = _data[i];

      // and create our first tree level
      tree[h] = TreeItem({parent: bytes32(0), nodeType: NodeTypes.Leaf});
      emit LogCreateLeaf(_data[i], h);
    }


    return (tmp, index);
  }


  /// @dev this function creates one tree level
  /// @param _childrenHashes Children hashes from previous level or data hashes, if we start building the tree
  /// @return array of hashes for created tree level and count of that array
  function createTreeLevel(bytes32[] memory _childrenHashes, uint256 _childrenCount)
  private
  returns (bytes32[] memory, uint256){

    require(_childrenCount > 0, "_childrenCount must be > 0");


    bytes32[] memory tmp = new bytes32[](div2ceil(_childrenCount));
    uint256 index = 0;

    // if we have only one hash, means our tree is ready and this is our root
    if (_childrenCount == 1) {

      root = _childrenHashes[0];
      tree[_childrenHashes[0]].  nodeType = NodeTypes.Root;
      emit LogCreateRoot(_childrenHashes[0]);

      return (tmp, 0);
    }


    uint256 len = _childrenHashes.length;
    // go through every hash by step of 2, because every iteration takes 2 items to generate parent hash
    for (uint i=0; i < len; i += 2) {

      // if we don't have even number of hashes, we use 0 in place of last one
      // how we handle that case is also depends on our implementation,
      // eg. we can have implementation where we pass current hash without change to next level
      // but here, we are using hashes also as pointers, so we can't do that
      bytes32 h = createItem(_childrenHashes[i],  //left child
                            i + 1 < len ? _childrenHashes[i+1] : bytes32(0)); //right child


      //save our hash, so we can pass it to the next level
      tmp[index] = h;
      index++;
    }


    return (tmp, index);
  }



  /// @dev this function create tree item based on children hashes
  /// @return item hash
  function createItem(bytes32 _left, bytes32 _right)
  private
  returns (bytes32 hash) {


    // create item hash
    hash = keccak256(abi.encodePacked(_left, _right));

    // save pointers from children to parent
    tree[_left].parent = hash;
    tree[_right].parent = hash;

    // save our current hash
    tree[hash] = TreeItem({parent: bytes32(0), nodeType: NodeTypes.Node});

    emit LogCreateTreeItem(hash, _left, _right);

    return hash;
  }

  /// @dev checks if type `nt` is correct according to the level.
  /// @param nt node type
  /// @param level current level of the node
  /// @param branchNodesCount - maximum number of levels (count of all nodes in a branch)
  function validateNodeType(NodeTypes nt, uint level, uint branchNodesCount)
  private
  pure
  returns (bool) {
    //first level is a leaf
    if (level == 0 && nt == NodeTypes.Leaf) return true;
    //last level is a root
    if (level == branchNodesCount - 1 && nt == NodeTypes.Root) return true;
    //all other should be nodes
    if (nt == NodeTypes.Node) return true;

    return false;
  }


  /// @dev this function checks, if our proof is valid
  /// @param _proof array of hashes, from leaf to the root. This is not requirement, to check always whole branch,
  /// in real product you may want to have option, to validate only part of the branch, but this implementation
  /// requires whole path
  /// @return 0 when valid, integer when invalid (just for debugging purposes)
  function checkProof(bytes32[] _proof)
  public
  view
  returns (int256) {

    // create memory variable, because we will be reading root more than once (saving some gas)
    bytes32 r = root;

    // we need to have a tree
    if (r == bytes32(0)) return -1;

    // we need to have at least one hash
    uint256 len = _proof.length;
    if (len < 1) return -2;


    // because we require whole path, we can also check root, it will save us a gas in situation, when proof is invalid
    if (_proof[len - 1] != r) return -2;


    TreeItem memory item = tree[_proof[0]];

    // this validation working on whole branch, and because we have information about the leaf,
    // we will use it to validate the proof
    if (item.  nodeType != NodeTypes.Leaf) return -4;


    // read whole branch up to the root, we start from 1, because leaf is already pulled and validated
    for (uint256 i = 1; i < len; i++) {

      // `i-1` because our item is a previous one
      if (!validateNodeType(item.nodeType, i-1, len)) {
        // this conversion would be a risk, but in this example I do not expect that many items
        // also I return int only because I want to use it for debug purposes
        return int256(i);
      }

      if (item.parent != _proof[i]) {
        return int256(i*1000);
      }

      // read next item from our tree
      item = tree[item.parent];
    }

    // we can do one last check (just in case) and see if root item do not have parent
    return item.parent == bytes32(0) ? 0 : int256(-5);

  }


}