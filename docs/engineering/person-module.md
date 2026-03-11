# Модуль «Персоны» (Person)

## 1. Цель и мотивация

Модуль Surypus.Person должен эмулировать и расширять функциональность `PPObjPerson` из OpenPapyrus (файлы `Src/PPLib/person.cpp`, `Src/PPLib/v_person.cpp`, `Src/PPLib/objreg.cpp`). `PPObjPerson` ведёт учёт контрагентов, привязаны к регистрам (ИНН/КПП/ОГРН), банковским реквизитам, контактам и разделам CRM/HR. Он заботится о:

- целостности ИНН и КПП;
- синонимичности записей с записями из разных объектов (`PPObjPersonRelType`, `JobQueue`, `PPObjRegister`);
- строгом учёте связей, адресов, контактов;
- начислении скидок и кредитных лимитов (используются в `PPObjBill::SearchCustomer`, `PPObjPerson::GetClientActivityStatistics`).


## 2. Стек Surypus и текущие артефакты

- **LiquidHaskell**: `Domain.Person` уже несёт инварианты `personCredit >= 0` и `0 <= personDiscount <= 100`. Это ядро можно расширить, добавив `validateINN`/`validateKPP` с доказательствами.
- **PostgreSQL**: `config/database_schema.sql` создаёт `persons.person` и наследуемые таблицы `employee/manager`. Дополнительные скрипты (`config/schema_person.sql`, `config/schema_person_kind.sql` и др.) расширяют адреса, контакты.
- **Hasql**: `DB.Person` и `Domain.Person` служат API-слоем, но пока обрывываются между схемой и API (например, в схеме `person` нет колонок `address`, `credit_limit`, `discount`, которые используются в запросах).
- **REST**: `APIServer.personsRoutes` уже реализует CRUD и фильтры по `name/inn/kind/status`.
- **QML/Reports/Job**: пока нет экранов/отчётов, но мы планируем QML-модуль «Контрагенты», ETL-инструменты и регулярные подкачки (`JobQueue`) для синхронизации с CRM-сервисами.


## 3. Необходимые инварианты и проверки

1. `INN` и `KPP` — только цифры, длина 10 или 12 (см. `PPObjPerson::CheckINN()`, `PPObjPerson::CheckKPP()` в `person.cpp`).
2. Кредитный лимит и скидка — неотрицательные (`PPObjPerson::SetCreditLimit`), скидка не может превышать 100%.
3. Каждая персона должна иметь хотя бы трёхзначный код/символьный идентификатор в `person.code`.
4. Связи `PersonRel` не должны создавать циклов (аналог `PPObjPersonRelType::CheckCycle`).
5. Локализация адресов должна совпадать с репозиториями `PersonLocation` и `PersonContact`.

Инварианты накладываются в LiquidHaskell на `Person` (`Domain.Person`) и `PersonRel` друг с другом. Пространство типов должно отражать эти ограничения и фиксировать их на этапе компиляции.


## 4. План реализации

1. **Схема PostgreSQL**: удостовериться, что `persons.person` имеет столбцы `code`, `address`, `phone`, `email`, `credit_limit`, `discount`. Добавить `ALTER TABLE` в `config/schema_person.sql` или `config/database_schema.sql`, чтобы гарантировать их наличие независимо от порядка исполнения.
2. **Hasql/DB**: согласовать декодеры с точным списком полей; добавить `INSERT`/`UPDATE` с контролем `code` и `search_path`.
3. **Core/Domain**: расширить LiquidHaskell-инварианты (`validateINN`, `validateKPP`), описать `PersonRel` и `PersonLocation` как типы с доказательствами (например, `PersonLocation` не может быть одновременно `isPrimary` и `isDefault` для двух записей).
4. **API**: усилить middleware с JWT/логгированием и расширить CRUD на `PersonContact`, `PersonBankAccount`, `PersonLocation`.
5. **UI/Reports/Jobs**: представить `qml/persons/` с формами, отчёты `Jasper`/`Pentaho` и расширенный `JobQueue` для синхронизации контрагентов.
6. **Тесты**: свойство `prop_person_credit_nonneg`, таблицы с `QuickCheck` `PersonRel` (без циклов), интеграционный тест `APIServer.personsRoutes`.

## 5. Текущие действия

1. Выделить модуль Person как первый в контуре реинжиниринга;
2. Привести наименования schema (уникальные `schema_Core_Document_Register`, `schema_PPObjRegister_Register`) и задокументировать их;
3. Проверить alignment схемы `persons.person` с `DB.Person`, включая `code`/`credit_limit`.
4. Создать агрегированные отчёты/хранимые процедуры (например, `get_person_summary()`), чтобы job-сервер мог эвакуировать KPI по контрагентам и передавать их в Jasper/Pentaho/Helical.
5. Сделать snapshot job (`run_person_summary_snapshot`), который периодически срабатывает в job-очереди и переносит KPI в `person_summary_snapshot`, позволяя QML/UI строить графики трендов и наполнять отчёты Jasper/Pentaho/Helical.

## 6. Источники

- OpenPapyrus: `Src/PPLib/person.cpp`, `Src/PPLib/v_person.cpp`, `Src/PPLib/objreg.cpp`.
- Surypus: `Domain.Person`, `DB.Person`, `APIServer.personsRoutes`, config-схемы.
