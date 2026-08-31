# Surypus ERP — План автономной реализации (2026-2027)

> **Источник:** `~/src/Surypus` (локальная копия `dominicusin/Surypus`, ветка `main`)  
> **ORM-референс:** pGenie — https://pgenie.io/docs/  
> **Цель:** весь ERP создаётся из единого DSL; при изменении DSL автоматически меняется ORM, SQL-миграции, Datalog, GET/POST API, QML и прочее

## Статус на начало планирования

- DSL-транспилер `surypus-codegen` — рабочий, компилируется, есть `build`/`check`/`migrate`/`version`
- `dsl/schema.yaml` — 54 сущности, извлечены из `src/DAL/Schema.hs` (Persistent TH)
- CI-гейт `surypus-codegen check` — добавлен в `.github/workflows/ci.yml`
- `SURYPUS_GEN_LOCK` — добавлен в `.gitignore`
- `strategic_analysis_pgenie_plan.md` — существующий стратегический план (459 строк)
- Процесс-архитектура: `process-architecture.md` — BMAD/SpecKit/GSD/Beads стек определён
- Beats-форпост: `beads.lock` = e88a57c на текущем состоянии

## Дополнения к целеполаганию

### 0. Процессная архитектура — отдельная фаза (была в context, но не в списке целей)

Из context: Surypus должен управлять разработкой через многослойную агентскую дисциплину:

```text
BMAD (.planning/CHARTER.md, .planning/initiatives/*.md)   → «зачем»
  → Spec Kit (.specify/, .openspec/changes/*)             → «что» (контракт)
    → Beads (.beads/beads.json)                            → граф состояний задач
      → GSD (.gsd/plan.md)                                 → «как» + evidence
```

Это означает:
- Новый агент не пишет план «с нуля» — он продолжает существующий граф
- Диаграмма lifecycle: Issue → Discovery → Architecture → Planning → Implementation → Test → Security → Performance → Documentation → Review → AutoApproval → Merge → Deploy → Post-deploy Verification

**Реализация:** фаза 0 создаёт каркас `.planning/`, `.specify/`, `.beads/` (если ещё нет) и `.gsd/` с шаблонами. Без этого остальные фазы выполняются «в вакууме».

### 1. CI-артефакт — уточнение

Из списка: «Довести DSL-транспайлер до статуса CI-артефакта» и позже «Перевод surypus-gen из standalone CLI в обязательный CI-гейт с блокировкой breaking changes».

Это одна цель в двух фазах:
- **Фаза 1:** транспилер работает как CI-артефакт (проверка, генерация, freeze)
- **Фаза 10:** CI-гейт блокирует мёрж при breaking changes (не просто проверяет синхронность, а сравнивает с предыдущей закоммиченной схемой и отвергает несовместимые изменения)

### 2. Bill posting flow — детализация

Из контекста: создание счёта → refinement-валидация → событие → проекции в учётные регистры → аудит.

**Уточнение:** нужно явно перечислить этапы:
1. Создание bill (BillEntity в DSL уже есть)
2. Валидация refinement-предикатов (суммы >= 0, VAT-соответствие, консервация при возврате)
3. Emission события (BillPostedEvent → event-store)
4. Проекция в регистры (Дебет/Кредит в accounting_entries, depleting в inventory_reserves)
5. Аудит-запись (AuditEntry с correlation ID)
6. Подтверждение (exit code / API response)

**Реализация:** фаза 2 — это полный сквозной сценарий через API + QML + проверка в DB.

### 3. RBAC middleware — детализация

«Подключение RBAC-middleware ко всем оставшимся маршрутам (не только к «важным»).»

**Уточнение:**
- Инвентаризация всех маршрутов из `API_DOCUMENTATION.md` (~50 endpoint'ов)
- Каждый маршрут должен иметь явную RBAC-политику (включая public для публичных)
- Стабилизация refresh-токенов: устранение известной проблемы надёжности (контекст: `fake-refresh-token` в `Surypus.JWT:117-137`, silent error elimination в `Surypus.RBAC:144-166`)

**Реализация:** фаза 3 — рефактор `Surypus.RBAC` и `Surypus.JWT` + инвентаризация маршрутов + подключение middleware.

### 4. Hardcoded stubs — замена

«Замена оставшихся hardcoded-заглушек в API-хендлерах реальной логикой — по инвентаризации, начиная с тех, что находятся на критическом пути (finance, auth).»

**Уточнение:** stubs проигнорированы в предыдущих патчах A-C, но не системно заменены. Фаза 2 (bill flow) и фаза 3 (auth) закрывают критический путь. Остальные stubs — как зависимость.

### 5. Observability — детализация

«Наблюдаемость: структурированное логирование с корреляцией по event sourcing correlation ID через все домены.»

**Уточнение:**
- Correlation ID передаётся через: API-запрос → event → projection → audit
- CircuitBreaker на всех внешних I/O-границах (БД, HTTP-клиенты, воркер)

**Реализация:** фаза 4 — это отдельная фаза, а не часть безопасности.

### 6. QuickCheck — детализация

Три группы property-тестов:
1. Refinement-предикаты Invoice aggregate (суммы >= 0, VAT-соответствие, консервация при возврате)
2. RBAC-политики (невозможность межтенантной эскалации)
3. Инварианты event sourcing (replay-детерминированность)

**Уточнение:** это замена AI-автоматизации патчей. Тесты должны быть в CI и блокировать мёрж при падении.

### 7. Job handlers — детализация

«Реализация Job handler'ов поверх существующего диспетчера воркера (патчи A–C дали только скелет).»

**Уточнение:** нужно посмотреть текущий скелет диспетчера и добавить обработчики. Это отдельная фаза, а не часть observability.

### 8. Payroll + Inventory — две отдельные фазы

PayrollService (event-sourced) — фаза 8.  
InventoryService (резервирование + движение) — фаза 9.

### 9. QML codegen — уточнение

«QML-кодогенерация для дополнительных форм за пределами MVP-сценария.»

**Уточнение:** MVP-сценарий (создание + просмотр счёта) — фаза 6. QML codegen для остальных форм — фаза 13, отдельная, низкий приоритет.

### 10. ERP domain expansion — условно Low

Из context: production/MRP, CRM, аналитика/отчётность — список из 15+ модулей (MES, APS, PLM, QMS, EAM, IIoT, WMS, TMS, OMS, SCM, SRM, S2P, CRM, CMS, CPQ, LMS, FMS, EPM, HCM, BI, MDM, PIM, BPM, PPM, ECM, GRC, ITSM, IAM).

**Уточнение:** это Low приоритет в списке, но в context упоминается как среди целей. Решение: отдельная фаза 14 «ERP доменное расширение» с приоритетом MODULE → всегда Low относительно фазы 1-13, но в списке для полноты.

---

## Фаза 0: Процессная архитектура и каркас (1 неделя)

### Цель
Задать процессную архитектуру Surypus: BMAD → Spec Kit → Beads → GSD → Git/CI. Без этого остальные фазы выполняются без процессногоControl.

### Задачи
1. **`.planning/` каталог:**
   - `CHARTER.md` — видение, принципы, ограничения
   - `initiatives/` — инитиативы (по одной на крупный модуль: ORM, API, Security, Frontend)

2. **`.specify/` каталог (Spec Kit):**
   - `README.md` — как пользоваться Spec Kit в Surypus
   - Шаблон `spec.md` — контракт для каждой реализуемой возможности
   - Шаблон `plan.md` — план реализации
   - Шаблон `tasks.md` — задача разбиения

3. **`.beads/` каталог (Beads):**
   - `beads.json` — граф задач (или `beads.lock` как форпост)
   - `metadata.json` — состояние
   - `issues.jsonl` — история задач

4. **`.gsd/` каталог (GSD):**
   - `plan.md` — план текущей фазы
   - Шаблоны workflow'ов из GSD

5. **`.github/workflows/ci.yml`:**
   - Уже есть, но добавить шаги для process-каталогов (валидация наличия, если нужно)

### Критерий завершения
- `.planning/CHARTER.md` существует
- `.specify/` имеет шаблоны
- `.beads/` имеет граф (или lock-файл)
- `.gsd/plan.md` есть для текущей фазы
- Все процессные файлы закоммичены

---

## Фаза 1: DSL-транспилер → CI-артефакт (2-3 недели)

### Цель
Транспилер `surypus-codegen` становится полноценным CI-артефактом: строит, проверяет, генерирует миграции, создаёт freeze-файл. CI проверяет синхронность DSL и сгенерированного кода.

### Текущее состояние
- `surypus-codegen` компилируется (GHC 9.2.8, `cabal build --project-file=surypus-codegen.project`)
- `build` генерирует `src/DAL/Schema.hs` и `src/DAL/Types.hs` из `dsl/schema.yaml`
- `check` проверяет, что сгенерированные файлы совпадают с DSL
- `migrate` эмитит SQL-миграции
- `version` выводит версию
- CI-гейт `surypus-codegen check` уже добавлен в `.github/workflows/ci.yml`
- `SURYPUS_GEN_LOCK` в `.gitignore`

### Что нужно добавить
1. **Подкоманда `freeze`:**
   - Создаёт `surypus.freeze` — хеш текущего `dsl/schema.yaml` + список сгенерированных артефактов с их хешами
   - Фиксирует, что транспилер «замorkил» схему для данной версии

2. **`SURYPUS_GEN_LOCK` в CI:**
   - При коммите DSL: транспилер проверяет, что сгенерированный код совпадает с закоммиченным
   - При изменении DSL без регенерации: CI падает
   - Форпост: `surypus.freeze` закоммичен; CI сравнивает текущий freeze с закоммиченным

3. **CI-гейт блокировки breaking changes (позже, фаза 10):**
   - Сравнение текущей схемы с предыдущей
   - Отвержение несовместимых изменений (удаление полей, изменение типов, удаление сущностей)

4. **Тестирование transpiler'а:**
   - Property-тест: round-trip DSL → generated → DSL даёт тот же DSL
   - Property-тест: generated code валиден (синтаксически, если не компилируется)

### Критерий завершения
- `surypus-codegen freeze` работает
- `surypus.freeze` создаётся и проверяется в CI
- CI провален, если DSL изменился, но сгенерированный код не обновлён
- `SURYPUS_GEN_LOCK` работает как форпост

---

## Фаза 2: Критический бизнес-цикл — Bill Posting Flow (3-4 недели)

### Цель
Сквозная реализация bill posting flow: создание счёта → refinement-валидация → событие → проекции в учётные регистры → аудит.

### Детали flow
1. **Создание bill:**
   - API: `POST /api/v1/bills` (или `POST /api/v1/invoices`)
   - Валидация входных данных (екзистирование контрагента, полей, сумм)
   - Создание `BillEntity` в DB

2. **Refinement-валидация:**
   - `theorem_bill_total`: сумма строк = итоговая сумма
   - `theorem_amounts_nonnegative`: все суммы >= 0
   - `theorem_vat_calculated`: VAT = Σ (price * qty * vat_rate)
   - Если валидация не проходит: ошибка 422 с деталями

3. **Emission события:**
   - `BillPostedEvent` в event-store
   - Correlation ID для трекинга

4. **Проекции в учётные регистры:**
   - Дебет/Кредит в `accounting_entries`
   - depleting в `inventory_reserves` (если bill связан с инвентарём)
   - Обновление сальдо по счётам

5. **Аудит:**
   - `AuditEntry` с correlation ID, пользователем, временем, действием

6. **Подтверждение:**
   - API возвращает созданный bill с ID
   - Клиент (QML) получает подтверждение

### Реализация
- **API:** `Surypus.API.Server` — обработчик `POST /api/v1/bills` (или инвойсов)
- **Refinement:** `src/Finance/Tax.hs`, `src/Finance/Accounting.hs` — расширить LiquidHaskell аннотациями или runtime-проверками
- **Event:** `Infrastructure.EventStore.*` — emission `BillPostedEvent`
- **Проекция:** `Finance.Accounting.*` — debit/credit, `Inventory.*` — depleting
- **Аудит:** `Audit.Persistence.*` — запись `AuditEntry`

### Критерий завершения
- `POST /api/v1/bills` создаёт bill, валидирует, эмитит событие, обновляет регистры, пишет аудит
- QML-клиент может создать bill через REST и увидеть его в списке
- В DB: bill, событие, проводки, аудит-запись — все связаны correlation ID
- Integration test: сквозной сценарий проходит

---

## Фаза 3: Периметр безопасности — RBAC + Refresh Tokens (2-3 недели)

### Цель
RBAC-middleware подключён ко всем маршрутам. Refresh-токены стабильны. Нет hardcoded-заглушек в auth.

### Задачи
1. **Инвентаризация маршрутов:**
   - Взять `API_DOCUMENTATION.md` (~50 endpoint'ов)
   - Для каждого маршрута указать: публичный / авторизованный / RBAC-специфичный
   - Создать mapping в `Surypus.RBAC.Policy` (или конфигурацию)

2. **Подключение RBAC-middleware:**
   - `Surypus.API.Server` — middleware, проверяет permission для каждого маршрута
   - Маршруты без явной политики: по умолчанию запрещены (или public, если указано)
   - Явные политики для всех маршрутов (включая public)

3. **Рефактор `Surypus.RBAC`:**
   - Убрать hardcoded-стейты (строки 144-166)
   - Подключить реальный permission store (или integrate с DAL.RBAC)
   - Реальная логика проверки permissions

4. **Рефактор `Surypus.JWT`:**
   - Убрать `fake-refresh-token` (строки 117-137)
   - Реализовать real refresh-token rotation
   - Устранить silent error elimination (логировать, но не падать; или корректно обрабатывать ошибки)

5. **Интеграция с CI:**
   - Тест: маршрут без permission возвращает 403
   - Тест: refresh-token rotation работает корректно (второй запрос с тем же токеном получает новый access + refresh)

### Критерий завершения
- Все маршруты имеют явную RBAC-политику
- RBAC-middleware проверяет permission для каждого запроса
- Refresh-token rotation стабилен (нет silent errors, реальная ротация)
- Интеграционные тесты проходят: 403 для недоступных маршрутов, rotate для refresh

---

## Фаза 4: Наблюдаемость — CircuitBreaker + Correlation ID (2 недели)

### Цель
CircuitBreaker на всех внешних I/O-границах. Структурированное логирование с корреляцией по event sourcing correlation ID.

### Задачи
1. **CircuitBreaker:**
   - Создать модуль `Surypus.CircuitBreaker` (или использовать библиотеку)
   - Применить к:
     - БД-пулу (DAL.ORMPool / DAL.DB)
     - HTTP-клиентам (RestClient в QML, или Haskell HTTP-клиент при внешних интеграциях)
     - Воркер-диспетчеру (если воркер делает внешние вызовы)
   - Политика: после N ошибок в M секунд — открытие на T секунд, затем half-open

2. **Correlation ID:**
   - Генерировать correlation ID на входе в API (если не передан)
   - Передавать через event sourcing: событие получает correlation ID
   - Проекции и аудит используют correlation ID для linking
   - Логи включают correlation ID

3. **Структурированное логирование:**
   - Модуль `Surypus.Logger` (или integrate с существующим)
   - Формат: JSON (или structured text) с полями: timestamp, level, correlation_id, module, message, context
   - Применять ко всем доменам: Finance, Inventory, Auth, API

### Критерий завершения
- CircuitBreaker открывается при инъекции ошибок (тест)
- Correlation ID передаётся от API → event → projection → audit
- Логи имеют структурированный формат с correlation ID

---

## Фаза 5: QuickCheck — тестовый каркас вместо AI-патчей (3-4 недели)

### Цель
QuickCheck property-тесты для: refinement-предикатов Invoice aggregate, RBAC-политик, инвариантов event sourcing. Тесты в CI, блокируют мёрж при падении.

### Задачи
1. **Refinement-предикаты Invoice:**
   - `prop_invoice_total_equals_sum_lines`: для любого invoice: total == sum(lines)
   - `prop_invoice_amounts_nonnegative`: все суммы >= 0
   - `prop_invoice_vat_calculated`: VAT == sum(lines.price * lines.qty * lines.vat_rate)
   - `prop_invoice_return_conserves`: refundInvoice(invoice) сохраняет общую сумму (total == 0 после refund)

2. **RBAC-политики:**
   - `prop_no_cross_tenant_escalation`: для любых tenant_id1 != tenant_id2, role1, resource1: checkPermission(tenant_id1, role1, resource1) != checkPermission(tenant_id2, role1, resource1) если ресурсы разные тенантам
   - `prop_permission_store_consistent`: если permission есть в store, middleware разрешает; если нет — запрещает

3. **Event sourcing replay:**
   - `prop_replay_idempotent`: replay(events) == replay(events) (детерминированность)
   - `prop_replay_gives_same_state`: replay(events) даёт то же состояние, что и apply(events) последовательно

4. **CI интеграция:**
   - `stack test` с флагом `--test-arguments --quickcheck`
   - CI: `stack test --flag QuickCheck` (или аналог)
   - При падении QuickCheck: CI красный, мёрж блокирован

### Критерий завершения
- Все три группы property-тестов написаны и проходят
- Тесты в CI
- При падении QuickCheck: CI красный

---

## Фаза 6: Web-фронтенд как канал верификации (2-3 недели)

### Цель
Web-фронтенд (QML) активирован как минимум для одного полного бизнес-сценария: создание и просмотр счёта. Это канал верификации архитектуры.

### Задачи
1. **QML-сценарий создания счёта:**
   - Форма создания bill (Input: code, billType, lines[])
   - Submit через RestClient (POST /api/v1/bills)
   - Успех: показ созданного bill в списке
   - Ошибка: показ validation errors

2. **QML-сценарий просмотра счёта:**
   - Список bills (GET /api/v1/bills)
   - Детали bill (GET /api/v1/bills/:id)
   - Просмотр lines, сумм, статуса

3. **Integracion test через QML:**
   - Создать bill через QML
   - Убедиться, что bill появился в списке
   - Убедиться, что в DB: bill, событие, проводки, аудит

4. **Верификация архитектуры:**
   - DSL → ORM → API → QML работает сквозь
   - Если изменение в DSL ломает QML — CI должен это ловить (через transpiler + тесты)

### Критерий завершения
- QML-приложение может создать bill и увидеть его в списке
- Создание bill через QML проходит сквозной flow (валидация → событие → проекция → аудит)
- QML-тест или ручная проверка проходит

---

## Фаза 7: Job Handler'ы на диспетчере воркера (2-3 недели)

### Цель
Реализация Job handler'ов поверх существующего диспетчера воркера. Патчи A-C дали только скелет — теперь real handlers.

### Задачи
1. **Исследование текущего скелета:**
   - Найти диспетчер воркера в codebase (поиск по `Worker`, `Job`, `Queue`, `Dispatcher`)
   - Понять интерфейс: как добавлять job, как выполнять, как статус

2. **Реализация handler'ов:**
   - Handler для бизнес-событий (например, `BillPostedJob` → отправка уведомления, генерация отчёта)
   - Handler для фоновых задач (например, `GenerateReportJob` → асинхронная генерация)
   - Интерфейс: `handleJob :: Job -> IO (Either JobError ())`

3. **Интеграция с event store:**
   - При emission события → создание job в очереди (если нужно)
   - Job выполняется воркером

4. **Тестирование:**
   - Property-тест: job выполняется корректно (без side-effect'ов при ошибке)
   - Интеграционный тест: событие → job → результат

### Критерий завершения
- Handler'ы реализованы для минимум 2 типов jobs
- Воркер выполняет jobs корректно
- Тесты проходят

---

## Фаза 8: PayrollService — event-sourced начисления (4-5 недель)

### Цель
PayrollService — полная реализация с event-sourced моделью начислений.

### Детали
1. **DSL:**
   - Добавить Payroll-сущности в `dsl/schema.yaml` (EmployeeSalary, PayrollRun, PayrollEntry и т.д.)
   - Типы: salary amount, tax rates, deductions, net pay

2. **Event sourcing:**
   - `PayrollRunStartedEvent`, `PayrollRunCompletedEvent`, `PayrollEntryCalculatedEvent`
   - Event-store хранит последовательность событий
   - Replay даёт текущее состояние payroll

3. **Refinement-валидация:**
   - Зарплата >= 0
   - НДФЛ <= сумма начислений
   - Итого к выплате = начисления - удержания

4. **API:**
   - `POST /api/v1/payroll/runs` — запуск начислений
   - `GET /api/v1/payroll/runs/:id` — статус и детали
   - `GET /api/v1/payroll/employees/:id/history` — история начислений

5. **Проекции:**
   - Обновление учётных записей сотрудников
   - Генерация выплат (интеграция с Finance)

### Критерий завершения
- PayrollService работает сквозь: DSL → ORM → API → event store → проекции
- QuickCheck property-тесты для payroll (суммы, валидация)
- Интеграционные тесты проходят

---

## Фаза 9: InventoryService — резервирование и движение остатков (4-5 недель)

### Цель
InventoryService — полная реализация, включая резервирование и движение остатков.

### Детали
1. **DSL:**
   - Добавить Inventory-сущности: `InventoryItem`, `StockReservation`, `StockMovement`
   - Типы: quantity, reserved_quantity, available_quantity, location_id

2. **Движение остатков:**
   - Приход: `StockReceived` → увеличение quantity
   - Расход: `StockIssued` → уменьшение quantity
   - Перемещение: `StockMoved` → уменьшение в одном location, увеличение в другом

3. **Резервирование:**
   - `StockReservation` — временное закрепление quantity для заказа/bill
   - При подтверждении bill → reservation конвертируется в расход
   - При отмене bill → reservation освобождается

4. **Refinement-валидация:**
   - available_quantity >= 0 (нельзя расходовать больше, чем есть)
   - reserved_quantity <= quantity
   - сумма резерваций <= quantity

5. **API:**
   - `POST /api/v1/inventory/reserve` — создать резервацию
   - `POST /api/v1/inventory/issue` — расходовать (после подтверждения)
   - `GET /api/v1/inventory/items/:id` — статус (quantity, reserved, available)
   - `GET /api/v1/inventory/movements` — история движений

6. **Проекции:**
   - Обновление `StockEntity` (или `InventoryItem`) при движениях
   - Аудит движений

### Критерий завершения
- InventoryService работает сквозь: DSL → ORM → API → event store → проекции
- Резервирование и движение работают корректно (available >= 0, зарезервированные корректно отчисляются)
- QuickCheck property-тесты для inventory invariants
- Сквозной сценарий: reservation → bill confirmation → issue → audit

---

## Фаза 10: CI-гейт — блокировка breaking changes (1-2 недели)

### Цель
Транспилер `surypus-codegen` становится обязательным CI-гейтом, который блокирует мёрж при breaking changes в DSL.

### Задачи
1. **Сравнение схем:**
   - При каждом PR: транспилер сравнивает текущую `dsl/schema.yaml` с закоммиченной (или с `main`)
   - Breaking changes: удаление сущностей, удаление полей, изменение типов полей, изменение enum-значений

2. **Блокировка:**
   - Если breaking changes detected: CI падает, мёрж блокирован
   - Если non-breaking changes (добавление сущностей, полей, не-breaking изменения): CI зелёный

3. **Пороговые значения:**
   - Breaking: удаление, тип-изменение, enum-изменение
   - Non-breaking: добавление, nullable-изменение (если не ломает существующий код)

4. **Опцией:**
   - `--allow-breaking` флаг для экстренных случаев (с явным обоснованием в PR)

### Критерий завершения
- CI блокирует мёрж при breaking changes
- CI зелёный при non-breaking changes
- Флаг `--allow-breaking` работает для экстренных случаев

---

## Фаза 11: Второй DSL-агрегат (InventoryItem/Employee) (2 недели)

### Цель
Расширение DSL-транспиллера на второй доменный aggregate для проверки generalisability.

### Детали
1. **Выбор aggregate:**
   - `InventoryItem` — логично, уже часть inventory flow
   - `Employee` — тоже логично, часть payroll
   - Рекомендация: `InventoryItem` как второй, потому что тесно связан с InventoryService (фаза 9)

2. **Расширение DSL:**
   - Добавить `InventoryItemEntity` в `dsl/schema.yaml` (или EmployeeEntity)
   - Поля: code, name, description, unit_id, category_id, min_stock, max_stock, location_id

3. **Генерация:**
   - `surypus-codegen build` генерирует ORM, Types, API, QML для InventoryItem
   - Проверка, что генерация общая (не специально заточена под Bill)

4. **Верификация generalisability:**
   - Добавить сущность → `build` → сгенерированный код работает (компилируется, тесты проходят)
   - Удалить сущность → `build` → сгенерированный код компилируется без неё

### Критерий завершения
- Второй aggregate (InventoryItem или Employee) добавлен в DSL
- `surypus-codegen build` генерирует код для него
- Код компилируется и тесты проходят
- Обратное удаление тоже работает

---

## Фаза 12: Документация refinement-предикатов в DSL (1 неделя)

### Цель
Документация refinement-предикатов как часть DSL-схемы, а не только в коде. Для аудируемости нетехническими стейкхолдерами.

### Задачи
1. **Расширение DSL-схемы:**
   - В `dsl/schema.yaml` добавить секцию `refinements` для каждой сущности
   - Пример:
     ```yaml
     entities:
       - name: BillEntity
         sql_table: bill
         fields:
           ...
         refinements:
           - name: total_equals_sum_lines
             description: "Итоговая сумма счёта равна сумме строк"
             formula: "bill_total == sum(bill_lines.amount)"
             type: invariant
           - name: amounts_nonnegative
             description: "Все суммы неотрицательны"
             formula: "all(bill_lines.amount >= 0)"
             type: invariant
     ```

2. **Генерация документации:**
   - `surypus-codegen doc` — генерирует Markdown-документацию из DSL
   - Документация включает: сущности, поля, refinement-предикаты с описанием

3. **Хранение:**
   - Сгенерированная документация в `docs/refinements.md` (или аналог)
   - В CI: документация генерируется и проверяется (нет рассинхронизации)

### Критерий завершения
- `dsl/schema.yaml` содержит refinement-предикаты для Invoice/Bill
- `surypus-codegen doc` генерирует документацию
- Документация в CI и доступна для аудита

---

## Фаза 13: QML-кодогенерация за пределами MVP (2-3 недели)

### Цель
QML-кодогенерация для дополнительных форм за пределами MVP-сценария (создание + просмотр счёта).

### Задачи
1. **Расширение транспиллера:**
   - Подкоманда `surypus-codegen qml` генерирует QML-формы из DSL
   - Для каждой сущности: форма создания, форма редактирования, форма списка

2. **Генерация:**
   - `PersonEntity` → PersonForm.qml, PersonList.qml
   - `GoodsEntity` → GoodsForm.qml, GoodsList.qml
   - `BillEntity` → BillForm.qml (уже есть MVP), BillList.qml

3. **Стилизация:**
   - Генерированные формы используют общий стиль (цвета, шрифты, layout)
   - Интеграция с `AppState.qml` и навигацией

4. **Верификация:**
   - Сгенерированные формы компилируются и работают в QML-приложении
   - Создание сущности через сгенерированную форму → API → DB (сквозной тест)

### Критерий завершения
- `surypus-codegen qml` генерирует формы для минимум 3 сущностей
- Сгенерированные формы работают в QML-приложении
- Сквозной тест: создание сущности через форму → API → DB

---

## Фаза 14: ERP доменное расширение (Low приоритет, долгосрочное)

### Цель
Расширение охвата ERP-доменов: production/MRP, CRM, аналитика/отчётность.

### Домены (из context)
- **Production/MRP:** MES, APS, PLM, QMS, EAM, IIoT
- **CRM:** CRM, CMS, CPQ, LMS
- **Финансы/аналитика:** FMS, EPM, HCM, BI, MDM, PIM
- **Управление:** BPM, PPM, ECM, GRC, ITSM, IAM

### Подход
Каждый домен — как фаза 11 (второй aggregate):
1. Добавить сущности в `dsl/schema.yaml`
2. `surypus-codegen build` → ORM, API, QML
3. Реализовать бизнес-логику (сервисы, event sourcing)
4. QuickCheck property-тесты
5. Интеграция с существующими модулями (например, Inventory + Production)

### Приоритизация доменов (рекомендация)
1. **Inventory (уже в фазе 9)** — критический путь
2. **Payroll (фаза 8)** — критический путь
3. **CRM (клиенты, лиды, продажи)** — следующая по важности
4. **Production/MRP (заказы, расходные материалы)** — зависит от Inventory
5. **Отчётность/BI** — зависит от данных в других модулях

### Критерий завершения
- Каждый домен добавлен в DSL, сгенерирован, реализован, протестирован
- Сквозные сценарии проходят

---

## Дорожная карта и приоритизация

### Критический путь (фазы 0-6 + 10)
Эти фазы закрывают базовую архитектуру: процесс, DSL-транспилер, бизнес-цикл, безопасность, наблюдаемость, frontend-верификация, CI-гейт.

| Фаза | Зависимости | Оценка | Приоритет |
|---|---|---|---|
| 0. Процесс | — | 1 неделя | Высокий |
| 1. DSL → CI-артефакт | 0 | 2-3 недели | Критический |
| 2. Bill Posting Flow | 1 | 3-4 недели | Критический |
| 3. RBAC + Refresh | 1 | 2-3 недели | Высокий |
| 4. Observability | 1, 2 | 2 недели | Высокий |
| 5. QuickCheck | 1 | 3-4 недели | Высокий |
| 6. Frontend верификация | 2, 3 | 2-3 недели | Высокий |
| 10. CI-гейт breaking changes | 1 | 1-2 недели | Критический |

### Высокий приоритет (фазы 7-9 + 11-12)
Эти фазы расширяют функциональность и доказывают generalisability.

| Фаза | Зависимости | Оценка | Приоритет |
|---|---|---|---|
| 7. Job Handler'ы | 0, 1 | 2-3 недели | Высокий |
| 8. PayrollService | 1, 5 | 4-5 недель | Высокий |
| 9. InventoryService | 1, 5, 11 | 4-5 недель | Критический |
| 11. Второй DSL-агрегат | 1 | 2 недели | Высокий |
| 12. Документация refinement | 1, 5 | 1 неделя | Средний |

### Низкий приоритет (фаза 13-14)
Расширение за пределами MVP.

| Фаза | Зависимости | Оценка | Приоритет |
|---|---|---|---|
| 13. QML codegen | 1, 6, 11 | 2-3 недели | Низкий |
| 14. ERP домены | 11, 12, 13 | Долгосрочно | Низкий |

### Параллелизация
- Фазы 0, 1独立 (процесс и DSL могут идти параллельно)
- Фазы 2, 3, 4, 5 могут идти параллельно после фазы 1 (разные команды/агенты)
- Фаза 6 зависит от 2 и 3 (нужен работающий bill flow и RBAC)
- Фаза 10 зависит от 1 (нужен работающий transpiler)
- Фазы 7, 8, 9, 11, 12, 13 могут идти параллельно после фазы 1 (разные домены)
- Фаза 14 зависит от всех предыдущих (домены строятся на базе)

---

## Уточнения к целеполаганию (говорящие в целях)

1. **Фаза 0 добавлена** — процессная архитектура (BMAD/SpecKit/GSD/Beads) не была в явном списке целей, но упоминалась в контексте. Без неё остальные фазы не have процессного каркаса.

2. **Фаза 1 и 10 разделены** — «довести до статуса CI-артефакта» и «перевод в обязательный CI-гейт с блокировкой breaking changes» — это две разные задачи. Первая: транспилер работает как артефакт. Вторая: CI блокирует breaking changes.

3. **Фаза 2 детализирована** — bill posting flow расписан по шагам (создание → валидация → событие → проекции → аудит). Это закрывает «сквозную реализацию» из списка.

4. **Фаза 3 объединяет RBAC и refresh-токены** — они взаимосвязаны (midleware зависит от JWT, JWT зависит от RBAC-store).

5. **Фаза 4 выделена отдельно** — observability не является частью безопасности; это отдельный concern с CircuitBreaker и корреляцией.

6. **Фаза 5 — QuickCheck** — три группы тестов (refinement, RBAC, event sourcing) как замена AI-патчей.

7. **Фаза 7 — Job handler'ы** — отдельная фаза, потому что зависит от диспетчера воркера (который уже есть в скелетном виде).

8. **Фаза 11 — второй DSL-агрегат** — это проверка generalisability, а не просто расширение. Важно, чтобы транспиллер работал с разными сущностями одинаково.

9. **Фаза 14 — ERP домены** — Low приоритет, но в списке для полноты. Каждый домен — как отдельный агрегат.

---

## Критерии готовности всего проекта

Проект считается готовым (MVP + extensible), когда:

1. **DSL-транспилер** — CI-артефакт, блокирует breaking changes, генерирует ORM/API/QML/Datalog из `dsl/schema.yaml`
2. **Bill Posting Flow** — сквозной сценарий работает (создание → валидация → событие → проекции → аудит)
3. **RBAC + Refresh Tokens** — все маршруты защищены, refresh-токены стабильны
4. **Observability** — CircuitBreaker на всех I/O, логи с корреляцией
5. **QuickCheck** — property-тесты для refinement, RBAC, event sourcing; в CI
6. **Frontend** — QML-сценарий создания и просмотра счёта работает
7. **Job Handler'ы** — реализованы на диспетчере воркера
8. **PayrollService** — event-sourced, работает
9. **InventoryService** — с резервированием и движением, работает
10. **Второй DSL-агрегат** — добавлен, транспиллер generalisable
11. **Документация refinement** — в DSL, генерируется, аудируема

Это 11 критериев. Если все выполнены — проект готов к расширению ERP-доменами (фаза 14).

---

## Что уже сделано (пре-трело)

- [x] Клонирование репо: `~/src/Surypus`
- [x] DSL-транспилер: `tools/surypus-codegen/` — компилируется, есть `build`/`check`/`migrate`/`version`
- [x] `dsl/schema.yaml` — 54 сущности из `src/DAL/Schema.hs`
- [x] CI-гейт `surypus-codegen check` — добавлен в `.github/workflows/ci.yml`
- [x] `SURYPUS_GEN_LOCK` — в `.gitignore`
- [x] `strategic_analysis_pgenie_plan.md` — стратегический план (459 строк)
- [x] `process-architecture.md` — BMAD/SpecKit/GSD/Beads стек
- [x] `beads.lock` — форпост состояния

## Ссылки на файлы

- DSL: `dsl/schema.yaml`
- Транспилер: `tools/surypus-codegen/Main.hs`, `tools/surypus-codegen/surypus-codegen.cabal`, `tools/surypus-codegen/surypus-codegen.project`
- Strategic plan: `strategic_analysis_pgenie_plan.md`
- Process architecture: `process-architecture.md`
- CI: `.github/workflows/ci.yml`
- API docs: `API_DOCUMENTATION.md`
- ORM: `src/DAL/Schema.hs`, `src/DAL/Types.hs`, `src/DAL/QueriesORM.hs`, `src/DAL/MutationsORM.hs`, `src/DAL/ClassifiersORM.hs`
- API: `Surypus/API/Server.hs`, `Surypus/API/*`
- RBAC: `Surypus/RBAC.hs`, `DAL/RBAC.hs`
- JWT: `Surypus/JWT.hs`
- Event store: `Infrastructure/EventStore/*`
- Finance: `src/Finance/Tax.hs`, `src/Finance/Accounting.hs`, `src/Finance/Currency.hs`
- Inventory: `src/Inventory/Stock.hs`
- QML: `frontend/qml/`
- Tests: `test/`
- SQL migrations: `sql/migrations/`

---

*План создан: 2026-08-29. Автор: AI-агент Surypus. Базовый репозиторий: `dominicusin/Surypus`.*