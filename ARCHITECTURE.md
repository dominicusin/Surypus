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
