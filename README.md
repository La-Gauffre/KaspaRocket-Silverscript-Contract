# KaspaRocket Silverscript Contracts

This repository contains advanced Silverscript smart contracts for KCC20 token trading on Kaspa. It features an Automated Market Maker (AMM) with a dual-phase bonding curve and non-custodial escrow contracts for decentralized limit orders.

## Contracts Overview

### 1. `LP_AMM.sil` (Liquidity Pool AMM)
The Liquidity Pool operates using a unique dual-phase mathematical model:
- **Phase 1 (Bonding Curve):** Initially, the token price is determined dynamically along a linear bonding curve defined by `Price(S) = a * S + b`. Users can mint/buy or burn/sell tokens directly against this curve.
- **Phase 2 (Constant-Product AMM):** Once a predefined supply threshold (`S1`) is reached, the contract irreversibly transitions to a standard constant-product AMM model (similar to Uniswap V2) where `k = reserve_kas * reserve_tokens`.

**Key Features:**
- **Robust Security:** Prevents input spoofing attacks by rigorously verifying covenant ownership IDs (`ownerIdentifier == myCovId`).
- **Platform Fee:** Seamlessly integrates a 0.3% platform fee that is routed directly to a specified fee recipient address without interfering with the mathematical invariants.
- **Overflow-Safe:** Incorporates mathematically verified bounds to prevent integer overflows during complex bonding curve integration calculations.

### 2. `Escrow_buy_token.sil` (Limit Buy Order)
A decentralized limit buy order contract allowing users to securely lock KAS in exchange for tokens.
- **Mechanism:** The creator locks KAS and specifies a fixed price (`kas_per_token`), the total tokens desired, and the buyer's public key.
- **Filling:** Anyone can fill this order (partially or fully) by supplying the requested KCC20 tokens. In return, the filler receives the KAS locked in the escrow.
- **Anti-Aliasing:** Enforces canonical output indexing (`buyer_kcc20_out_idx == escrow_out_idx + 1`) to guarantee that the tokens are truly delivered to the buyer, preventing aliasing attacks.
- **Platform Fee:** Applies a 0.3% fee on the execution.

### 3. `Escrow_sell_token.sil` (Limit Sell Order)
A decentralized limit sell order contract allowing users to securely lock tokens in exchange for KAS.
- **Mechanism:** The creator locks KCC20 tokens inside a covenant-owned vault and specifies a fixed KAS price per token, along with the seller's KAS payout address (`seller_spk`).
- **Filling:** Anyone can fill the order by sending the required KAS to the seller. They receive the locked tokens from the vault in return.
- **Vault Identification:** Uses robust ID scanning (`vault_count == 1`) to accurately identify its specific vault among all transaction inputs, allowing it to coexist safely with other protocol vaults in the same transaction.
- **Platform Fee:** Applies a 0.3% fee on the execution.

## Composability & Interoperability

A major innovation of these contracts is their ability to securely interact with each other in a single atomic transaction. Because Silverscript operates on a UTXO model, arbitrageurs can construct transactions that simultaneously interact with an Escrow and the `LP_AMM` to execute flash-swap style trades without upfront capital.

### Atomic Arbitrage Scenarios

#### Scenario A: Arbitraging a Buy Escrow using the AMM
If an `Escrow_buy_token` offers a higher KAS price than the `LP_AMM`'s current token price, an arbitrageur can:
1. Buy tokens from the `LP_AMM` using KAS.
2. Immediately deliver those tokens to the `Escrow_buy_token` to receive the escrowed KAS.

**Security Measure:** To prevent a malicious user from simply tricking the Escrow into reading the AMM's token output as their own, `Escrow_buy_token.sil` intentionally filters out tokens owned by protocol vaults (identifier type `0x02`). It only counts tokens that are genuinely owned by a user (`0x00` or `0x01`). This forces the arbitrageur to legitimately source the tokens before the escrow unlocks the KAS.

#### Scenario B: Arbitraging a Sell Escrow using the AMM
If an `Escrow_sell_token` offers tokens at a lower price than the `LP_AMM`'s bid price, an arbitrageur can:
1. Buy tokens from the `Escrow_sell_token` by paying KAS to the seller.
2. Immediately sell those same tokens into the `LP_AMM` to extract KAS profit.

**Security Measure:** Because both the `LP_AMM` and the `Escrow_sell_token` rely on KCC20 vaults, placing both in the same transaction means there are multiple `0x02` covenant inputs. `Escrow_sell_token.sil` safely handles this by specifically identifying the vault whose `ownerIdentifier` strictly matches its own `OpInputCovenantId`. This prevents vault collision or injection attacks.

### Conclusion
By enforcing strict canonical output paths and distinguishing between user-owned (`0x00`/`0x01`) and protocol-owned (`0x02`) tokens, the KaspaRocket ecosystem enables highly liquid, secure, and fully composable on-chain trading directly on Kaspa Layer 1.
