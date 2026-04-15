# SURYPUS MVP — Phase 2 & Phase 3: Acceptance by BDD (Gherkin)

Feature: Accounts CRUD and auditing (Phase 2)

  Scenario: Admin can login and access accounts
    Given an admin user exists
    When the admin logs in with valid credentials
    Then a valid JWT is returned with appropriate permissions

  Scenario: Create an account (ACID)
    Given an authenticated admin user
    When they POST /api/v1/accounts with {code, name, type, currency, description, is_active}
    Then the system responds with 201 Created and the account is persisted
    And the account must be unique by code

  Scenario: Read accounts
    Given an authenticated user with read permissions
    When they GET /api/v1/accounts
    Then the response is 200 and contains the created accounts

  Scenario: Create a journal entry and update balance (read-model)
    Given an existing account
    When they POST /api/v1/journal_entries with {account_id, debit, credit, amount, currency, date, description, posted}
    Then the response is 201 Created
    And the account balance read-model must reflect the change within 5–10s

  Scenario: RBAC - forbidden action
    Given a user without accounts:write permission
    When they attempt to POST /api/v1/accounts
    Then the response is 403 Forbidden

  Scenario: Health and readiness
    When requesting /health and /readiness
    Then responses are 200 with expected structure

  Scenario: Phase 3 - Accounts ES
    Given Phase 3 is active
    When an account is updated and the event is appended
    Then you can replay events to reconstruct the balance

  Scenario: Phase 3 - Read-model updates
    Given a journal entry is inserted for an account
    When the entry is persisted
    Then the account_balances read-model is updated accordingly (within a few seconds)
