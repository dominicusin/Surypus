# OpenPapyrus → Surypus: Reverse-Engineering Notes

## 1. System Entrypoint & Control Flow
- `ppmain` drives the legacy system: `/home/domini/src/petr/OpenPapyrusHS/OpenPapyrus/Src/ppmain/ppmain.cpp` acts as the bootstrapper for service/client/daemon modes via `PPSession`, `DS.Init`, and the `SrvCmd` state machine. This file defines how external commands reach the system (`run_server`, `run_client`, service install/start/stop) and how the session lifecycle is managed before any business logic runs.
- The same structure must reappear in Surypus as an orchestration module: Surypus currently exposes `Surypus/src/Main.hs` and `Surypus/src/APIServer.hs`, but we need to ensure they cover service vs. API server distinctions. Their orchestration should mirror `PPSession::Init`, `DS.SetMenu`, and the command dispatch so that service lifecycle, scheduled agents (RFID, sync), and manual UI drivers translate cleanly.

## 2. Documents & Accounting (PPObjBill)
- `PPObjBill` (declaration around `/home/domini/src/petr/OpenPapyrusHS/OpenPapyrus/Src/include/pp.h#L34813`) is the hub for every document. It is responsible for validation (`ValidatePacket`), persistence (`TurnPacket`, `UpdatePacket`, `ExtractPacket`), and invariants (`CheckAmounts`, double-entry bookkeeping, locking). The implementation in `OpenPapyrus/Src/pplib/c_bill.cpp` enforces consistency (see `PPObjBill::CheckAmounts`, `/home/domini/src/petr/OpenPapyrusHS/OpenPapyrus/Src/PPLib/c_bill.cpp#L177`) by recomputing totals from the packet and comparing them to stored amounts, issuing corrective logs, and touching payment flags.
- `PPObjBill` also orchestrates inventory transitions (`TurnInventory`, `TurnLocTrfrList`), ledger entries (`TurnPacket` → `PPObjAccTurn`), VAT (`BillTaxDiffs`, `PPBillPacket::SumAmounts`), and attachments (tags, serials, freight metadata). These control/data flows need to be captured into Surypus modules:
  - Document schema → `Surypus/src/Core/Document/Bill.hs`
  - Accounting ledger & double-entry → `Core/Accounting/Ledger.hs` plus LiquidHaskell invariants: `Σ Debit = Σ Credit`, `CheckAmounts` analogue, `Bill` totals matching line sum.
  - VAT/Tax hooks → `Core/Tax/TAX*.hs`.

## 3. Inventory & Stock
- Inventory dialogs (`OpenPapyrus/Src/PPLib/inventry.cpp`) rely on `PPBillPacket`, `PPObjBill::TurnInventory`, and `PPViewInventory` to expose stock snapshots and the ability to write-off/rollback. The code enforces invariants such as non-negative stock through `InventoryFilt::fSelExistsGoodsOnly` filters and `TurnInventory`'s checks (see `/home/domini/src/petr/OpenPapyrusHS/OpenPapyrus/Src/PPLib/inventry.cpp`).
- Surypus already contains `Surypus/src/Core/Inventory/Stock.hs` and `InventoryEx.hs`, but we must ensure:
  - LiquidHaskell invariants cover `stock(t+1) = stock(t) + income - outcome`
  - Inventory actions are typed (e.g., FIFO/LIFO) and map to stored procedures (`sql/consume_fifo.sql`?) in `Surypus/sql`.
  - All operations adjusting lots reference the same invariants as `SelectLotParam`, serial handling, and `GetClbNumberByLot`.

## 4. Cash/POS Hardware Flow
- Equipment modules in `PPEquip` (e.g., `frontol.cpp`, `setstart.cpp`) call `AddTempCheckAmounts` and `SetTempCheckAmounts` (`/home/domini/src/petr/OpenPapyrusHS/OpenPapyrus/Src/PPEquip/SetStart.cpp#L1295`, `/home/domini/src/petr/OpenPapyrusHS/OpenPapyrus/Src/PPLib/Cshses.cpp#L986`) to accumulate cash check totals before they are posted. These flows feed into `PPViewCSess` for session totals (`/home/domini/src/petr/OpenPapyrusHS/OpenPapyrus/Src/PPLib/V_csess.cpp`).
- Surypus modules responsible for POS/cash (e.g., `Core.Device`, `Core.CashOperation`) must reproduce:
  - `CheckAmounts` verification before committing.
  - Cash session aggregation, as reflected in `PPAsyncCashSession`.
  - Liquid invariants like `check_total = Σ(line_amount − discounts)` and non-negative change.

## 5. Payroll & Personnel
- `OpenPapyrus/Src/PPLib/salary.cpp` handles payroll envelopes, deductions, and net salary invariants. It produces payroll documents linked to `PPObjBill` and ensures `Net = Gross − Taxes − Deductions`.
- Surypus already organizes payroll logic in `Surypus/src/Core/HR/Salary.hs` (and related `Salary` modules). We must ensure the LiquidHaskell specs assert:
  - `salaryNet >= 0`, `gross >= net`, no overlapping pay periods (`theorem_no_period_overlap`), and payroll entries linked to `Person` entries (`Core.Party`).
  - Database tables `salary`, `salary_lines` (if present) reflect these invariants.

## 6. Supporting Metadata & Compliance (Serials, Tags, VAT)
- OpenPapyrus uses `ObjTag`, `LotExtCode`, and `AdvBillItem` structures (sliced across files like `objtag.cpp`, `objgoods.cpp`, `objgtax.cpp`). For example, `PPObjBill::GetSerialNumberByLot` and `SetSerialNumberByLot` ensure each lot's serial numbers align with documents, while `AdvBillItem` links to accounting entries.
- Surypus equivalents live under `Core.Inventory` (serial/tags) and `Core.Document`. We need to document which stored procedures (`sql/*`) support `calc_vat`, `consume_fifo`, `create_bill`, etc., so heavy relational computations stay in Postgres while Haskell manages invariants.

## 7. Surypus Coverage Gaps
- Compare the complete set of PPLib modules (inventory, accounting, HR, CRM, analytics, equipment) against Surypus Core modules. The architecture doc already maps many, but we should flag modules not yet matched (e.g., `PPObjSync`, `PPObjBpr`, `PPObjMsg`, `ppsoapclient`) by referencing `OpenPapyrus/Src/PPLib/objsync.cpp`, `msg` sources, and SOAP-related files.
- Each unmapped area should get a dedicated LiquidHaskell-typed module (e.g., `Core.Sync`, `Core.Message`, `Core.Integration.SSOAP`). Document them with at least a placeholder typeclass + invariants, so re-engineering can proceed iteratively.

## Next Steps
1. Validate Surypus `Core` + `DAL` modules against this mapping and explicitly mark missing pieces; create issue list or TODO file for each domain.
2. Formalize LiquidHaskell invariants for `PPObjBill::CheckAmounts`, inventory usage of lots, payroll period constraints, and cash change correctness.
3. Drive heavy operations into PostgreSQL via stored procs listed in `Surypus/sql` while keeping Haskell validation wrappers.
4. Expand Surypus orchestration layer (`Main.hs`, `Universe` modules) to mimic `ppmain`'s lifecycle, including service commands and asynchronous jobs (RFID, sync) in Haskell (via `JobQueue`/`Cron` modules).

## Surypus Domain Mapping (current coverage)
- Document pipeline: `Surypus/src/Core/Document.hs`, `Surypus/src/Core/BillLine.hs`, `Surypus/src/Core/BillStatusEx.hs`, and `Surypus/src/Core/BillTaxDiffs.hs` expose typed bill creators, per-line totals, and tax diffs that mirror `PPObjBill`/`PPBillPacket` flows. They should ultimately enforce the same invariants as `PPObjBill::ValidatePacket` and `CheckAmounts`.
- Accounting & ledger: `Surypus/src/Core/Accounting.hs`, `Surypus/src/Core/AccturnDiffs.hs`, and `Surypus/src/Core/AccPlan.hs` mirror general ledger, double-entry, and trial balance logic from `acct.cpp`/`accturn.cpp`. They surface the `AccountingScheme` typeclass described in `docs/ARCHITECTURE.md` so `Σ Debit = Σ Credit` and `balance(t+1) = balance(t) + turnover`.
- Inventory & warehouse: `Surypus/src/Core/Inventory.hs`, `Surypus/src/Core/InventoryEx.hs`, and `Surypus/src/Core/Warehouse.hs` together with `Surypus/src/Core/Inventory/Types/Stock.hs` and `Types/Lot.hs` implement stock/lot models. Stored procedures in `Surypus/sql/procedures.sql` (`calc_stock_balance`, `fifo_select_lots`, `calc_line_totals`, etc.) represent the heavy-lifting versions of `select lot`, `TurnInventory`, and `PPObjBill::SelectLot2`.
- Tax subsystem: `Surypus/src/Core/Tax.hs`, `GoodsTaxEx.hs`, `TaxInvoice.hs` and supporting modules (e.g., `BillTaxDiffs.hs`) provide VAT computation and invoice-specific tax parsing that correspond to `objgtax.cpp`, `bilvatax.cpp`, and `PPObjBill::CalcVAT`.
- HR/salary: `Surypus/src/Core/HR.hs`, `Surypus/src/Core/Salary.hs`, and related payroll helpers match `salary.cpp`'s payroll generation, deduction, and net salary invariants.
- Parties/contacts: `Surypus/src/Core/Party.hs`, `Person.hs`, `PersonEx.hs`, `Contact.hs`, and `Core/Address.hs` track counterparties just like `objpersn.cpp`/`objartcl.cpp`. The `checkInn` utilities implement the same validation as `theorem_inn_valid`.
- Integration & messaging: `Surypus/src/Core/Message.hs`, `Integration.hs`, `Notification.hs`, and `Sync.hs` cover the replacement of `objsync.cpp`, `ppmail.cpp`, and notification/logging subsystems. They need to hook into the `JobQueue`/`Cron` modules for scheduled tasks mirroring `ppserver` jobs.
- Database & DAL: `Surypus/src/DAL.hs`, `Surypus/src/DB.hs`, and the `Surypus/src/Database` directory define table records and queries; they should align with legacy tables (`BillTbl`, `AccTurnTbl`, `ReceiptTbl`) from `include/pp.h`. The stored procedures file is the execution counterpart to `PPObjBill::TurnPacket` and other TA-driven operations.

## Coverage Gaps to Address
1. **PPEquip/Hardware-first flows** (`OpenPapyrus/Src/PPEquip/*`): modules like `frontol`, `setstart`, `shtrihmf` accumulate check totals via `AddTempCheckAmounts` before posting (`OpenPapyrus/Src/PPLib/Cshses.cpp`). Surypus currently has `Core.Device` and POS models but lacks an equivalent temp-check aggregator; we should design a `CashSessionTemp` layer plus invariants ensuring `check_total = Σ(line_amount − discounts)`.
2. **SOAP/integration clients** (`OpenPapyrus/Src/SOAP`, `ppsoapclient.cpp`, `egais.cpp`): Surypus does not yet provide `Core.SOAP` or EGAIS-specific clients. We need modules that mirror the request/response semantics and guarantee invariants such as `theorem_mark_unique` and `status` integrity.
3. **PPObjSync & offline sync** (`OpenPapyrus/Src/PPLib/objsync.cpp`): The legacy sync engine handles data diffs between instances. Surypus has `Core.Sync`, but we should validate whether it encapsulates the same state machine (change logs, versioning) and output invariants. If not, extend it with events derived from `objsync.cpp`.
4. **Complex analytics (v_* views)**: OpenPapyrus builds numerous virtual views (`v_bill`, `v_inv`, `v_psnev`, etc.) to drive reports and dashboards. Surypus has `Core/Analytics.hs`, but the data coverage/versioning may not reach all `v_*` models. We should inventory the most critical ones (`v_balanc`, `v_inv`, `v_tsess`) and ensure Surypus offers equivalent derived data (perhaps via SQL `views` or `Hasql` queries).
5. **Automated jobs and services**: The `ppserver` job scheduler (RFID, sync, crm) exists in `ppserver.cpp`, `ppjob.cpp`, `ppserv`. Surypus needs equivalent service runners (maybe in `Core/JobQueue.hs` + `Cron.hs`), but we must prove they can emulate the `SrvCmd` flows and the `PPSession` orchestrated start/stop commands.
