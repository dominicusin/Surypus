Surypus — стратегический roadmap для OpenCode
Анализ архитектуры, пробелов реализации и приоритетных задач

8
критических
11
высоких
9
средних
5
низких
Стабилизация ядра API (Phase 3)
8 задач
Подключить реальные DB-запросы в API handlers
Блокирует любую production-readiness
критическая
›
Завершить интеграцию stored procedures с Haskell DAL
INTEGRATION_SUMMARY.md описывает частичную интеграцию
критическая
›
Стабилизация и упорядочивание миграций БД
Конфликты в порядке миграций V001-V012
критическая
›
Завершить RBAC middleware для всех endpoints
requirePermission не подключён к большинству routes
критическая
›
Исправить refresh token rotation
rotateRefreshTokenBestEffort может пропустить ошибки
критическая
›
Реализовать полноценный сервисный слой (Service.*)
Service модули существуют как заглушки
высокий
›
Завершить WebSocket реальные уведомления
WebSocket принимает подключения но не рассылает события
высокий
›
Реализовать Job Worker и background processing
surypus-job-worker — заглушка в JobWorker.hs
высокий
›
Качество и надёжность тестирования
3 задач
Интеграционные тесты API endpoints против реальной PostgreSQL
test/API/ServerSpec.hs — большинство тестов mockery
критическая
›
QuickCheck property tests для всех domain invariants
Есть примеры в Test.hs, но охват неполный
высокий
›
Repair failing test infrastructure и добавить CI gates
SURYPUS_SKIP_RBAC_TESTS legacy flag нужно убрать
высокий
›
Бизнес-логика и Domain completeness
5 задач
Реализовать полный Bill posting flow
Центральный бизнес-процесс не реализован end-to-end
критическая
›
Завершить модуль Payroll: SalaryCharge, периоды, расчёты
docs/engineering/hr-payroll-module.md описывает план
высокий
›
Реализовать инвентаризацию (Inventory document lifecycle)
GET /inventory — заглушка без реального функционала
высокий
›
Реализовать модуль Production: TechCard, WorkOrder, MRP
docs/engineering/production-module.md — детальный план
средний
›
Multi-currency support: конвертация, курсы, расчёты
Таблица currency существует, но конвертация не реализована
средний
›
Database и производительность
3 задач
Connection pooling, health checks, circuit breaker
System.CircuitBreakerFullWithMetrics объявлен но не подключён
высокий
›
Индексы и оптимизация запросов
Пагинированные запросы без explain analyze
средний
›
Event Store foundation для CQRS
docs/REFACTORING_SUMMARY.md описывает архитектуру
средний
›
Frontend и UI
3 задач
Web UI: подключить к реальному API
web/index.html — полностью статичный mockup
высокий
›
GraphQL proxy: завершить schema и resolvers
surypus-graphql/src/index.js — базовая схема без mutations coverage
средний
›
QML: подключить к API и сделать рабочим
qml/Main.qml — полный UI но без реального функционала
низкий
›
DevOps, Observability и Documentation
5 задач
Prometheus metrics: реальные метрики вместо заглушек
GET /metrics возвращает MetricsResponse 0 0 0
средний
›
Structured logging с correlation IDs
debugLog выводит в stdout без структуры
средний
›
Docker multi-stage build оптимизация
Dockerfile компилирует PostgreSQL из источников — очень медленно
средний
›
Обновить README и API docs под текущее состояние
README описывает API routes которые не работают
низкий
›
Seed data и demo environment
sql/seeds/basic_seed.sql — минимальные данные
низкий
›
