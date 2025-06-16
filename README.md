 stx-autosplit

A Clarity smart contract for automated and trustless STX payment splitting on the Stacks blockchain.

---

 Overview

`stx-autosplit` is a lightweight smart contract that allows users to split incoming STX payments among multiple recipients based on predefined percentage allocations. The contract eliminates the need for manual fund distribution, making it ideal for collaborative earnings, royalty sharing, and DAO-based revenue streams.

---

 Features

-  Register recipients with custom percentage shares
-  Automatically split deposited STX based on shares
-  Prevents over-allocation or rounding issues
-  Read-only functions for configuration and balance checks
-  Immutable configuration once locked (optional)

---

 Use Cases

- Revenue sharing for DAOs and multi-member projects  
- Automatic STX royalties for NFTs or content creators  
- Group freelance payment settlements  
- Creator-community revenue streams  
- Multi-sig team wallets with programmable split logic  

---

 Functions

Public Functions

- `set-splits (list (tuple (recipient principal) (share uint)))`:  
  Sets the list of recipients and their STX percentage shares. The total must sum to 100%.

- `deposit-and-split`:  
  Distributes the deposited STX among the recipients based on predefined shares.

- `lock-splits`:  
  Locks the split configuration to prevent further changes (optional governance control).

---

Read-Only Functions

- `get-recipients`:  
  Returns the list of registered recipients and their shares.

- `get-total-recipients`:  
  Returns the number of recipients in the split pool.

- `get-split-for (recipient)`:  
  Returns the percentage share for a given recipient.

---

## 🛠️ Deployment

You can deploy the contract using Clarinet or the Stacks CLI.

```bash
clarinet deploy contracts/stx-autosplit
