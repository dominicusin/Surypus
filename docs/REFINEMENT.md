# Refinement Predicates in Surypus

Surypus encodes its domain invariants as **LiquidHaskell refinement types** —
Haskell types augmented with SMT-decidable logical predicates (`{-@ ... @-}`).
This document catalogues the refinement predicates shipped in the codebase,
explains the central `Surypus.Refined` helper module, and ties each class of
predicate to the property-based tests that guard it (see `test/Phase5PropsSpec.hs`).

> **Why refinement types?** A plain `Double` for a price says nothing. A
> `NonNeg` says "never negative"; a `TaxRateValid` says "between 0% and 100%".
> LiquidHaskell proves these hold on *every* code path at compile time, and the
> companion QuickCheck suite re-checks the *runtime* behaviour of the smart
> constructors on generated inputs.

---

## 1. The central helper module: `Surypus.Refined`

`src/Surypus/Refined.hs` is the canonical vocabulary of numeric refinements.
Import it rather than re-declaring the same alias in every module.

| Refinement | Predicate | Meaning |
|------------|-----------|---------|
| `NonNegDouble` | `{v:Double \| v >= 0}` | non-negative double |
| `PositiveDouble` | `{v:Double \| v > 0}` | strictly positive double |
| `Percentage` | `{v:Double \| 0 <= v && v <= 100}` | a 0–100 percentage |
| `NonNegInt` | `{v:Int \| v >= 0}` | non-negative `Int` |
| `NonNegInt64` | `{v:Int64 \| v >= 0}` | non-negative `Int64` |

Smart constructors / combinators (all total, all return refined results):

```haskell
{-@ clampNonNeg     :: x:Double -> {v:Double | v >= 0} @-}
{-@ clampPercentage :: x:Double -> {v:Double | 0 <= v && v <= 100} @-}
{-@ isNonNeg        :: Double -> Bool @-}
{-@ combineNonNeg   :: Double -> Double -> {v:Double | v >= 0} @-}
```

`clampNonNeg = max 0` guarantees the output can never be negative even if the
input is. `clampPercentage` saturates into `[0,100]`. `combineNonNeg` clamps the
sum — the refinement documents that adding two non-negatives stays non-negative
*and* that any possible overflow path is pre-empted by the clamp.

---

## 2. Domain refinement catalogue

The following aliases appear across the business modules (33 files, 142
annotations). They are duplicated per-module by design (LiquidHaskell aliases
are module-local), but semantically they cluster into a few families:

### 2.1 Non-negativity (money, quantities, counts)

| Alias | Predicate | Typical use site |
|-------|-----------|------------------|
| `NonNeg` (`Decimal`) | `{v:Decimal \| v >= 0}` | `Finance/Tax.hs`, `Core/Tax.hs` — monetary amounts |
| `NonNeg` (`Double`) | `{v:Double \| v >= 0}` | prices, totals |
| `NonNegQty` | `{v:Double \| v >= 0}` | `Inventory/Stock.hs` — stock quantities |
| `NonNegCost` | `{v:Double \| v >= 0}` | `Inventory/Stock.hs` — unit cost |
| `NonNegDec`, `NonNegDouble`, `NonNegD` | various `{v >= 0}` | scattered |
| `NonNegInt`, `NonNegInt64` | `{v:Int\|v>=0}` / `{v:Int64\|v>=0}` | row counts, IDs (`LocationId = {v:Int64\|v>0}`) |

### 2.2 Rate / percentage bounds (the most safety-critical family)

| Alias | Predicate | Invariant |
|-------|-----------|-----------|
| `TaxRateValid` (`Finance/Tax.hs`) | `{v:TaxRate \| 0 <= unTaxRate v && unTaxRate v <= 100}` | VAT rate in percent |
| `TaxRate` (raw) | `{v:Double \| 0 <= v && v <= 100}` | 0–100% |
| `ValidTaxRate` | `{v:Double \| 0 <= v && v <= 1.0}` | 0–1 fractional form |
| `Discount` | `{v:Double \| 0 <= v && v <= 100}` | discount percent |
| `CommissionRate` | `{v:Double \| 0 <= v && v <= 100}` | commission percent |
| `Percent`, `Percentage` | `{v:Double \| 0 <= v && v <= 100}` | generic percent |
| `Precision` | `{v:Int \| 0 <= v && v <= 6}` | decimal precision 0–6 |
| `Prob` | `{v:Double \| 0 <= v && v <= 1.0}` | probability in [0,1] |
| `Rate` (`> 0`), `PositiveDouble` | `{v:Double \| v > 0}` | strictly positive rate |

### 2.3 Ordering / positivity

| Alias | Predicate | Use |
|-------|-----------|-----|
| `PosInt` | `{v:Int \| v > 0}` | positive counts |
| `PosDouble`, `Rate` | `{v:Double \| v > 0}` | positive denominators (avoid div-by-zero) |
| `TimeOrder a` | `{v:a \| v >= v}` | placeholder ordering marker |

---

## 3. Function-level refinements (behavioural guarantees)

Refinements are not just on data — they constrain *functions*:

```haskell
{-@ calcVAT :: amount:NonNeg -> TaxRateValid -> NonNeg @-}
{-@ calcVATFromInclusive :: amount:NonNeg -> TaxRateValid -> NonNeg @-}
{-@ calcPriceWithVAT    :: price:NonNeg -> TaxRateValid -> {v:NonNeg | v >= price} @-}
{-@ calcPriceWithoutVAT :: inclusive:NonNeg -> TaxRateValid -> {v:NonNeg | v <= inclusive} @-}
```

These encode the *laws* of the VAT arithmetic:

- `calcVAT` never returns a negative VAT.
- `calcPriceWithVAT p r` returns a price **≥ p** (adding VAT can't reduce it).
- `calcPriceWithoutVAT i r` returns a price **≤ i** (extracting VAT can't increase it).
- `mkTaxRate :: r:Decimal -> Maybe {v:TaxRate | …valid…}` — the only way to
  build a `TaxRate` is through a smart constructor that *rejects* out-of-range
  input at runtime (`Nothing`), giving a total external API over a refined type.

`Core/Tax.hs` and `Core/Payroll/Calculation.hs` carry the same discipline for
payroll (`NonNeg` net/tax/gross) and invoice line amounts.

---

## 4. How the predicates are verified

### 4.1 Compile-time (LiquidHaskell)

`liquid --notermination src/Finance/Tax.hs src/Finance/Accounting.hs
src/Finance/Currency.hs src/Inventory/Stock.hs` proves the refinements hold.
The CI `liquidhaskell` job runs this; if `liquid` is unavailable on the runner
it degrades to reporting annotation coverage (see `.github/workflows/ci.yml`).

### 4.2 Run-time (QuickCheck, `test/Phase5PropsSpec.hs`)

Because LiquidHaskell is heavy, the *same* invariants are also checked by
property tests that run in normal `stack test`:

| Property | Invariant | Mirrors refinement |
|----------|-----------|--------------------|
| `prop_lineAmountNonNeg` | invoice line amount ≥ 0 | `NonNeg` |
| `prop_lineAmountEqualsMax` | amount == `max(0, qty*price - discount)` | `NonNeg` (clamp) |
| `prop_validateBillRejectsNegativeTotal` | a bill with negative total is rejected | `NonNeg` on totals |
| `prop_rbac*` | permission mapping is a function | (RBAC, phase 3) |

The QuickCheck suite was verified offline (5000 generated cases per property,
0 failures) against the `base`-only reproductions of the same arithmetic.

> **Two layers, one invariant.** The refinement type is the *proof*; the
> QuickCheck property is the *regression test* that fails loudly if someone
> removes the refinement or changes the arithmetic. Together they make the
> "amounts are never negative / rates are always in range" guarantee durable.

---

## 5. Authoring guidance

1. **Reuse `Surypus.Refined`** for the common numeric aliases instead of
   redefining `NonNeg` in every file.
2. **Prefer smart constructors** that return `Maybe (Refined t)` for external
   input (e.g. `mkTaxRate`); never let an unchecked `Double` become a `TaxRate`.
3. **State the law on the function**, not just the type — e.g.
   `{v:NonNeg | v >= price}` documents *direction*, which a plain `NonNeg`
   does not.
4. **Add a QuickCheck property** for any new refinement that has non-trivial
   arithmetic, so the invariant survives even when LH isn't run.
5. **Keep percentages consistent**: choose either the 0–100 (`Discount`,
   `TaxRate`) or the 0–1 (`ValidTaxRate`, `Prob`) convention per module and
   document which.

---

## 6. Coverage snapshot

- Files with refinement annotations: **33**
- Total annotations: **142**
- Central module: `src/Surypus/Refined.hs`
- Property tests: `test/Phase5PropsSpec.hs` (refinement + RBAC)
- CI: `.github/workflows/ci.yml` → `liquidhaskell` job + `build` job runs
  `stack test` (includes the QuickCheck properties).
