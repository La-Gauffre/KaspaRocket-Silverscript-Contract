# KaspaRocket SilverScript Contracts

> **Note:** this README was written with AI assistance.

SilverScript covenant contracts for trading KCC20 tokens on Kaspa Layer 1. They are the on-chain core of [KaspaRocket](https://kasparocket.fun) and are written for **SilverScript 1.0**.

| File | Role |
|---|---|
| `kcc20.sil` | KCC20 fungible token (reference template) |
| `LP_AMM.sil` | Liquidity pool: bonding curve, then constant-product AMM |
| `Escrow_buy_token.sil` | Limit buy order: KAS locked, exchanged for tokens |
| `Escrow_sell_token.sil` | Limit sell order: tokens locked, exchanged for KAS |

## `kcc20.sil`: the token

Each token UTXO carries a balance in its state: `amount`, `owner`, `owner_scheme`, plus optional borrow settings. All UTXOs of a given token share one covenant id and one script template, so other contracts can recognise a genuine token output by its template hash.

- **Owner schemes:** P2PK Schnorr, P2PKH Schnorr, P2PKH ECDSA, P2SH, or **another covenant** (`OWNER_COVENANT_ID`, `0x04`). The last one is how pools and escrows hold tokens.
- **`transfer`:** the *leader* input. It gathers its own balance and up to 9 *delegate* inputs of the same token, checks that the outputs conserve the total amount (up to 10 outputs), and authorizes the spend.
- **`transfer_delegator`:** a *delegate* input. It only proves its owner's consent; the leader accounts for its balance and creates the outputs.

## `LP_AMM.sil`: the liquidity pool

One pool per token, paired with KAS. The token reserve sits in a KCC20 UTXO owned by the pool's covenant (the *vault*). The KAS reserve is the value of that vault UTXO. The pool records both reserves in its state and checks, on every swap, that the vault presented matches them.

`executeSwap` buys or sells `amount` tokens in two phases:

1. **Bonding curve** (`binary_flag = 0`). The price rises linearly with the supply sold, `price(S) = (a_num / a_den) · S + b`, and a trade pays the integral of that price. When `S` reaches `S1`, the pool switches to phase 2. The switch is irreversible.
2. **Constant-product AMM** (`binary_flag = 1`). Trades follow `reserve_kas · reserve_tokens = k`, rounded in favour of the pool. A minimum token reserve is always kept.

Curve parameters, the token and the fee recipient are fixed for the pool's lifetime.

## `Escrow_buy_token.sil`: limit buy order

The creator locks KAS and offers `kas_per_token` for up to `tokens_remaining` tokens, delivered to `buyer_pk`.

- **`fill`:** a partial fill. The filler delivers tokens to the buyer and receives the matching KAS. The order continues with the rest.
- **`close_fill`:** fills the whole remainder and closes the order. Any KAS left over is refunded to the creator.
- **`cancel`:** the creator takes all the remaining KAS back.

## `Escrow_sell_token.sil`: limit sell order

The creator locks tokens in a vault owned by the escrow's covenant and asks `kas_per_token` for each. The KAS goes to `seller_spk`.

- **`fill`:** a partial fill. The buyer pays the seller and receives tokens from the vault. The vault is rebuilt with the rest.
- **`close_fill`:** buys the whole vault and closes the order.
- **`cancel`:** the creator takes the remaining tokens back, together with the KAS carried by the vault and the escrow.

## Shared design

### One transaction, many covenants

Every covenant input owns a **block of 4 outputs** at the end of the transaction, derived from its input index:

```
base = tx.outputs.length - 4 * (activeInputIndex + 1)

base + 0   covenant continuation (pool or escrow), or refund on close
base + 1   tokens: the pool's updated vault, or the buyer's tokens
base + 2   KAS to the seller (sell escrow only)
base + 3   platform fee
```

Because each input reads only its own block, a single atomic transaction can combine the pool and several escrows. For example, one transaction can buy on the curve and fill resting orders at the same time, or fill an escrow with tokens just bought from the pool.

### Vault identification

A pool or sell escrow finds its vault among the token inputs by requiring **exactly one** token input whose owner is its own covenant id (`owner == OpInputCovenantId(this)`, `owner_scheme == 0x04`). Two vaults of different covenants in the same transaction therefore cannot be confused.

The buy escrow does the opposite. It only counts tokens that are **not** held by a covenant, so a filler cannot pass off a pool's vault as tokens of its own: the tokens must really be delivered.

### Fees

Each contract enforces a **minimum fee of 0.3%** of the KAS traded, paid to a fee recipient fixed at creation. A platform can charge more by paying a larger fee output. The contracts only check the floor.

### Integer safety

Prices and amounts are bounded (maximum slope, supply and KAS flow) so that the curve arithmetic stays within 64-bit integers.
