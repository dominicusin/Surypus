# Surypus ERP/CRM

**Система управления предприятием нового поколения на Haskell с формальной верификацией**

## Технологический стек

- **Backend**: Haskell (GHC 9.8.4, Stack)
- **База данных**: PostgreSQL 16+
- **ORM/DAL**: Hasql, Rel8, Opaleye, Profunctors
- **API**: REST (Scotty), OpenAPI 3.0
- **UI**: QML Desktop + Web (PWA)
- **Отчёты**: PDF-Slave, JasperReports
- **Верификация**: LiquidHaskell (в процессе внедрения)

## Документация

- [ARCHITECTURE.md](ARCHITECTURE.md) — Архитектура системы и схема данных
- [DEVELOPMENT.md](DEVELOPMENT.md) — Руководство по разработке, сборке и тестированию
- [OPERATIONS.md](OPERATIONS.md) — Docker, миграции, CI/CD и обслуживание
- [PLANNING.md](PLANNING.md) — Roadmap, требования и текущий статус проекта
- [CHANGELOG.md](CHANGELOG.md) — История изменений
- [CONTRIBUTING.md](CONTRIBUTING.md) — Правила участия в разработке

## Быстрый старт

### Сборка и запуск

```bash
# Сборка проекта
stack build

# Запуск базы данных (через docker-compose)
docker-compose up -d db

# Инициализация БД и миграции
./sql/migrations/init_db.sh

# Запуск API сервера (порт 8080)
stack exec surypus
```

### Тестирование

```bash
stack test
```

## Структура проекта

```
Surypus/
├── src/                # Исходный код Haskell
│   ├── Core/           # Бизнес-логика (Tax, Accounting, Inventory)
│   ├── DAL/            # Слой доступа к данным (Repository, EventStore)
│   ├── Domain/         # Доменные модели и типы
│   └── APIServer.hs    # REST API Handlers
├── sql/                # SQL ресурсы
│   ├── migrations/     # Миграции базы данных
│   └── docs/           # Техническая документация БД
├── qml/                # QML Desktop UI
├── web/                # Web UI (Desktop & Mobile)
├── templates/          # Шаблоны отчетов и документов
└── test/               # Набор тестов (Hspec, QuickCheck)
```

## Лицензия

GPL-3
