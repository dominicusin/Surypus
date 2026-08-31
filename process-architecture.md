# Surypus Process Architecture — BMAD / SpecKit / GSD / Beads Stack

> Этот документ отвечает на вопрос: **как Surypus должен управлять своей разработкой**,
> учитывая, что в репозитории уже живёт Beads-граф, GSD-пакет и есть STRATEGY.md/ARCHITECTURE.md/PLANNING.md.

> **Модель (согласно переговору 2026-08-29):** BMAD → SpecKit → Beads → GSD → Git/CI,
> где каждый слой отвечает за свою фазу, а не дублирует задачи.

---

## 1. Что уже работает в Surypus процессно

### 1.1 Beads — единственный task graph (state layer)

- **62 issue** в `.beads/issues.jsonl` (Dolt-бэкенд, `config.yaml: database=dolt`).
- Все issue'ы имеют статус `closed` (62/62, из них 39 bug, 14 feature, 9 task, 4 chore, 4 team).
- Последние состояния синхронизированы: `176d5d52 chore: Update beads state after Redis cache work`.
- Это **единственный источник истины о состоянии задач** — GitHub Issues, TODO.md и ручные списки **не дублируются**.

Это уже правильная архитектура: один граф состояний, чтобы не было 5 независимых списков задач.

### 1.2 GSD — execution device (пакет + шаблоны)

- `.agent/get-shit-done/` — полный GSD-пакет (VERSION, gsd-tools.cjs, bin/lib/*).
- Шаблоны: `spec-phase.md`, `retrospective.md`, `state.md` — присутствуют в каждом агент-профиле.
- Нет активного `.gsd/plan.md` — фазы не запущены (или закончены и не созданы новые).

Это значит: GSD как execution engine готов, но не используется как активная фаза.

### 1.3 STRATEGY.md / ARCHITECTURE.md / PLANNING.md — существующий «why/what» слой

Эти три документа выполняют роль **BMAD-продукта/архитектуры**, но не имеют явного формата BMAD-чартера (`.planning/CHARTER.md`, `.planning/initiatives/*.md`).

- **STRATEGY.md** (19.5K): стратегический анализ, тезисы, цели, текущее состояние, технический долг.
- **ARCHITECTURE.md** (17.4K): слои системы, схема данных, event sourcing, безопасность, отчёты.
- **PLANNING.md** (4.8K): цели проекта, текущий статус, дорожная карта, требования.

Это уже хорошо — есть продукт/архитектурное обоснование, но оно **размазано по корню**, а не в `.planning/` как явный BMAD-слой.

### 1.4 Research-черновики

`src/.planning/research/` содержит draft-исследования для R&D-цикла:
- `ARCHITECTURE.md` — архитектурные исследования (слои, event sourcing, multi-tenant).
- `FEATURES.md` — черновик фич (GraphQL, Datalog, multi-tenant).
- `PITFALLS.md` — риски реализации.

Это **промежуточный BMAD-research слой**, но не оформлен как явный `initiatives/` или `discovery/`.

---

## 2. Где разрыв слой→слой

| Слой | Состояние | Пробел |
|---|---|---|
| **BMAD (why/what)** | STRATEGY.md + ARCHITECTURE.md + PLANNING.md + research/ | Нет формата `.planning/CHARTER.md`, initiative split, нет product owner voice, исследования не привязаны к задачам |
| **SpecKit (contract)** | Отсутствует — нет `.specify/`, `specs/`, `openspec/changes/` | Нет executable specification для фич; ARCHITECTURE.md — это архитектура, но не контракт интерфейса |
| **Beads (state)** | Живой граф, 62 issue, все closed | Граф существует, но новые задачи не создаются (все closed) — нужно создавать новые issue'ы через beads для новых фич |
| **GSD (execution)** | Пакет готов, шаблоны есть | Нет активной фазы `.gsd/plan.md` — фазы не запущены |
| **Git/CI** | CI есть (`.github/workflows/ci.yml`), коммиты.push | Связь между задачами и коммитами не явная — Beads-issue'ы не привязаны к PR номерам |

**Ключевой разрыв:** SpecKit-контракт отсутствует вообще. Это значит, что «что именно должно быть реализовано» живёт в Beads-issue описаниях и в STRATEGY.md, но не в формализованном spec.md с контрактами интерфейсов.

---

## 3. Рекомендация: как встроить стек без 5 независимых списков задач

### 3.1 Правило: каждому каталогу — чёткая семантика

| Каталог | Семантика | NOT |
|---|---|---|
| `.planning/` | BMAD — product, architecture, discovery artifacts | Не task list |
| `.specify/specs/` | SpecKit — executable spec (contract) для крупной фичи | Не task list, не research |
| `.openspec/changes/` | SpecKit — изменения в спецификациях | Не todos |
| `.beads/` | Beads — граф состояний задач | Не архивация 검토 |
| `.gsd/` | GSD — active phase план + state | Не архивация 검토 |

**Запрет:** SpecKit-таски не дублируются в Beads и GSD-фазах. Если SpecKit создаёт task.md, Beads-issue ссылается на него как на contract, но не дублирует текст.

### 3.2 Маленькая задача → GSD fast

Если задача — однофайловая правка, баг-фикс, мелкое улучшение:

```
GSD fast
  → beads issue (автоматически, если не создан)
  → выполнить
  → beads close
  → git commit + push
```

**Пример:** Fix LoadBalancer.selectByWeight (была в beads как `Surypus-93x`, closed).

### 3.3 Средняя feature → SpecKit spec + GSD execute

Если feature требует явного контракта интерфейса (API endpoint, QML форма, event schema):

```
SpecKit
  → .specify/specs/<feature>/spec.md (контракт)
  → beads issue (ссылается на spec)
  → GSD execute
  → beads close
  → git commit + push
```

**Пример:** Invoice posting flow, RBAC middleware everywhere, refresh-token stability.

### 3.4 Большая feature → SpecKit + Beads graph + GSD

Если feature — композит из нескольких подзадач:

```
SpecKit
  → .specify/specs/<feature>/spec.md
Beads
  → issue + подзадачи (dependency graph)
  → приоритизация
GSD
  → .gsd/plan.md (фаза)
  → execute
  → verify (tests, CI)
  → beads close
  → git commit + push
```

**Пример:** PayrollService event-sourced, InventoryService with reservations.

### 3.5 Архитектурная задача → BMAD-designed (и/или SpecKit)

Если изменение затрагивает архитектуру (DSL transpiler, circuit breaker contour, observability):

```
BMAD (optional, для сложных изменений)
  → .planning/initiatives/<change>/ (discovery, архитектура)
SpecKit
  → .specify/specs/<change>/spec.md (контракт)
Beads
  → issue + подзадачи
GSD
  → execute
  → verify
  → beads close
  → git commit + push
```

**Пример:** DSL transpiler migration, circuit breaker contour integration.

---

## 4. Поведение новых агентов: продолжать граф, не писать план «с нуля»

Когда новый агент получает задачу:

1. **Проверить Beads-граф** — задача уже есть как issue? Если нет — создать issue через beads.
2. **Если задача архитектурная** — проверить `.planning/` и STRATEGY.md для технического обоснования. Если его нет — создать discovery artifact в `.planning/initiatives/`.
3. **Если задача средняя/большая** — создать SpecKit spec в `.specify/specs/<feature>/spec.md`, если контракта ещё нет.
4. **Если задача выполнимая** — запустить GSD-фазу (`.gsd/plan.md`) или выполнить как GSD-fast.
5. **После выполнения** — beads close, git commit + push, update Beads-граф.

Новый агент **не должен** писать план «с нуля» — он должен продолжить существующий граф.

---

## 5. Конкретные шаги для Surypus

### 5.1 Формализовать BMAD-слой

- [ ] Переименовать/переместить STRATEGY.md + ARCHITECTURE.md + PLANNING.md в `.planning/` как `.planning/strategy.md`, `.planning/architecture.md`, `.planning/planning.md`.
- [ ] Создать `.planning/CHARTER.md` — явный product charter: зачем существует Surypus, для кого, какие утверждения.
- [ ] Создать `.planning/initiatives/` для крупных архитектурных изменений (например, `dsl-transpiler/`, `circuit-breaker/`, `observability/`).
- [ ] Связать research-черновики из `src/.planning/research/` с инициативами.

### 5.2 Ввести SpecKit контракты

- [ ] Создать `.specify/` (директория) как корень SpecKit-пространства.
- [ ] Для каждой крупной фичи создать `.specify/specs/<feature>/spec.md` — контракт интерфейса (API, event schema, refinement predicates).
- [ ] Первая спека: `InvoicePostingFlow` — описать контракт: input, validation, event, projection, audit, API endpoints.
- [ ] Вторая спека: `RBACMiddleware` — описать контракт: middleware signature, policy resolution, public routes.
- [ ] Третья спека: `RefreshTokenStability` — описать контракт: rotate flow, token storage, failure modes.

### 5.3 Поддерживать Beads граф

- [ ] Создать новые issue'ы в Beads для каждой новой задачи (не дублировать в GitHub Issues).
- [ ] Привязывать issue к PR номерам (комментарий в issue + в PR).
- [ ] Обновлять state.json/export-state.json после каждой фазы.

### 5.4 Запускать GSD фазы

- [ ] Для каждой крупной фичи создавать `.gsd/plan.md` — фаза с research, plan, execute, verify.
- [ ] Использовать GSD-шаблоны из `.agent/get-shit-done/templates/`.
- [ ] После фазы — retrospective, beads close, git push.

### 5.5 Избежать 5 независимых списков

- [ ] Не создавать задачи в GitHub Issues, TODO.md, ручные списки — только Beads.
- [ ] SpecKit task.md ссылается на beads issue, а не дублирует.
- [ ] GSD phase.md ссылается на beads issue, а не дублирует.
- [ ] Если Beads-issue'ов слишком много — архивировать закрытые, не удалять.

---

## 6. Пример: Invoice posting flow как полный цикл

1. **BMAD discovery** (опционально): `.planning/initiatives/invoice-posting-flow/discovery.md` — почему нужен, что должен делать, риски.
2. **SpecKit spec**: `.specify/specs/invoice-posting-flow/spec.md` — контракт: input validation, event schema, projection contract, audit contract, API endpoints.
3. **Beads issue**: `Surypus-xyz` «Invoice posting flow» — зависимость от RBAC middleware, CircuitBreaker contour, refresh-token stability (если применимо).
4. **GSD phase**: `.gsd/plan.md` — фаза с research (как реализовать), plan (подзадачи), execute, verify.
5. **Execute**:
   - Реализовать validation (refinement predicates).
   - Реализовать event (InvoiceCreated in EventStore).
   - Реализовать projection (accounting entries).
   - Реализовать audit (audit_entry).
   - Реализовать API endpoints.
   - Написать QuickCheck property tests.
6. **Verify**: `stack test`, `surypus-codegen check`, QuickCheck property тесты.
7. **Beads close**: `Surypus-xyz` → closed.
8. **Git commit + push**: коммит с привязкой к issue.
9. **CI**: проходит.

Это полный цикл BMAD → SpecKit → Beads → GSD → Git/CI, без дублирования задач.

---

## 7. Оценка текущей ситуации

### 7.1 Что уже работает хорошо

- Beads как единственный task graph — правильная архитектура.
- STRATEGY.md/ARCHITECTURE.md/PLANNING.md — есть продукт/архитектурное обоснование.
- GSD как execution device — пакет готов, шаблоны есть.
- Нет 5 независимых списков задач — это уже правильно.

### 7.2 Что нужно улучшить

- BMAD-слой не формализован — нет `.planning/CHARTER.md`, initiative split, product owner voice.
- SpecKit контракты отсутствуют — «что именно должно быть реализовано» живёт в Beads-issue описаниях и STRATEGY.md, но не в формализованном spec.md.
- GSD фазы не активны — нет `.gsd/plan.md`.
- Новые задачи не создаются в Beads (все closed) — нужно создавать новые issue'ы для новых фич.

### 7.3 Приоритизированные шаги

| Приоритет | Действие | Effect |
|---|---|---|
| 1 | Создать Beads-issues для новых фич (Invoice posting flow, RBAC middleware, refresh-token stability) | Новых задач нет → нет выполнения |
| 2 | Ввести SpecKit spec для крупных фич (InvoicePostingFlow, RBACMiddleware, RefreshTokenStability) | Контракт интерфейса, не дублирование задач |
| 3 | Формализовать BMAD-слой (CHARTER.md, initiatives/) | Явный why/what layer |
| 4 | Запускать GSD фазы для крупных фич (`.gsd/plan.md`) | Execution layer |
| 5 | Связывать коммиты с Beads-issue'ами | Трассируемость |

---

## 8. Риски

| Риск | Severity | Митigation |
|---|---|---|
| Documentation-driven development — AI тратит время на артефакты, а не код | High | Маленькие задачи — GSD fast без SpecKit, не создавать SpecKit для каждой правки |
| 5 независимых списков задач — Beads, SpecKit tasks, GSD tasks, GitHub Issues, BMAD stories | High | Запрет на дублирование, каждый слой — своя семантика |
| SpecKit specs не поддерживаются — старые specs рассинхронизируются с кодом | Medium | Спеки обновляются при изменении контракта, beads issue привязан к spec, при закрытии — обновление spec |
| BMAD charter избыточен для маленьких проектов | Medium | CHARTER.md — только для крупных проектов, для маленьких — STRATEGY.md достаточно |
| GSD фазы слишком медленные — каждый шаг требует фазы | Medium | Маленькие задачи — GSD fast, средние — SpecKit + GSD, большие — SpecKit + Beads + GSD |

---

## 9. Вывод

Для Surypus оптимальная модель: **BMAD (strategy/architecture/docs) → SpecKit (contracts for features) → Beads (state graph) → GSD (execution phases) → Git/CI**.

Но с **условным включением**:
- Маленькая задача → GSD fast (без SpecKit).
- Средняя feature → SpecKit spec + GSD execute.
- Большая feature → SpecKit spec + Beads graph + GSD phase.
- Архитектурная задача → BMAD discovery + SpecKit spec + Beads + GSD.

Не «четыре методологии одновременно», а **слои с чёткой семантикой**, и каждый новый агент продолжает существующий граф, а не пишет план «с нуля».

Сейчас в Surypus Beads и GSD-пакет работают, но SpecKit контракты отсутствуют, BMAD-слой не формализован, GSD фазы не активны. Это нужно закрыть, но осторожно — не начинать documentation-driven development.

---

*Автор: аудит процессной архитектуры Surypus, 2026-08-29. Основано на инвентаризации .planning/, .beads/, .specify/ (отсутствует), .gsd/ (отсутствует), STRATEGY.md, ARCHITECTURE.md, PLANNING.md, beads/issues.jsonl (62 закрытых issue), gsd-file-manifest.json, .github/workflows/ci.yml.*
