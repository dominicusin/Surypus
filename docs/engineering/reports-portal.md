# Отчёты: Jasper / Pentaho / Helical

OpenPapyrus использовал Crystal Reports и встроенный генератор отчётов `report_engine` (например `PPReport`, `CrystalReport`). Surypus перепроектирует отчётную подсистему в несколько компонентов:

1. **Математические шаблоны** — каждую Crystal-форму (`report/*.rpt`) мы описали как `ReportDef` (см. `Surypus/src/Surypus/Reports.hs` и `Surypus/src/Reports.hs`). Сегодня доступны шаблоны:
   * `sales_daily.jrxml` — ежедневные продажи (Jasper)
   * `inventory.jrxml` — остатки по складам (Pentaho)
   * `balance_sheet.jrxml` — финансы (Helical)

2. **SQL-поддержка** — `sql/procedures.sql` содержит `calc_bill_totals`, `calc_stock_balance`, `calc_vat`, и другие подпрограммы, ранее реализованные на C++ в `objbill.cpp`, `objstor.cpp`. Эти процедуры являются входом для Jasper/Pentaho и могут вызываться напрямую из JobServer.
3. **REST-доступ** — `APIServer.reportRoutes` отдаёт метаданные отчётов (`/reports`, `/reports/:name`), а QML UI (`reportPage`) позволяет пользователю просматривать описания и SQL-фрагменты до запуска.
4. **Интеграция Jasper/Pentaho/Helical**:
   * **Jasper** (`*.jrxml`) содержит параметры (даты, фильтры, контрагенты) и может генерировать PDF/HTML через `jasperreports` CLI.
   * **Pentaho** использовать `Pentaho Data Integration` для ETL-потоков, преобразовывающих данные из PostgreSQL в CSV/OLAP.
   * **Helical** задействует регенерацию OLAP-кубов на основе `job`/`report` данных, сохраняя исторические снимки.
5. **JobServer ↔ Reports** — каждая задача может ссылаться на `report_template_id` в `job_data`, что позволяет автоматизировать генерацию отчётов по расписанию (см. `Domain.Job` и `DB.JobQueue.enqueueJob`).
6. **Мониторинг** — отчёты регистрируются в `service_events`, `job`-статусах и выводятся на QML-дэшборде (ниже) через `reportModel`.

7. **Scheduled Rendering** — новая таблица `report_schedule` и endpoints `/reports/schedules` позволяют создать cron-расписание для любого `ReportDef`. Каждый запуск создаёт задачу `report_render` с payload `{ scheduleId }`, которую обрабатывает worker `surypus-job-worker`. Результат сохраняется в `report_render_snapshot` и доступен по `GET /reports/schedules/:id/snapshots`, поэтому Jasper/Pentaho/Helical могут подхватывать исторические JRXML.  

Следующие улучшения:

* Поддержка `Pentaho / Helical` через `REST`-обёртки (см. `Surypus/web/`).
* Автоматическая публикация PDF на `reports.surypus.local`.
* Версионирование шаблонов в `reports/` (Git + Jenkins).
