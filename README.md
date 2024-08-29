## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Third-Party Libraries

This project includes code from the following open-source project(s):

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) - Licensed under the MIT License.
- further see the "third-party-licenses" folder

<br><br><br><br><br>

Next steps:

have two different numconfirmationrequired for normal transactions and adding/deleting users (does that make sense?) - leichte entscheidungen 50+1 und schwere 2/3 mehrheit
-> two nums implemented.✅
-> have them automatically and alwyas at 50+1 and 2/3✅

add a function to change the numConfirmationsRequired if ALL multisig owners confirm. make sure tho that it cant be higher than how many multisigowners exist at the given time. -> Since I use the automated logic it would make more sense to use the Diamond structure to make the whole contract and thus the logic itself upgradable ✅
Also doublecheck that if a multisigowner gets deleted that the numconfirmation gets reduced in case otherwise there would be more confirmations required than multisigowners exist. -> added note for that in the code ✅

add a function where the multisigOwner who submitted a transaction is able to cancel/delete it anytime before it has been executed. - i dont think thats necessary, since one can just revoke their confirmation. ✅

have two different numconfirmationrequired for normal transactions and adding/deleting users (does that make sense?) - leichte entscheidungen 50+1 und schwere 2/3 mehrheit ✅

❌ bei 2 ownern reicht die confirmation von einem um tokens zu transferieren also 50% +1 funktioniert nicht richtig

enhance the event information as explained by cGPT above

muss ich noch irgendwelche getter und setter funktionen schreiben?

Gas Efficiency: Using assembly for decoding is efficient, but ensure it’s necessary for the data format you expect. Solidity's abi.decode could be used if the data format is consistent.

Error Handling: Add more descriptive error messages for edge cases, such as invalid data formats or failed transactions.

natspec nochmal machen lassen weil ich ja sachen geändert hatte

using an enum instead of a boolean for isERC721 can make the code more readable and maintainable. Enums provide a clearer understanding of the possible states and can be extended more easily in the future if needed.

check if the 2/3 and 50%+1 really works for 2 3 4 5 6 7 8 99 999 owners

Reentrancy Guard: Use OpenZeppelin's ReentrancyGuard modifier for public and external functions to protect against reentrancy attacks. You already inherit from ReentrancyGuard, so applying its modifier to susceptible functions is advisable.

Add that with submitting there will automatically the confirm function be called (is that necessary?)

Remix Notes:

3 Owners:
0 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
1 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
2 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db

Abstimmung 1: Send 0.1 ETH to 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2 (Owner 2)
Worked

Abstimmung 2: Send 0.3 ETH to 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C (random third person)
Worked

Abstimmung 3: add owner 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
❌--> Ok i can submit the addOwner but when the other two existing owners want to confirm i get a "Transaction failed"

Abstimmung 4: remove owner 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB

Abstimmung 5: ERC20 verschicken lassen

Abstimmung 6: ERC721 verschicken lassen

How to use:
to deploy do not send ETH with it but put all the owners in [] seperated with ,
to submitTransaction write the value in WEI and if only ETH write 0x for data

ok jetzt mal das ganze in hardhat testen ob ich da mit dem simplified contract das gleiche problem habe oder ob es an remix liegt. wenn nicht dann schauen ob die erc721 und erc20 executes gehen. wenn ja dann einfach für die add und remove owner mit highlevel calls umprogrammieren - einfach erstmal wieder den hardhat node zum laufen bringen und dann statt mit der console mit scripten mit dem contract interargieren. vlt kann ich später mal hardhat durch foundry ablösen - vielleicht auch einfach mal mit cGPT komplett hardhat neu einrichten, also checken ob die version passt und dann neue projekt anlegen - remix sepolia funktioniert auch nicht, also wird hardhat wohl auch nicht funktionieren. das problem ist also im contract selbst. als nächstes schauen ob die erc721 und erc20 executes gehen. wenn ja dann einfach für die add und remove owner mit highlevel calls umprogrammieren
-> Also erc20 funktioniert, es ist wohl nur das problem mit dem internen call.
-> hab jetzt refactored um mit transactionType alles zu coordinieren. jetzt nochmal auf remix testen.

also implement the safeERC20 thing from open zepplin ✅

-> jetzt noch erc721 und erc20 testen dann hab ich eigentlich alles vorgetestet und kann an die richtigen tests mit hardhat oder foundry gehen
-----> continue here ❌ when testing the safeTransferFrom() function, i get an error similarly to before when i couldnt call the internal function addOwnerInternal. add a callback function with a console.log to verify if its the same situation. more details see cGPT

get the 2/3 consensus to work (50%+1 already seem to have worked correctly, just get it from the commit before the simplify commit)

Add licence files
use .env for privatekey und so

Some additional security considerations not directly tested here but worth keeping in mind:
Gas limits: Ensure that loops in your contract (like in deactivatePendingTransactions) can't cause out-of-gas errors with a large number of transactions.
Reentrancy: Your use of nonReentrant modifier is good. Make sure it's applied to all relevant functions.
Integer overflow/underflow: Solidity 0.8.x provides built-in overflow/underflow protection, which is great.
Event emission: Ensure all important state changes emit appropriate events for off-chain monitoring.

was mit ERC721 und ERC20 tests im testscript?

erst nochmal den erc721 transfer funktion checken ✅
add und remove owner checken -> nochmal von 3 initial ownern auf 5 hoch und auf 1 runter und wieder auf 3 hoch ✅
dann transfer eth erc20 ✅ und erc721 ✅ mit mehreren owneren checken (hierfür vlt 5 owners und unterschiedliche numImportantDecisionConfirmations wählen) ✅
dann richtiges extensives testscript schreiben ("now create a foundry testscript (\*.t.sol) that automatically tests all this stuff, transfering eth, erc20, erc721 and adding and removing owners and "other" (enum number 5) as well as all other functions extensively including the eventlogs")
dann alle anpassungen durchführen
funktion nochmal mit testscript bestätigen
extensives testscript und fuzzing schreiben

spießer proposals
transaction index should start with 1 instead of 0
for the transfer erc20 and 721 functions of the multisig wallet the from is obviously this.address, so it shouldnt be needed in the functions arguments

-
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
