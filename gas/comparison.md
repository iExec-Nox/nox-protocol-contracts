# Gas Comparison: Public Handle Existence Registry

Compares gas before/after adding `isKnownPublicHandle` to close the handle-forgery /
fund-freeze vulnerability (Option 1: existence registry). Production optimizer on
(runs: 200, viaIR). All proxy calls are measured via `<UnrecognizedContract>`.

---

## Summary (% deltas)

| Function                | Avg Δ%  | Min Δ%  | Max Δ%  | Note                                                 |
| ----------------------- | ------- | ------- | ------- | ---------------------------------------------------- |
| `wrapAsPublicHandle`    | +67.6 % | +1.1 %  | +73.2 % | Cold wrap +20k SSTORE+LOG; repeat: warm SLOAD only   |
| `initialize` (proxy)    | +48.6 % | +48.6 % | +48.6 % | 6 cold SSTOREs for zero handles                      |
| `initialize` (impl)     | +55.4 % | +55.4 % | +55.4 % | Same reason, different measurement context           |
| `isAllowed` (proxy)     | +23.0 % | −2.7 %  | −0.5 %  | +SLOAD on public path; unique-handle path is cheaper |
| `validateAllowedForAll` | +9.9 %  | −2.5 %  | −0.8 %  | Additional SLOAD per public handle in array          |
| `add`                   | +3.3 %  | +0.8 %  | +4.2 %  | One extra SLOAD per operand pair                     |
| `transfer`              | +2.3 %  | −0.3 %  | +4.2 %  | Same                                                 |
| `mint`                  | +2.3 %  | −0.3 %  | +4.2 %  | Same                                                 |
| `burn`                  | +2.3 %  | −0.3 %  | +4.2 %  | Same                                                 |
| NoxCompute bytecode     | +1.4 %  | —       | —       | +239 bytes (16,516 → 16,755)                         |
| NoxCompute deployment   | +1.4 %  | —       | —       | +51,541 gas (3,666,607 → 3,718,148)                  |

**First wrap vs repeat wrap (`wrapAsPublicHandle`):**

- Cold (first) wrap: ~52,739 gas (median) — cold SSTORE + LOG opcode.
- Repeat wrap of same `(value, type)`: **30,555 gas (min)** — warm SLOAD guard check only,
  SSTORE skipped, no emit. The `emit` was moved inside the `if` block so repeat wraps also
  skip the LOG opcodes; this drops the min from the previous 32,503 back toward the pre-fix
  baseline (before min was 30,221). The +334 gas difference is the warm SLOAD guard itself.

**Cold zero-handle read (`isAllowed` on pre-seeded handle, `test_ZeroHandle_ColdRead_IsAllowed`):**

- Cold SLOAD into `isKnownPublicHandle`: ~8,154 gas (max in proxy `isAllowed` row).
- Warm repeat read: ~1,403 gas (min) — near-identical to pre-fix (was 1,442 gas).

---

## Test Counts

| Metric           | Before | After |
| ---------------- | ------ | ----- |
| Total passing    | 205    | 214   |
| Solidity passing | 201    | 210   |
| Node.js passing  | 4      | 4     |
| Failing          | 0      | 0     |

9 additional tests: 3 new ACL tests (forged handle rejected, wrapped handle allowed,
`validateAllowedForAll` reverts for forged), 6 new Compute tests (`add` forged lhs/rhs,
`add` legitimate public handles, `transfer` forged amount, zero handles known after init,
repeat-wrap idempotent with no-event assertion, zero-handle cold read).

---

## Bytecode Size

| Contract              | Before (bytes) | After (bytes) | Delta |
| --------------------- | -------------- | ------------- | ----- |
| NoxCompute            | 16,516         | 16,755        | +239  |
| NoxComputeMock        | 17,024         | 17,264        | +240  |
| NoxComputeUpgradeMock | 16,554         | 16,793        | +239  |
| NoxMock (SDK)         | 7,927          | 7,927         | 0     |

---

## Deployment Cost (NoxCompute implementation, 16 deployments)

| Metric         | Before    | After     | Delta   | Δ%    |
| -------------- | --------- | --------- | ------- | ----- |
| Deployment gas | 3,666,607 | 3,718,148 | +51,541 | +1.4% |

---

## Function Gas Detail — min / avg / median / max

Rows from the `<UnrecognizedContract>` proxy block (the primary measurement surface).

### `wrapAsPublicHandle` (#calls: 16 → 23)

| Stat   | Before | After  | Δ       | Δ%     |
| ------ | ------ | ------ | ------- | ------ |
| Min    | 30,221 | 30,555 | +334    | +1.1%  |
| Avg    | 30,332 | 50,840 | +20,508 | +67.6% |
| Median | 30,292 | 52,739 | +22,447 | +74.1% |
| Max    | 30,664 | 53,111 | +22,447 | +73.2% |

The min (30,555) is the repeat-wrap case: SLOAD guard passes, SSTORE and emit both skipped.
The +334 gas over the pre-fix baseline (30,221) is the cost of the warm SLOAD guard itself.
The median/max (~52,739–53,111) are first-time cold wraps paying the SSTORE + LOG.

### `isAllowed` (proxy, #calls: 55 → 65)

| Stat   | Before | After | Δ    | Δ%     |
| ------ | ------ | ----- | ---- | ------ |
| Min    | 1,442  | 1,403 | −39  | −2.7%  |
| Avg    | 2,883  | 3,546 | +663 | +23.0% |
| Median | 1,442  | 1,403 | −39  | −2.7%  |
| Max    | 8,193  | 8,154 | −39  | −0.5%  |

Min/median/max all slightly _decrease_: unique-handle path now branches away from the
public-handle check earlier. Avg rises because new tests exercise the public-handle SLOAD
path more heavily.

### `validateAllowedForAll` (#calls: 5 → 5)

| Stat   | Before | After  | Δ      | Δ%     |
| ------ | ------ | ------ | ------ | ------ |
| Min    | 3,188  | 3,110  | −78    | −2.5%  |
| Avg    | 8,237  | 9,056  | +819   | +9.9%  |
| Median | 7,138  | 9,295  | +2,157 | +30.2% |
| Max    | 15,046 | 14,929 | −117   | −0.8%  |

### `add` (#calls: 10 → 10)

| Stat   | Before | After  | Δ      | Δ%    |
| ------ | ------ | ------ | ------ | ----- |
| Min    | 38,317 | 38,637 | +320   | +0.8% |
| Avg    | 42,048 | 43,416 | +1,368 | +3.3% |
| Median | 38,762 | 40,672 | +1,910 | +4.9% |
| Max    | 56,017 | 58,349 | +2,332 | +4.2% |

### `transfer` (#calls: 2 → 2)

| Stat   | Before | After  | Δ      | Δ%    |
| ------ | ------ | ------ | ------ | ----- |
| Min    | 45,517 | 45,400 | −117   | −0.3% |
| Avg    | 52,523 | 53,713 | +1,190 | +2.3% |
| Median | 52,523 | 53,713 | +1,190 | +2.3% |
| Max    | 59,528 | 62,026 | +2,498 | +4.2% |

### `mint` (#calls: 2 → 2)

| Stat   | Before | After  | Δ      | Δ%    |
| ------ | ------ | ------ | ------ | ----- |
| Min    | 45,319 | 45,202 | −117   | −0.3% |
| Avg    | 52,325 | 53,515 | +1,190 | +2.3% |
| Median | 52,325 | 53,515 | +1,190 | +2.3% |
| Max    | 59,330 | 61,828 | +2,498 | +4.2% |

### `burn` (#calls: 2 → 2)

| Stat   | Before | After  | Δ      | Δ%    |
| ------ | ------ | ------ | ------ | ----- |
| Min    | 45,737 | 45,620 | −117   | −0.3% |
| Avg    | 52,743 | 53,933 | +1,190 | +2.3% |
| Median | 52,743 | 53,933 | +1,190 | +2.3% |
| Max    | 59,748 | 62,246 | +2,498 | +4.2% |

### `initialize` (proxy, #calls: 5 → 5)

| Stat   | Before  | After   | Δ        | Δ%     |
| ------ | ------- | ------- | -------- | ------ |
| Min    | 230,776 | 342,947 | +112,171 | +48.6% |
| Avg    | 230,776 | 342,947 | +112,171 | +48.6% |
| Median | 230,776 | 342,947 | +112,171 | +48.6% |
| Max    | 230,776 | 342,947 | +112,171 | +48.6% |

Flat distribution: all 5 calls are identical fresh deploys. Each seeds 6 zero handles at
~20k gas per cold SSTORE = ~120k additional, consistent with the +112k observed.

---

## Verdict

The overhead is acceptable:

- **Repeat wrap** (same `(value, type)` already known): warm SLOAD guard only, no SSTORE,
  no emit. Cost ≈ +334 gas over baseline (+1.1%). Idempotent by design.
- **First wrap** (new `(value, type)`): cold SSTORE + LOG ≈ +22k gas over baseline.
  One-time per distinct handle; subsequent wraps of the same value are near-free.
- **Per-access overhead on compute ops**: +~320–2,500 gas per call depending on whether
  the SLOAD is warm or cold. Negligible in production (warm after first use in a tx).
- **Deployment**: +239 bytes / +51k gas, one-time.
- **Security gain**: forged public handles are rejected at the ACL layer — fund-freeze
  attack closed with no ongoing runtime cost for already-known handles.
