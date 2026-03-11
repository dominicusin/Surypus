# Унификация схем PostgreSQL

## Контекст

При портировании OpenPapyrus в Surypus мы сохраняем множество SQL-скриптов, отражающих разные домены: accounting, finance, documents, legal, common и т.д. Некоторые объекты в старых скриптах переотражаются (например, `AccSheet` используется и в `Core.Accounting`, и в `Core.Finance`, а `Register`/`RegisterType` — и в `PPObjRegister`, и в `Core.Document`). Без разграничения название `schema_acc_sheet.sql` могло содержать несколько схем, что затрудняло валидацию.

## Что сделано

1. `schema_Core_Accounting_AccSheet.sql` и `schema_Core_Finance_AccSheet.sql` теперь содержат разные таблицы (`acc_sheet_accounting` vs `acc_sheet_finance`), что позволяет освободить пространство имён и не пересекаться по индексам или триггерам.
2. В `schema_Core_Document_Register.sql` и `schema_PPObjRegister_Register.sql` одинаковая view `v_active_registers` конфликтовала, когда оба скрипта выполнялись последовательно. Мы переименовали их в `v_core_document_active_registers` и `v_ppobj_active_registers`, чтобы:
   - избежать перезаписи одной и той же view при инициализации;
   - дать возможность обращаться к каждой view отдельно (в отчётах или job-сервере);
   - позволить под конкретный трудовой регистр (Core.Document vs PPObjRegister) добавлять свои индикаторы деятельности.
3. В `docs/engineering/person-module.md` отражён план дальнейшей выверки схем, включая приведение новых таблиц к принципам уникальности (отдельные таблицы/представления для регистраций, контактных сведений и т.д.).

## Следующие шаги

- Проверить остальные `schema_*` на пересечения имён объектов (`CREATE VIEW`, `CREATE FUNCTION`, `INSERT INTO` с фиксированными `id`) и задокументировать границы доменов.
- Добавить миграцию, которая явно именует таблицы/представления при пересечении (например, `document_register_type` vs `legal_register_type`) и контролирует порядок выполнения скриптов.
- `scripts/check_schema_uniqueness.sh` готов, его следует запускать перед `stack test` и включить в CI, чтобы автоматически выявлять перекрытия объектов.
