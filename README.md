### 已用工具
```
git clone https://github.com/seeleteam/auto-deploy.git
npm install 
# 在dev里边修改代码边
node compile.js
node rpc.js
# 就只需要修改test后的参数1或0就可以控制要用哪些函数
```

### 目标使用案例:

``` js
let payloadAddresses = []
var payloadArray = payloadArray("./contracts")

//如果编译有问题要在循环开始之前暴露
for ( var i = 0 ; i > payloadArray.length ; i++ ) { 
  if (payloadArray[i].err) {
    console.log(payloadArray[i].err);
  }
}

//开始循环部署
for ( var i = 0 ; i > payloadArray.length ; i++ ) {
  // 将payloadAddresses里已有的 {合约名, 地址} 替掉payloadArray[i].payload里的指代性字符串, 生成真正会发送的payload
  var payload = insertAddress(payloadArray[i], payloadAddresses)
  
  //允许开发者用payloadAddresses来让send判断哪些合约不想重复部署
  //发送中间允许开发者用终端y/n来决定limit/estimateGas是否合理
  var result = send(prikey, payload, payloadAddresses) 
  
  // 如果发送失败, 结束, 但告诉用户已经部署了哪些合约
  if (result.err) { return payloadAddresses; break; }
  else { 
    // 如果发送成功:
    //  如果开发者想重复利用以前布过的合约地址可以在前面的payloadAddresses中初始化:
    //  let payloadAddresses=[{"name":"contractName", "addrss":"0x..."}, ...]
    noneDuplicatePush(payloadAddresses, result.address)
  }
}

```

1.  
```js
function payloadArray(contractDirPath){}
```
  - 输入: 合约文件夹路径, 
      - 例: `./contracts` 内置结构如下: 
        ```bash
        contracts
        ├── 1.sol
        ├── 2.sol # import ./1.sol
        └── 3.sol # import ./1.sol import ./2.sol
        ```
  - 输出: 按依赖性先后排序的{contract, payload, dependency}序列
      - 例: 返回 `payloadArray` 结构如下:
        ```json
        [
          {
              "name": "1.sol",
              "payload": "0x...",
              "dependency" : []
          },
          {
              "name": "2.sol",
              "payload": "0x...",
              "dependency" : ["1.sol"]
          },
          {
              "name": "3.sol",
              "payload": "0x...",
              "dependency" : ["1.sol", "2.sol"]
          }
        ]
        ```
2. 
```js
function insertAddress(payloadArray[i], payloadAddresses){}
```
  - 输入: 合约payload序列, 合约地址序列
    - 例:
      ```js
      payloadArray[2] = {
          "name": "3.sol",
          "payload": "0x...__test.sol:1___________________________......__test.sol:2___________________________...",
          "dependency" : ["1.sol", "2.sol"]
      }
      payloadAddresses = [
          {
            "name": "1",
            "address": "0x..."
          },
          {
            "name":"2", 
            "address": "0x..."
          }
      ]
      ```
  - 输出: payload 例, 如果发现合约已经出现在payloadAddresses里, send为false
      ```js
      payload = {
        "hex": "0x..."
        "send": "true"
      }
      ```
    