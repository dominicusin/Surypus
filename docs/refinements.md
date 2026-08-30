# Surypus DSL — Refinement Predicates & Domain Events

This document is **generated** by `surypus-codegen doc` from `dsl/schema.yaml`.
Do not edit by hand; edit the DSL `refinements:` / `events:` sections and re-run `build`.

## Refinement predicates (4)

### amount_non_negative

**Applies to:** Bill, Goods, Customer

Сумма документа неотрицательна.

```liquidhaskell
{v:Amount | v >= 0}
```

### vat_calculated

**Applies to:** Bill

НДС = нетто * 0.20 для российского НДС.

```liquidhaskell
{v:VatAmount | v == net * 0.20}
```

### stock_available_nonneg

**Applies to:** InventoryItem

Доступный остаток >= 0.

```liquidhaskell
{q:AvailableQty | q >= 0}
```

### reserved_le_quantity

**Applies to:** InventoryItem

Зарезервировано <= фактическое количество.

```liquidhaskell
{r:ReservedQty, q:Qtty | r <= q}
```

## Domain events (4)

### BillPosted

**Aggregate:** Bill

Счёт проведён: созданы проводки и запись аудита.

**Fields:** billId, amount, vat

### CustomerCreated

**Aggregate:** Customer

Клиент создан (CRM).

**Fields:** customerId, code, name

### CustomerCreditLimitChanged

**Aggregate:** Customer

Изменён кредитный лимит клиента.

**Fields:** customerId, creditLimit

### GoodsCreated

**Aggregate:** Goods

Товар/услуга созданы.

**Fields:** goodsId, code, name, price

