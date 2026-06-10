# Развёртывание и CI/CD

> Раздел описывает сборку проекта, Docker-инфраструктуру, CI/CD-пайплайн и мониторинг.

---

## 1. Сборка проекта

### Локальная сборка (Stack)

```bash
── Сборка
stack build

── Сборка с форсированной пересборкой
stack build --force-dirty

── Сборка в production (оптимизировано)
stack build --copy-bins
```

**prod-опции (stack.yaml):**

```yaml
ghc-options:
  "$locals":
    - -O2 -funbox-strict-fields -fworker-wrapper
    - -fexpose-all-unfoldings -fspecialise-aggressively
    - -flate-specialise -fmax-simplifier-iterations=20
```

### Cabal

```bash
── Альтернативная сборка через cabal
cabal build
cabal test
cabal run surypus-server
```

### Makefile

```bash
make build      ── stack build
make test       ── stack test
make run        ── stack run
make clean      ── stack clean
make migrate    ── apply DB migrations
make docker     ── docker compose build
```

### Быстрая проверка

```bash
stack build && stack test
── Ожидается: 76+ тестов, все green
```

---

## 2. Docker

### Мультистейджинг билд (Dockerfile)

```dockerfile
── Stage 1: Builder (haskell:9.6)
──   - Устанавливает libpq-dev, libssl-dev, libpcre2-dev
──   - stack build --copy-bins
──
── Stage 2: Production (debian:bookworm-slim)
──   - Копирует бинарник surypus-server
──   - Устанавливает libpq5, ca-certificates, dumb-init
──   - EXPOSE 443
──   - HEALTHCHECK /api/v1/health
──   - ENTRYPOINT: dumb-init -- surypus-server
```

### Docker Compose

```yaml
services:
  db:
    image: postgres:16-alpine
    volumes: [pgdata:/var/lib/postgresql/data]
    healthcheck: [pg_isready -U surypus]

  redis:
    image: redis:7-alpine
    healthcheck: [redis-cli ping]

  api:
    build: .
    ports: ["8080:443"]
    depends_on: [db, redis]
    environment:
      DATABASE_URL: postgres://surypus:password@db:5432/surypus
      REDIS_URL: redis://redis:6379
      JWT_SECRET: "${JWT_SECRET}"
    healthcheck: [curl -f http://localhost:443/api/v1/health]

  worker:
    build: .
    command: surypus-worker
    depends_on: [db, redis]
    restart: unless-stopped
```

### Запуск

```bash
── Полный стек
docker compose up -d

── Только база
docker compose up -d db

── Пересборка API
docker compose build api && docker compose up -d api

── Логи
docker compose logs -f api
```

### Переменные окружения

| Переменная | Описание | Пример |
|-----------|----------|--------|
| `DATABASE_URL` | PostgreSQL connection string | `postgres://user:pass@host:5432/surypus` |
| `REDIS_URL` | Redis connection string | `redis://host:6379` |
| `JWT_SECRET` | Secret key для JWT | `(openssl rand -hex 32)` |
| `PORT` | Порт сервера | `443` |
| `LOG_LEVEL` | Уровень логирования | `INFO` |
| `CORS_ORIGIN` | Разрешённый CORS origin | `*` |

Полный список: `ENV_VARS.md` (корень проекта).

---

## 3. CI/CD

### GitHub Actions (planned)

```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: haskell-actions/setup@v2
        with:
          ghc-version: '9.6.5'
          stack-version: 'latest'

      - name: Build
        run: stack build --no-terminal

      - name: Test
        run: stack test --no-terminal

      - name: HLint
        run: hlint src/

  docker:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: docker build -t surypus:latest .
```

### Локальный CI (через Makefile)

```bash
── Полная проверка перед коммитом
make ci:
  stack build && \
  stack test && \
  hlint src/ && \
  echo "✓ CI passed"
```

### Quality Gates

1. **Build**: `stack build` — без ошибок, без warnings
2. **Tests**: `stack test` — 76+ тестов проходят
3. **Lint**: `hlint src/` — без ошибок
4. **Type check**: GHC —Wall — без предупреждений
5. **Docker**: `docker compose build` — успешная сборка

---

## 4. Мониторинг

### EKG (метрики приложения)

Эндпоинт: `GET /api/v1/metrics`

```json
{
  "requests_total": 12345,
  "requests_active": 5,
  "response_time_avg_ms": 45,
  "db_pool_size": 10,
  "db_connections_active": 3,
  "http_200": 12000,
  "http_401": 200,
  "http_500": 10
}
```

**Категории метрик:**

| Метрика | Описание |
|---------|----------|
| `requests_total` | Всего запросов |
| `requests_active` | Текущие активные запросы |
| `response_time` | Время ответа (avg/p50/p95/p99) |
| `db_pool_*` | Состояние пула соединений |
| `http_*` | Коды ответов |
| `memory_*` | Потребление памяти |
| `gc_*` | Сборка мусора GHC |

### Health Checks

```bash
── Базовая проверка
curl https://host:443/api/v1/health
{"status":"ok","timestamp":"2024-03-15T10:00:00Z"}

── Проверка БД
curl https://host:443/api/v1/health/db
{"status":"ok","db":"connected","poolSize":5,"active":2}
```

### Prometheus + Grafana

```yaml
── docker-compose.yml (prometheus)
scrape_configs:
  - job_name: 'surypus'
    static_configs:
      - targets: ['api:443']
    metrics_path: '/api/v1/metrics'
```

Дашборды Grafana: `config/*.json`

### Логирование

```bash
── Формат логов
[2024-03-15 10:00:00] INFO  [correlation-id: abc-123] POST /api/v1/bills 201 45ms
[2024-03-15 10:00:01] ERROR [correlation-id: abc-124] GET /api/v1/goods 500 "DB connection failed"

── Уровни: DEBUG, INFO, WARN, ERROR
── LOG_LEVEL=INFO по умолчанию
```

### Алерты

| Условие | Действие |
|---------|----------|
| HTTP 5xx > 1% за 5 мин | Уведомление в Slack |
| DB connection pool exhausted | Автоскейлинг / алерт |
| Health check failed 3x подряд | Рестарт контейнера |
| Время ответа > 1s p95 | Оптимизация запроса |

---

## 5. Production-рекомендации

### PostgreSQL

```ini
── postgresql.conf (рекомендации)
max_connections = 50
shared_buffers = 2GB
work_mem = 64MB
effective_cache_size = 6GB
maintenance_work_mem = 512MB
random_page_cost = 1.1
effective_io_concurrency = 200
wal_level = replica
max_wal_size = 4GB
min_wal_size = 1GB
```

### Haskell Runtime

```
── GHC RTS опции
+RTS -N4 -A64M -H1G -M4G -RTS
  -N4        : использовать 4 ядра
  -A64M      : размер шага аллокатора
  -H1G       : начальный размер хипа
  -M4G       : максимум памяти
```

### Security

- JWT secret: `openssl rand -hex 32`
- HTTPS через reverse proxy (nginx/Caddy)
- DB password: минимум 32 символа
- Регулярные backup-ы БД
- Rate limiting: 100 req/s на IP

---

## 6. Резервное копирование

```bash
── Полный бекап БД
pg_dump -h localhost -U surypus --format=custom -f backup.dump surypus

── Восстановление
pg_restore -h localhost -U surypus --dbname=surypus backup.dump

── Автоматизация (cron)
0 2 * * * pg_dump -h localhost -U surypus --format=custom \
  -f /backups/surypus_$(date +\%Y\%m\%d).dump surypus
```

---

## 7. Связанные документы

- `OPERATIONS.md` (корень) — Эксплуатация (базовая)
- `DEVELOPMENT.md` (корень) — Настройка окружения разработчика
- `ENV_VARS.md` (корень) — Все переменные окружения
- `CONTRIBUTING.md` (корень) — Как контрибьютить
- `Dockerfile` (корень) — Docker-сборка
- `docker-compose.yml` (корень) — Локальный запуск
