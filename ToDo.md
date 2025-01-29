

have two different numconfirmationrequired for normal transactions and adding/deleting users (does that make sense?) - leichte entscheidungen 50+1 und schwere 2/3 mehrheit
-> two nums implemented.✅
-> have them automatically and alwyas at 50+1 and 2/3✅

add a function to change the numConfirmationsRequired if ALL multisig owners confirm. make sure tho that it cant be higher than how many multisigowners exist at the given time. -> Since I use the automated logic it would make more sense to use the Diamond structure to make the whole contract and thus the logic itself upgradable ✅
Also doublecheck that if a multisigowner gets deleted that the numconfirmation gets reduced in case otherwise there would be more confirmations required than multisigowners exist. -> added note for that in the code ✅

add a function where the multisigOwner who submitted a transaction is able to cancel/delete it anytime before it has been executed. - i dont think thats necessary, since one can just revoke their confirmation. ✅

have two different numconfirmationrequired for normal transactions and adding/deleting users (does that make sense?) - leichte entscheidungen 50+1 und schwere 2/3 mehrheit ✅

✅ bei 2 ownern reicht die confirmation von einem um tokens zu transferieren also 50% +1 funktioniert nicht richtig

using an enum instead of a boolean for isERC721 can make the code more readable and maintainable. Enums provide a clearer understanding of the possible states and can be extended more easily in the future if needed. ✅

ok jetzt mal das ganze in hardhat testen ob ich da mit dem simplified contract das gleiche problem habe oder ob es an remix liegt. wenn nicht dann schauen ob die erc721 und erc20 executes gehen. wenn ja dann einfach für die add und remove owner mit highlevel calls umprogrammieren - einfach erstmal wieder den hardhat node zum laufen bringen und dann statt mit der console mit scripten mit dem contract interargieren. vlt kann ich später mal hardhat durch foundry ablösen - vielleicht auch einfach mal mit cGPT komplett hardhat neu einrichten, also checken ob die version passt und dann neue projekt anlegen - remix sepolia funktioniert auch nicht, also wird hardhat wohl auch nicht funktionieren. das problem ist also im contract selbst. als nächstes schauen ob die erc721 und erc20 executes gehen. wenn ja dann einfach für die add und remove owner mit highlevel calls umprogrammieren✅
-> Also erc20 funktioniert, es ist wohl nur das problem mit dem internen call.✅
-> hab jetzt refactored um mit transactionType alles zu coordinieren. jetzt nochmal auf remix testen.✅

also implement the safeERC20 thing from open zepplin ✅

-> jetzt noch erc721 und erc20 testen dann hab ich eigentlich alles vorgetestet und kann an die richtigen tests mit hardhat oder foundry gehen✅
-----> when testing the safeTransferFrom() function, i get an error similarly to before when i couldnt call the internal function addOwnerInternal. add a callback function with a console.log to verify if its the same situation. more details see cGPT ✅

-erst nochmal den erc721 transfer funktion checken ✅
-add und remove owner checken -> nochmal von 3 initial ownern auf 5 hoch und auf 1 runter und wieder auf 3 hoch ✅
-dann transfer eth erc20 ✅ und erc721 ✅ mit mehreren owneren checken (hierfür vlt 5 owners und unterschiedliche numImportantDecisionConfirmations wählen) ✅
-dann richtiges extensives testscript schreiben ("now create a foundry testscript (\*.t.sol) that automatically tests all this stuff, transfering eth, erc20, erc721 and adding and removing owners and "other" (enum number 5) as well as all other functions extensively including the eventlogs")
-------> next step das existierende testscript scheint die events / logs nicht richtig zu erwarten. nochmal neu cGPT fragen das zu überarbeiten aber ohne das script so zu verbiegen, dass tatsächliche fehler im multisig.sol vertuscht werden.✅ ---> step by step die fehlschlagenden tests durchgehen, siehe claudeAI✅ --> habe ich versehentlich test funktionen gelöscht... Alte commits checken und vergleichen✅

Num confirmations; wenn stimme1 + stimme2 + ... > Anzahl User \*0,5+1 dann execute ✅

adapt testscript to the new voting mechanism✅

Reentrancy Guard: Use OpenZeppelin's ReentrancyGuard modifier for public and external functions to protect against reentrancy attacks. You already inherit from ReentrancyGuard, so applying its modifier to susceptible functions is advisable.
-> bei addOwnerInternal gibts einen fehler wenn ich den reentrancy guard nutze...✅

cGPT meint confirmTransaction sollte auch einen reentrancy guard haben. Mit cGPT die implementation machen da ich mit Claude das problem habe, dass dann der executeTransaction call nicht geht. vlt sollte ich das automatische executeTransaction auch raus lassen wenn das wirklich nicht mit nonReentrant geht... -> ne doch nicht weil execute transaction eh erst aufgerufen wird, wenn genug confirmations da sind ✅

Gas limits: Ensure that loops in your contract (like in deactivatePendingTransactions) can't cause out-of-gas errors with a large number of transactions. ✅

// !!! ✅

spießer proposals✅
transaction index should start with 1 instead of 0 -> machts kompliziert also lass ichs weg
for the transfer erc20 and 721 functions of the multisig wallet the from is obviously this.address, so it shouldnt be needed in the functions arguments --> it makes sense to have from, because the contract could also handle tokens where it just has the rights to, without owning them (so i added the from parameter to ther erc721 as well)
Add that with submitting there will automatically the confirm function be called (is that necessary?) ✅

ok this is my contract now ... please let me know where i can safe gas significantly ✅

funktion nochmal mit testscript bestätigen ✅

check if the 2/3 really works for 2 3 4 5 6 7 8 99 owners ✅

also check the remove owner function like that ✅

check if a malicious owner would not be able to use the "other" enum to go aroud the 2/3 requirement when calling the add/remove owner function internally ✅

check if the >50% really works for 2 3 4 5 6 7 8 99 owners for ETH, ERC20 and ERC721 ✅

Error Handling: Add more descriptive error messages for edge cases, such as invalid data formats or failed transactions. ✅

Find out why saving, formatting and auto error checks (these red lines) are so slow now ✅

Add licence files ✅
use .env for privatekey und so ✅
checked .gitignore ✅
multisigWallet.sol natspec nochmal machen lassen weil ich ja sachen geändert hatte ✅

test receive erc20 and erc721 and the emitted event for receiving ✅

test natspec machen lassen ✅

licence files niklas vergleichen ✅

- "Please evaluate my tests critically if they make sense or if they are bent in a way that they actually cover up issues with my smart contract" - extensives testscript und fuzzing schreiben (das testscript was ich aktuell habe verstehe ich nicht 100% also sicher gehen dass ich keinen scheiß teste) (Add more edge case tests, particularly around owner management and transaction execution. ; Add tests for potential malicious scenarios to ensure the contract is secure against various attack vectors. ; 1. testFailAddExistingOwner() The failure in testFailAddExistingOwner() suggests that either:
  The contract allows adding an existing owner, which it shouldn't, or The test might be incorrectly asserting the behavior.)
  doublecheck that if a multisigowner gets deleted that the numconfirmation gets reduced in case otherwise there would be more confirmations required than multisigowners exist. ✅

Testnet tests:
deployscript für multisigWallet schreiben #Deployed at 0x205750B139d821A87caBD52757be99DC92FF07D0 - later changed and redeployed at 0x0aD2C8cc921f660F0661c0588473155468606f9a - later changed and redeployed at 0x64890a1ddD3Cea0A14D62E14fE76C4a1b34A4328 ✅
deployscript für simpleERC20 schreiben #Deployed at 0xbD89C92329E24a6abdE36e3aa44F17B396d62422 ✅
deployscript für simpleERC721 schreiben #Deployed at 0x76590a96a63688Ad1c7422fbAa6EFB66C9ba176a ✅
\testscript auf sepolia fork validieren - Overpaying problem is probably just because of dust left on these addresses, so instead of checking the absolute balance, check the difference between initial and final balance ✅

neues einfaches testscript schreiben um die funktion auf tatsächlichem sepolia testnet zu validieren
Also foundry kann nicht einfach ein script einfach auf der sepolia evm laufen lassen... cGPT sagt man kann vlt ethers.js oder web3.js nutzen oder über polling foundry dazu zwingen seine daten vom testnet zu holen...
ich könnte auch ein testscript in hardhat schreiben, aber ich denke dann wäre es vlt auch besser im foundry projekt mit ethers.js oder web3.js ein javascript testscript zu schreiben.
ich kann auch mit chisel oder cast (?) die tests komplett manuell machen... aber das finde ich schon kacke, dass ich dann nicht dokumentieren und nachweisen kann, dass ich die tests gemacht hatte und sie erfolgreich waren. ✅

make the testscript an actuall chai test. The problem loop i am facing now is since i did yarn add --dev @nomicfoundation/hardhat-chai-matchers@latest chai@latest - so find a way to revert this and go on from there -- maybe i should just go back to the last commit ✅
added event log checks ✅

add more functions to the testscript which test the contracts functionality
let eth get transfered at 5 owners ✅
add simpleErc721 and simpleERC20 ✅ (sepolia already deployed)
let erc20 get transfered at 2 owners ✅
let erc20 get transferFrom at 2 owners ✅
let erc721 get transfered at 4 owners ✅
let other function do something ✅

adapt the testscript for staging on sepolia and let it run once (be aware of gas costs!) ✅
deploy that new version of the multisig wallet and change the address in the .env ✅

create a new wallet (maybe metamask on the business brave profile) and put 500€ real ETH on it✅

Gasusage checken fürs deployment: ✅
deployment gas: 2575191 x 10^(-9) x 10 | x 40 = 0,02575191ETH <-> 0,10300764ETH = 62,35EUR <-> 249,43EUR
submit transaction: 200001 x 10^(-9) x 10 | x 40 = 0,00200001ETH <-> 0,00800004ETH = 4,84EUR <-> 19,37EUR
send ERC721 transaction: 222734 x 10^(-9) x 10 | x 40 = 0,00222734ETH <-> 0,00890936ETH = 5,39EUR <-> 21,57EUR
confirm transaction: 93255 x 10^(-9)x 10 | x 40 = 0,00093255ETH <-> 0,0037302ETH = 2,25EUR <-> 9,03ETH
last confirm (execute): 238701 x 10^(-9) x 10 | x 40 = 0,00238701ETH <-> 0,00954804 = 5,78ETH <-> 23,12EUR

prepare mainnet deploy script with real private key ✅

sepolia testeth besorgen ✅

✅ activate optimizer in the foundry.toml optimizer = true, optimizer_runs = 200 (10 for cheaper deployment, 5000 for cheaper executions)

use dotenv for the depoly scripts ✅

dont use dotenv at all and do it like patrick cyfrin explains it ✅

CI workflow run CI: All jobs have failed -> update the expected logs in the foundry test script ✅

Cyfrin nach audit fragen (wie sind die kosten?) und ob die auch Certora Prover oder andere Formal Verification tools nutzen - https://www.cyfrin.io/blog/solidity-smart-contract-formal-verification-symbolic-execution ✅

does the multisig wallet execute transactions as the wallet itself or as the owner who made the last confirmation? this is relevant for functions being called that use the msg.sender. ✅


➡️ _Mainnet deploy_ (Niklas Public Key, Stefan Public Key, Gasprice niedirg) -> Public keys ins deploy script und dann einfach nur den befehl ausführen


**optional toDo:** 

add getter function for latest transactionId

Gas Efficiency: 
Using assembly for decoding is efficient, but ensure it’s necessary for the data format you expect. Solidity's abi.decode could be used if the data format is consistent.
Use offchain services for transparency and only have this contract process the minimum things

add the transaction ID to the events of BatchtransferExecuted, OwnerAdded and OwnerRemoved

add newNumConfirmations in the event of confirmTransaction and revokeConfirmation

how about ERC777 and other token standards? How about implementing safeTransfer for ERC20 tokens? -> using a delegate call to a **fallback manager**. but at this point i should aswell use the **diamond setup** to have the whole contract upgradable I guess...


-
-
-
-
-
-
-

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
