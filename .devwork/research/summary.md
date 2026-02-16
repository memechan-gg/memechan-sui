# Research Summary

## Prompt
# PR #2: Release

## Diff
```diff
diff --git a/codegen/CHANGELOG.md b/codegen/CHANGELOG.md
new file mode 100644
index 0000000..d8c95fb
--- /dev/null
+++ b/codegen/CHANGELOG.md
@@ -0,0 +1,17 @@
+### Changelog
+
+# 15 05 2024
+v.1.0.35
+Upgrade contract:
+new package address: 0x80229d697d3a6dc4d410d312199e3c8495ea5ff28317c499bef3c1989ee7e64a
+old package address: 0xc48ce784327427802e1f38145c65b4e5e0a74c53187fca4b9ca0d4ca47da68b1
+
+
+# 22 05 2024
+v.1.0.36
+Upgrade contract:
+new package address: 0xa8f5987d3a6572015d3d6194d67e4c9629cd248a162e084f8a9a8e4f6ebe4ee4
+old package address: 0xc48ce784327427802e1f38145c65b4e5e0a74c53187fca4b9ca0d4ca47da68b1
+
+- Fix issue with distributing only admin fees
+- Fix issue with minting more meme than it should into CLMM
diff --git a/codegen/package.json b/codegen/package.json
index 7f154e4..a73102c 100644
--- a/codegen/package.json
+++ b/codegen/package.json
@@ -1,6 +1,6 @@
 {
   "name": "@avernikoz/memechan-ts-interface",
-  "version": "1.0.34",
+  "version": "1.0.36",
   "author": "aldrin-labs (@0xxgen, @comradekoval)",
   "license": "private",
   "private": false,
diff --git a/interest/clamm/Move.lock b/interest/clamm/Move.lock
index f842be8..a052ea9 100644
--- a/interest/clamm/Move.lock
+++ b/interest/clamm/Move.lock
@@ -2,22 +2,21 @@
 
 [move]
 version = 0
-manifest_digest = "2474853B4B26F5E59C794B83920449CE83441C809FAD7C4D8558EE66991ACE29"
-deps_digest = "060AD7E57DFB13104F21BE5F5C3759D03F0553FC3229247D9A7A6B45F50D03A3"
+manifest_digest = "D2708BF8A8FB4900D6FEA92AF8A9FBD64F14D6E160104F2F7C81528BE1463D87"
+deps_digest = "3C4103934B1E040BB6B23F1D610B4EF9F2F1166A50A104EADCF77467C004C600"
 
 dependencies = [
-  { name = "MoveStdlib" },
   { name = "Sui" },
   { name = "SuiTears" },
 ]
 
 [[move.package]]
 name = "MoveStdlib"
-source = { git = "https://github.com/MystenLabs/sui.git", rev = "framework/mainnet", subdir = "crates/sui-framework/packages/move-stdlib" }
+source = { git = "https://github.com/MystenLabs/sui.git", rev = "mainnet-v1.22.0", subdir = "crates/sui-framework/packages/move-stdlib" }
 
 [[move.package]]
 name = "Sui"
-source = { git = "https://github.com/MystenLabs/sui.git", rev = "framework/mainnet", subdir = "crates/sui-framework/packages/sui-framework" }
+source = { git = "https://github.com/MystenLabs/sui.git", rev = "mainnet-v1.22.0", subdir = "crates/sui-framework/packages/sui-framework" }
 
 dependencies = [
   { name = "MoveStdlib" },
@@ -25,7 +24,7 @@ dependencies = [
 
 [[move.package]]
 name = "SuiTears"
-source = { git = "https://github.com/interest-protocol/suitears.git", rev = "mainnet-1.0.0-beta", subdir = "contracts" }
+source = { local = "../suitears" }
 
 dependencies = [
   { name = "MoveStdlib" },
@@ -33,6 +32,6 @@ dependencies = [
 ]
 
 [move.toolchain-version]
-compiler-version = "1.22.0"
-edition = "legacy"
+compiler-version = "1.25.0"
+edition = "2024.beta"
 flavor = "sui"
diff --git a/interest/clamm/Move.toml b/interest/clamm/Move.toml
index 8946795..4f3cbca 100644
--- a/interest/clamm/Move.toml
+++ b/interest/clamm/Move.toml
@@ -4,7 +4,7 @@ edition = "2024.beta"
 license = "MIT"
 authors = ["Jose Cerqueira (jose@interestprotocol.com)"]
 version = "4.0.0-alpha"
-published-at = "0x429dbf2fc849c0b4146db09af38c104ae7a3ed746baf835fa57fee27fa5ff382"
+published-at = "0x2a106ca08831543cb7420d9e3893b11cf38573c02346ca337c048db6c36f3f5a"
 
 [dependencies]
 Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "mainnet-v1.22.0" }
diff --git a/interest/clamm/sources/pool.move b/interest/clamm/sources/pool.move
index dced675..f10717e 100644
--- a/interest/clamm/sources/pool.move
+++ b/interest/clamm/sources/pool.move
@@ -383,7 +383,6 @@ module clamm::interest_pool {
     assert!(self.addy() == pool_address, errors::wrong_request_pool_address());
 
     let rules = (*hooks.rules.get(&name)).into_keys();
-    assert!(!rules.is_empty(), errors::invalid_hook_name());
 
     let rules_len = rules.length();
     let mut i = 0;
diff --git a/memechan/Move.lock b/memechan/Move.lock
index b5d7a31..f5f251b 100644
--- a/memechan/Move.lock
+++ b/memechan/Move.lock
@@ -2,7 +2,7 @@
 
 [move]
 version = 1
-manifest_digest = "EE69783B6AB721A2BA172CAD14C9AD5A2969B0FCB5167CDB00DEFE6E11649A18"
+manifest_digest = "536786B820D24626FCA7480DA995EE2C177AD52088EAFA40E79B20437F1E5A83"
 deps_digest = "060AD7E57DFB13104F21BE5F5C3759D03F0553FC3229247D9A7A6B45F50D03A3"
 dependencies = [
   { name = "CLAMM" },
diff --git a/memechan/Move.toml b/memechan/Move.toml
index 53ea2e4..23462b2 100644
--- a/memechan/Move.toml
+++ b/memechan/Move.toml
@@ -2,7 +2,7 @@
 name = "Memechan"
 version = "0.0.1"
 edition = "legacy"
-published-at = "0xc48ce784327427802e1f38145c65b4e5e0a74c53187fca4b9ca0d4ca47da68b1"
+published-at = "0xa8f5987d3a6572015d3d6194d67e4c9629cd248a162e084f8a9a8e4f6ebe4ee4"
 
 [dependencies]
 Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "mainnet-v1.22.0" }
diff --git a/memechan/sources/live_phase/fee_distribution.move b/memechan/sources/live_phase/fee_distribution.move
index d7eaae0..6bb743a 100644
--- a/memechan/sources/live_phase/fee_distribution.move
+++ b/memechan/sources/live_phase/fee_distribution.move
@@ -216,4 +216,32 @@ module memechan::fee_distribution {
         let withdraw_diff_x = ((user_withdrawals as u256) * stake_diff) / PRECISION;
         (withdraw_diff_x as u64)
     }
+
+    public fun fees_meme<S, Meme>(self: &FeeState<S, Meme>): &Balance<Meme> {
+        &self.fees_meme
+    }
+
+    public fun fees_s<S, Meme>(self: &FeeState<S, Meme>): &Balance<S> {
+        &self.fees_s
+    }
+
+    public fun user_withdrawals_x<S, Meme>(self: &FeeState<S, Meme>): &Table<address, u64> {
+        &self.user_withdrawals_x
+    }
+
+    public fun user_withdrawals_y<S, Meme>(self: &FeeState<S, Meme>): &Table<address, u64> {
+        &self.user_withdrawals_y
+    }
+
+    public fun stakes_total<S, Meme>(self: &FeeState<S, Meme>): u64 {
+        self.stakes_total
+    }
+
+    public fun fees_meme_total<S, Meme>(self: &FeeState<S, Meme>): u64 {
+        self.fees_meme_total
+    }
+    
+    public fun fees_s_total<S, Meme>(self: &FeeState<S, Meme>): u64 {
+        self.fees_s_total
+    }
 }
\ No newline at end of file
diff --git a/memechan/sources/live_phase/go_live.move b/memechan/sources/live_phase/go_live.move
index af6acab..8fdcacc 100644
--- a/memechan/sources/live_phase/go_live.move
+++ b/memechan/sources/live_phase/go_live.move
@@ -15,8 +15,9 @@ module memechan::go_live {
     use memechan::events;
     use memechan::admin::Admin;
     use memechan::seed_pool::{Self as seed_pool, SeedPool, gamma_s};
-    use memechan::staking_pool;
-    use clamm::interest_pool;
+    use memechan::staking_pool::{Self, StakingPool};
+    use clamm::interest_pool::{Self, InterestPool, Request};
+    use clamm::curves::Volatile;
     use clamm::interest_clamm_volatile as volatile_hooks;
     use suitears::coin_decimals;
     use suitears::owner;
@@ -44,6 +45,19 @@ module memechan::go_live {
     const EBondingPoolNotReady: u64 = 0;
     const EBondingPoolMemeBalanceNotEmpty: u64 = 1;
     const EQuoteSupplyMismatch: u64 = 2;
+    const EAddLiquidityNotAllowed: u64 = 3;
+
+    public fun start_add_liquidity_request_and_approve<S, Meme, LP>(
+        staking_pool: &StakingPool<S, Meme, LP>, 
+        amm_pool: &InterestPool<Volatile>,
+        clock: &Clock
+    ): Request {
+        assert!(clock::timestamp_ms(clock) >= staking_pool::end_ts(staking_pool), EAddLiquidityNotAllowed);
+
+        let start_request = interest_pool::start_add_liquidity(amm_pool);
+        interest_pool::approve(&mut start_request, AddLiquidityHook {});
+        start_request
+    }
 
     // Admin endpoint
     public fun go_live_default<Meme, LP>(
@@ -228,6 +242,50 @@ module memechan::go_live {
         owner::destroy(decimals_cap);
     }
 
+    public fun extract_excess_liquidity<S, Meme, LP>(
+        _admin: &Admin,
+        amm_pool: &mut InterestPool<Volatile>,
+        staking_pool: &mut StakingPool<S, Meme, LP>,
+        gamma_m: u64,
+        omega_m: u64,
+        clock: &Clock,
+        ctx: &mut TxContext,
+    ) {

... (truncated)
```

## Task
Review and improve the changes in this PR based on the diff.


## Findings
# PR #2: Release - Detailed Summary

## Project Overview

This is a **Sui blockchain** project using the **Move language**. It consists of three main packages:

1. **interest/clamm** - Concentrated Liquidity Automated Market Maker (CLAMM)
2. **memechan** - Main project with staking, fee distribution, and live phase logic
3. **codegen** - TypeScript interface generation for Sui smart contracts

---

## Package Versions

### From package.json (codegen)
```json
{
  "name": "@avernikoz/memechan-ts-interface",
  "version": "1.0.36",  // was 1.0.34
  "dependencies": {
    "@mysten/bcs": "0.11.1",
    "@mysten/sui.js": "0.51.2"
  }
}
```

### From Move.lock (interest/clamm)
- **Sui Framework**: `mainnet-v1.22.0` (rev: mainnet-v1.22.0)
- **Move compiler**: `1.25.0`
- **Edition**: `2024.beta` (changed from `legacy`)
- **SuiTears**: Now a local dependency (`local = "../suitears"`) instead of git

---

## Key Changes in This PR

### 1. CHANGELOG.md (NEW FILE)
Added documentation for versions 1.0.35 and 1.0.36:
- **v.1.0.35**: Contract upgrade (new package address)
- **v.1.0.36**: Contract upgrade with bug fixes:
  - Fix: distributing only admin fees
  - Fix: minting more meme than it should into CLMM

### 2. CLAMM Pool Change (interest/clamm/sources/pool.move)
**REMOVED** this assertion:
```move
assert!(!rules.is_empty(), errors::invalid_hook_name());
```
**Impact**: Allows hooks with empty rules to be processed. This is a **relaxation of validation** that could affect security assumptions if empty rules were previously considered invalid.

### 3. New Getters in FeeState (memechan/sources/live_phase/fee_distribution.move)
Added 7 new **public getter functions** to expose FeeState internals:

| Function | Return Type | Description |
|----------|-------------|-------------|
| `fees_meme<S, Meme>(self: &FeeState<S, Meme>)` | `&Balance<Meme>` | Get meme fees balance |
| `fees_s<S, Meme>(self: &FeeState<S, Meme>)` | `&Balance<S>` | Get S token fees balance |
| `user_withdrawals_x<S, Meme>(self: &FeeState<S, Meme>)` | `&Table<address, u64>` | Get user's X withdrawals |
| `user_withdrawals_y<S, Meme>(self: &FeeState<S, Meme>)` | `&Table<address, u64>` | Get user's Y withdrawals |
| `stakes_total<S, Meme>(self: &FeeState<S, Meme>)` | `u64` | Total stakes |
| `fees_meme_total<S, Meme>(self: &FeeState<S, Meme>)` | `u64` | Total meme fees |
| `fees_s_total<S, Meme>(self: &FeeState<S, Meme>)` | `u64` | Total S token fees |

**Note**: These functions break encapsulation by exposing internal `Table` and `Balance` references directly.

### 4. New Liquidity Function (memechan/sources/live_phase/go_live.move)

Added new function and constants:

```move
const EAddLiquidityNotAllowed: u64 = 3;

struct AddLiquidityHook has drop {}

public fun start_add_liquidity_request_and_approve<S, Meme, LP>(
    staking_pool: &StakingPool<S, Meme, LP>, 
    amm_pool: &InterestPool<Volatile>,
    clock: &Clock
): Request {
    assert!(clock::timestamp_ms(clock) >= staking_pool::end_ts(staking_pool), EAddLiquidityNotAllowed);

    let start_request = interest_pool::start_add_liquidity(amm_pool);
    interest_pool::approve(&mut start_request, AddLiquidityHook {});
    start_request
}
```

**Functionality**: Creates and approves an add liquidity request, only allowed after the staking pool end timestamp.

---

## Import Paths (from go_live.move)

Key imports used in the project:
```move
use memechan::staking_pool::{Self, StakingPool};
use clamm::interest_pool::{Self, InterestPool, Request};
use clamm::curves::Volatile;
use clamm::interest_clamm_volatile as volatile_hooks;
use suitears::coin_decimals;
use suitears::owner;
use memechan::utils::mist;
use suitears::math256::mul_div_up;
```

---

## Contract Addresses (from Move.toml)

| Package | Old Address | New Address |
|---------|-------------|-------------|
| Memechan | `0xc48ce784327427802e1f38145c65b4e5e0a74c53187fca4b9ca0d4ca47da68b1` | `0xa8f5987d3a6572015d3d6194d67e4c9629cd248a162e084f8a9a8e4f6ebe4ee4` |
| CLAMM | `0x429dbf2fc849c0b4146db09af38c104ae7a3ed746baf835fa57fee27fa5ff382` | `0x2a106ca08831543cb7420d9e3893b11cf38573c02346ca337c048db6c36f3f5a` |

---

## Project Structure Conventions

1. **Move projects** use `Move.toml` for configuration and `Move.lock` for dependency locking
2. **TypeScript codegen** uses `sui-client-gen` with a `generate.toml` manifest
3. **Edition 2024.beta** is the new Move language edition (previously `legacy`)
4. **Constants** are named with `E` prefix for errors (e.g., `EAddLiquidityNotAllowed`)

---

## Potential Gotchas

1. **Removed hook validation**: The removal of `assert!(!rules.is_empty())` may allow invalid hook configurations that were previously rejected
2. **Exposing internal state**: The new getter functions return `&Table` and `&Balance` references, allowing external modification of internal state
3. **Local dependency change**: SuiTears changed from git to local - ensure the local path exists
4. **Timestamp check**: The new `start_add_liquidity_request_and_approve` function requires `clock::timestamp_ms(clock) >= staking_pool::end_ts(staking_pool)` - ensure the staking pool has ended before calling
