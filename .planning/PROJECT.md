# Surypus ERP/CRM

**Система управления предприятием нового поколения на Haskell с формальной верификацией**

## Vision

Построить современную ERP/CRM систему на Haskell с:
- Event Sourcing для аудита и надежности
- LiquidHaskell для верификации бизнес-логики
- REST API на Scotty
- QML Desktop UI + Web PWA

## Non-Negotiables

1. Все финансовые расчеты верифицируются LiquidHaskell
2. Event Sourcing для критических изменений
3. RBAC с JWT аутентификацией
4. PostgreSQL 16+ с Hasql/Rel8 ORM
