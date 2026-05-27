# Requirements: Surypus ERP/CRM

**Defined:** 2026-05-27
**Milestone:** v55.0 — Deep Refactoring & Tooling
**Core Value:** Современная ERP/CRM система на Haskell с формальной верификацией

## v55.0 Requirements

### Toolchain Installation

- [ ] **TOOL-01**: Установить ghcid (горячая перезагрузка)
- [ ] **TOOL-02**: Установить fourmolu (форматирование)
- [ ] **TOOL-03**: Установить cabal-fmt (форматирование .cabal)
- [ ] **TOOL-04**: Установить weeder (мёртвый код)
- [ ] **TOOL-05**: Установить stan (статический анализ)
- [ ] **TOOL-06**: Установить cabal-audit (уязвимости)
- [ ] **TOOL-07**: `cabal install` команда отрабатывает без ошибок

### Formatting & Linting

- [ ] **LINT-01**: Настроить fourmulo для всего проекта
- [ ] **LINT-02**: Настроить hlint с проектом правил
- [ ] **LINT-03**: Настроить stan для статического анализа
- [ ] **LINT-04**: Внедрить cabal-fmt для .cabal файлов
- [ ] **LINT-05**: Все файлы проходят fourmolu --check
- [ ] **LINT-06**: `stack build` проходит после форматирования

### ORM Migration: persistent + esqueleto

- [ ] **ORM-01**: Добавить persistent, persistent-postgresql, esqueleto в зависимости
- [ ] **ORM-02**: Определить схемы таблиц через Template Haskell (persistLowerCase)
- [ ] **ORM-03**: Создать общий модуль миграций
- [ ] **ORM-04**: Мигрировать DAL/Queries.hs — SELECT запросы
- [ ] **ORM-05**: Мигрировать DAL/Mutations.hs — INSERT/UPDATE/DELETE
- [ ] **ORM-06**: Мигрировать DAL/Classifiers.hs — запросы классификаторов
- [ ] **ORM-07**: Переписать API слой на esqueleto запросы
- [ ] **ORM-08**: Оставить Hasql pool для обратной совместимости (если нужно)
- [ ] **ORM-09**: `stack build` проходит после миграции

### Dead Code Cleanup

- [ ] **DEAD-01**: Запустить weeder для поиска мёртвого кода
- [ ] **DEAD-02**: Удалить неиспользуемые модули и функции
- [ ] **DEAD-03**: Удалить неиспользуемые зависимости из .cabal

### Architecture & Haskell Style

- [ ] **ARCH-01**: Выделить чистые функции из IO-обвязки
- [ ] **ARCH-02**: Исправить монадные цепочки (ReaderT вместо raw IO)
- [ ] **ARCH-03**: Устранить циклические зависимости между модулями
- [ ] **ARCH-04**: Разделить API-слой на handler + service + DAL

### Tests

- [ ] **TEST-01**: Добавить doctest к модулям DAL
- [ ] **TEST-02**: Добавить property-based тесты для бизнес-логики
- [ ] **TEST-03**: `stack test` проходит

### Type Safety

- [ ] **TYPE-01**: Внедрить Phantom Types для идентификаторов (UserId, ContactId)
- [ ] **TYPE-02**: Использовать GADTs для типизированных запросов
- [ ] **TYPE-03**: Подготовить LiquidHaskell аннотации для финансовых расчётов

### Code Organization

- [ ] **ORG-01**: Применить cabal-fmt к .cabal файлам
- [ ] **ORG-02**: Проверить структуру пакетов (surypus-api vs surypus-worker)
- [ ] **ORG-03**: Упорядочить imports (экспорты из внутренних модулей)

## Non-goals (Out of Scope for v55.0)

- Event Sourcing implementation
- New API endpoints (pure refactoring)
- GUI / QML changes
- Deployment / CI changes
