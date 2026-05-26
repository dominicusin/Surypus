# System Architecture: Surypus ERP/CRM

## Архитектурные принципы

Система построена на принципах разделения ответственности (Layered Architecture) и доменно-ориентированного проектирования (DDD).

### Слои системы (Layer Separation)

1.  **Domain/**: Чистые доменные модели, типы данных и инварианты. Не зависят от БД или API.
2.  **Core/ (Service Layer)**: Бизнес-логика (расчет налогов, проведение документов, учет). Оркестрирует работу между DAL и внешними интерфейсами.
3.  **DAL/ (Data Access Layer)**: Доступ к PostgreSQL через Hasql и Rel8. Содержит репозитории и Event Store.
4.  **API/ (Handlers)**: REST эндпоинты (Scotty), преобразование JSON (Aeson) и Swagger спецификация.
5.  **Infra/**: Утилиты, логирование, работа с JWT, WebSocket и интеграции.

## Схема данных (Database Schema)

Основные домены в PostgreSQL:

- **RBAC**: `roles`, `permissions`, `user_roles`.
- **Inventory**: `goods`, `locations`, `stock`, `stock_movements`.
- **Accounting**: `accounts` (План счетов), `accounting_entries` (Проводки).
- **Documents**: `bills` (Документы), `bill_items` (Строки документов).
- **Service**: `jobs` (Очередь задач), `audit_log`, `schema_migrations`.

## Event Sourcing

В Phase 3 внедряется Event Sourcing для критических изменений:
- Все изменения состояния порождают события в таблице `event_store`.
- Читаемые модели (projections) обновляются на основе потока событий.
- Позволяет реализовать "Time Travel" аудит и надежную репликацию.

## Безопасность (Security)

- **Аутентификация**: JWT (Access + Refresh tokens).
- **Авторизация**: RBAC middleware проверяет разрешения (`requirePermission`) перед выполнением handler-а.
- **Целостность**: Формальная верификация через LiquidHaskell для финансовых расчетов (внедряется).

## Генерация отчетов

Используется гибридный подход:
- **PDF-Slave**: YAML-шаблоны для быстрой генерации стандартных форм.
- **JasperReports**: Сложные аналитические отчеты.

---
*Последнее обновление: 2026-05-14*
#  - Формально верифицированная система

## Архитектура

Проект  представляет собой формально верифицированную систему ERP, переписанную  на Haskell с использованием LiquidHaskell для математического доказательства корректности.

### Основные принципы

1. **Формальная верификация** - математические теоремы доказывают корректность
2. **Параметризованные модули** - TypeClasses для различных налоговых/бухгалтерских схем
3. **PostgreSQL stored procedures** - бизнес-логика на стороне БД
4. **Type-safe** - строгая типизация через Haskell

---

## Модули Core (формально верифицированные)

### 1. Core.Tax.Tax
**Описание**: Расчёт налогов (НДС, акцизы, налог с продаж). Соответствует C++ классам PPGoodsTaxEntry, GTaxVect в objgtax.cpp, objgtax.cpp

**Теоремы**:
- `theorem_vat_inclusion`: Сумма с НДС = Сумма без НДС + НДС
- `theorem_vat_nonnegative`: VAT ≥ 0
- `theorem_rate_valid`: Ставка в диапазоне [0, 100]
- `theorem_vat_increase`: Сумма с НДС ≥ Сумма без НДС
- `theorem_vat_roundtrip`: Обратный расчёт сохраняет сумму
- `theorem_vat_sum_preservation`: Σ сумм с НДС = Σ (сумм без НДС × (1 + ставка/100))

**Типы**:
- `VatRate` - ставка НДС (0%, 10%, 20%, 22%)
- `GoodsTaxEntry` - налоговая группа товара
- `VatBookEntry` - запись книги покупок/продаж
- `TaxCalcResult` - результат расчёта налога

### 2. Core.Tax.Russian
**Описание**: Налоги России (НДФЛ, УСН, страховые взносы, ЕНВД, патенты)

**Теоремы**:
- `theorem_ndfl_calc`: НДФЛ = Доход × Ставка
- `theorem_insurance_calc`: Взносы = ФОТ × Тариф
- `theorem_usn_income_calc`: УСН = Доходы × 6%
- `theorem_patent_calc`: Патент = Потенциальный доход × 6%
- `theorem_total_tax_burden`: Σ налогов ≤ Доход

### 3. Core.HR.Salary
**Описание**: Расчёт заработной платы

**Теоремы**:
- `theorem_salary_period_valid`: BegDate ≤ EndDate
- `theorem_salary_amount_nonnegative`: amount ≥ 0
- `theorem_no_period_overlap`: периоды не пересекаются
- `theorem_avg_leq_total`: среднее ≤ сумма
- `theorem_net_salary`: Net = Gross - Tax - Deductions

### 4. Core.Inventory.Stock
**Описание**: Складской учёт (FIFO/LIFO)

**Теоремы**:
- `theorem_stock_balance`: stock(t+1) = stock(t) + income - outcome
- `theorem_fifo_order`: сортировка по дате (старые первыми)
- `theorem_lifo_order`: сортировка по дате (новые первыми)
- `theorem_stock_nonnegative`: остаток ≥ 0
- `theorem_conservation_mass`: сохранение массы при списании

### 5. Core.Accounting.Ledger
**Описание**: Бухгалтерский учёт (двойная запись)

**Теоремы**:
- `theorem_double_entry`: Σ Debet = Σ Credit
- `theorem_balance_eq`: Σ дебетовых сальдо = Σ кредитовых сальдо
- `theorem_account_type_saldo`: тип счёта определяет сторону сальдо
- `theorem_saldo_continuity`: saldo(t+1) = saldo(t) + оборот
- `theorem_closing_balance`: начальное сальдо = конечному предыдущего

### 6. Core.Document.Bill
**Описание**: Документы (накладные, счета)

**Теоремы**:
- `theorem_bill_total`: Total = Σ строк
- `theorem_amounts_nonnegative`: все суммы ≥ 0
- `theorem_vat_sum`: VAT = Σ VAT строк
- `theorem_total_with_vat`: TotalWithVAT = Total + VAT

### 7. Core.Party.Party
**Описание**: Контрагенты (персоналии)

**Теоремы**:
- `theorem_inn_valid`: ИНН валиден (10 или 12 цифр)
- `theorem_kpp_valid`: КПП валиден (9 цифр)
- `checkInnRussia`: алгоритм проверки контрольной суммы ИНН

### 8. Core.EDI.Gtin
**Описание**: EDI, штрих-коды (GTIN, SSCC, GLN)

**Теоремы**:
- `theorem_gtin13_check_digit`: контрольная цифра GTIN-13
- `theorem_sscc18_check_digit`: контрольная цифра SSCC-18
- `theorem_gln13_check_digit`: контрольная цифра GLN-13
- `theorem_edi_line_gtin`: GTIN в EDI валиден

### 9. Core.Production.MRP
**Описание**: Производство, MRP планирование

**Теоремы**:
- `theorem_requirement_nonnegative`: потребность ≥ 0
- `theorem_lead_time_sum`: время = Σ операций
- `theorem_production_order_materials`: материалы = спецификация × количество

### 10. Core.Analytics.Analytics
**Описание**: Аналитика и отчёты. Соответствует C++ классам анализа в v_*.cpp

**Теоремы**:
- `theorem_rentability_range`: рентабельность ∈ [-100%, +∞)
- `theorem_turnover_nonnegative`: товарооборот ≥ 0
- `theorem_inventory_days_nonnegative`: оборачиваемость ≥ 0
- `invariant_amount_nonnegative`: все суммы ≥ 0

**Типы**:
- `TurnoverItem` - показатель товарооборота
- `ProfitabilityItem` - анализ прибыльности
- `DebtItem` - дебиторская/кредиторская задолженность
- `InventoryTurnover` - оборачиваемость запасов

### 11. Core.Document.Document
**Описание**: Документы (накладные, счета, чеки). Соответствует C++ классам PPBillPacket, PPTransferItem в objbill.cpp, c_trfr.cpp

**Теоремы**:
- `theorem_bill_total`: Σ строк = Итоговая сумма
- `theorem_line_sum`: Σ(кол-во × цена) = Сумма строк
- `theorem_bill_vat`: НДС по строках = НДС документа
- `theorem_quantity_nonnegative`: количество ≥ 0
- `invariant_amount_nonnegative`: сумма ≥ 0

**Типы**:
- `Bill` - документ (накладная)
- `TransferItem` - строка перемещения
- `CashCheck` - чек
- `CashSession` - кассовая сессия

### 12. Core.Party.Party
**Описание**: Контрагенты (юридические и физические лица). Соответствует C++ классам PPObjPerson, PPObjArticle в objpersn.cpp, objartcl.cpp

**Теоремы**:
- `theorem_inn_digits`: ИНН содержит только цифры
- `theorem_inn_format`: ИНН = 10 или 12 цифр
- `theorem_kpp_format`: КПП = 9 цифр
- `theorem_status_defined`: статус определён корректно
- `invariant_name_not_empty`: наименование не пустое

**Типы**:
- `Person` - контрагент
- `PersonRelation` - отношение между контрагентами
- `Contact` - контактная информация
- `Address` - адрес
- `Article` - статья (счёт для расчётов)

### 13. Core.Loyalty.Loyalty
**Описание**: Программы лояльности и дисконтные карты. Соответствует C++ классам SCardCore в objscard.cpp

**Теоремы**:
- `theorem_points_nonnegative`: баллы ≥ 0
- `theorem_balance_calc`: Баланс = Начислено - Списано
- `theorem_discount_limit`: скидка ≤ сумма
- `invariant_discount_percent`: скидка ∈ [0, 100]

**Типы**:
- `DiscountCard` - дисконтная карта
- `DiscountCardSeries` - серия карт
- `LoyaltyProgram` - бонусная программа
- `CardOperation` - операция по карте

### 14. Core.EDI.EDI
**Описание**: Электронный документооборот. Соответствует C++ классам в ppedi.cpp

**Теоремы**:
- `theorem_vat_nonnegative`: НДС ≥ 0
- `theorem_status_valid`: статус определён

**Типы**:
- `EDIDocument` - EDI документ
- `EDIProvider` - провайдер EDI
- `EDIConfig` - настройка обмена

### 15. Core.Trade.EGAIS
**Описание**: Алкогольный учёт (ЕГАИС). Соответствует C++ классу EgaisCore в egais.cpp

**Теоремы**:
- `theorem_writeoff_nonnegative`: списание ≥ 0
- `theorem_balance_calc`: Остаток = Приход - Списание
- `theorem_mark_unique`: марка уникальна

### 16. Core.Finance.Budget
**Описание**: Бюджетирование. Соответствует C++ классу BudgetCore в v_budget.cpp

**Теоремы**:
- `theorem_budget_total`: Бюджет = Σ статей
- `theorem_within_budget`: Факт ≤ План

### 11. Core.Notifications
**Описание**: Система уведомлений

**Теоремы**:
- `theorem_notification_order`: отправка ≥ планирование
- `theorem_read_after_sent`: прочитано ≥ отправлено

### 12. Core.Security
**Описание**: Права доступа

**Теоремы**:
- `theorem_deny_priority`: запрет имеет приоритет над разрешением
- `hasAccess`: комбинированная проверка

### 13. Core.Device
**Описание**: POS, кассы, торговое оборудование

**Теоремы**:
- `theorem_receipt_total`: чек = Σ товаров - скидки
- `theorem_change_nonnegative`: сдача ≥ 0
- `theorem_vat_sum`: НДС = Σ НДС строк

### 14. Core.Location
**Описание**: Склады, местоположения, адреса

**Теоремы**:
- `theorem_no_cycles`: нет циклов в иерархии
- `isInside`: проверка вложенности

---

## База данных (PostgreSQL)

### Основные таблицы

- `account` - план счетов
- `accounting_entry` - бухгалтерские проводки
- `bill`, `bill_line` - документы
- `goods` - товары
- `warehouse` - склады
- `party` - контрагенты
- `salary` - зарплатные записи
- `stock_lot` - партии товаров
- `production_order` - производственные заказы
- `bill_of_materials` - спецификации
- `notification` - уведомления
- `access_control_list` - права доступа
- `receipt`, `receipt_item` - чеки

### Хранимые процедуры

- `calc_vat()` - расчёт НДС
- `calc_salary()` - расчёт зарплаты
- `get_stock()` - получить остаток
- `consume_fifo()`, `consume_lifo()` - списание
- `create_entry()` - создать проводку
- `get_trial_balance()` - оборотно-сальдовая ведомость
- `create_bill()`, `post_bill()` - документы
- `calc_ndfl()` - расчёт НДФЛ
- `calc_usn_income()` - расчёт УСН
- `check_gtin13()`, `check_sscc18()` - проверка штрих-кодов
- `has_access()` - проверка прав доступа
- `calc_change()` - рассчитать сдачу

---

## Параметризованные модули (TypeClasses)

```haskell
-- Бухгалтерия
class AccountingScheme as where
  createEntry :: as -> Int -> Day -> Int -> Decimal -> [AccountingEntry]
  calculateBalance :: as -> Int -> Day -> Day -> (Decimal, Decimal)
  validateChartOfAccounts :: as -> [Account] -> Bool
  calcTrialBalance :: as -> Day -> Day -> [AccountBalance]

-- Налоги
class TaxScheme ts where
  calculateTax :: Decimal -> ts -> TaxGroup -> Decimal
  defaultVatRate :: ts -> VatRate
  isAgentVatFree :: ts -> Int -> Bool

-- Зарплата
class SalaryScheme ss where
  calculateNetSalary :: ss -> Decimal -> [SalaryRec] -> Decimal
  applyDeductions :: ss -> Decimal -> [SalaryRec] -> Decimal
  calculateTax :: ss -> Decimal -> Decimal

-- Склад
class InventoryScheme is where
  calculateStock :: is -> Int -> Int -> Day -> Decimal
  consumeGoods :: is -> Int -> Int -> Decimal -> CostMethod -> (Decimal, [StockLot])
  receiveGoods :: is -> Int -> Int -> Decimal -> Decimal -> Decimal -> [StockLot]

-- Документы
class BillScheme bs where
  createBill :: bs -> Int -> Day -> Int -> [BillLine] -> Either String Bill
  postBill :: bs -> Bill -> Either String [Int]
  cancelBill :: bs -> Bill -> Either String Bill

-- Контрагенты
class PartyScheme ps where
  validatePartyScheme :: ps -> Party -> Either String Party
  checkInn :: ps -> String -> Bool
  searchByInn :: ps -> String -> IO (Maybe Party)
```

---

## Соответствие C++ → Haskell

| C++ класс | Haskell модуль |
|--------------------------|-----------------|
| SalaryCore | Core.HR.Salary |
| PersonCore | Core.Party.Party |
| BillCore, PPBill | Core.Document.Bill |
| GoodsCore, InventoryCore | Core.Inventory.Stock |
| Acct, AccTurn, AccountCore | Core.Accounting.Ledger |
| TaxCore | Core.Tax.VAT, Core.Tax.Russian |
| GtinStruc | Core.EDI.Gtin |
| MrpCore | Core.Production.MRP |
| PPView* | Core.Analytics.Reporting |
| NotificationCore | Core.Notifications |
| PPObjRights | Core.Security |
| CSess, DeviceTerminal | Core.Device |
| LocationCore | Core.Location |

---

## Запуск и сборка

```bash
# Установка зависимостей
stack setup

# Сборка
stack build

# Запуск тестов
stack test

# Запуск приложения
stack exec surypus
```

---

## Математические инварианты

1. **Бухгалтерия**: Σ активов = Σ пассивов
2. **Склад**: Σ приходов - Σ расходов = остаток
3. **Зарплата**: Net = Gross - Tax - Deductions
4. **Документы**: Total = Σ строк
5. **Налоги**: Σ налогов ≤ доход
