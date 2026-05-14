# Operations Guide: Surypus ERP/CRM

## Docker

Для локальной разработки и развертывания используются Docker и Docker Compose.

```bash
# Запуск всей инфраструктуры (DB, API, Worker)
docker-compose up -d

# Просмотр логов
docker-compose logs -f api
```

### Сервисы
- `db`: PostgreSQL 16 (порт 5432)
- `api`: Haskell REST Server (порт 8080)
- `worker`: Фоновый обработчик задач (отчеты, экспорт)

## Миграции базы данных

Система использует кастомный механизм миграций.

**Путь к файлам**: `sql/migrations/`

```bash
# Инициализация и запуск всех миграций
./sql/migrations/init_db.sh
```

### Порядок добавления новой миграции
1. Создайте файл `sql/migrations/V<XXX>__<description>.sql`.
2. Убедитесь, что версия `<XXX>` идет строго после последней существующей.
3. Добавьте SQL команды (CREATE, ALTER и т.д.).
4. Запустите `init_db.sh` для применения.

## Фоновые задачи (Jobs)

Задачи хранятся в таблице `jobs` и обрабатываются сервисом `worker`.

### Типы задач
- `report_generate`: Генерация PDF.
- `data_export`: Экспорт в CSV/Excel.
- `notification_send`: Отправка email.

## Наблюдаемость (Observability)

- **Метрики**: Prometheus эндпоинт `/metrics` (в процессе).
- **Логирование**: Настроено через stdout/stderr, рекомендуется собирать через Vector/Loki.
- **Аудит**: Все чувствительные операции записываются в `audit_log`.

## CI/CD

Проект использует **GitHub Actions** (`.github/workflows/`):
- `ci.yml`: Сборка и прохождение всех тестов при каждом Push/PR.
- `opencode.yml`: Проверки стиля и линтинг.

---
*Последнее обновление: 2026-05-14*
