-- ============================================================================
-- SURYPUS INTERNATIONALIZATION (i18n)
-- ============================================================================
-- Multi-language support: RU, EN, DE, FR, ZH
-- ============================================================================

module Surypus.I18n where

import Data.Map (Map)
import qualified Data.Map as Map
import Data.Text (Text)
import qualified Data.Text as T

-- ============================================================================
-- LANGUAGE TYPES
-- ============================================================================

data Language = RU | EN | DE | FR | ZH
  deriving (Show, Eq, Enum, Bounded, Ord)

langCode :: Language -> Text
langCode RU = T.pack "ru"
langCode EN = T.pack "en"
langCode DE = T.pack "de"
langCode FR = T.pack "fr"
langCode ZH = T.pack "zh"

langName :: Language -> Text
langName RU = T.pack "Русский"
langName EN = T.pack "English"
langName DE = T.pack "Deutsch"
langName FR = T.pack "Français"
langName ZH = T.pack "中文"

-- ============================================================================
-- TRANSLATION KEYS
-- ============================================================================

data Domain
  = DCore
  | DAccounting
  | DWarehouse
  | DBills
  | DPersons
  | DGoods
  | DReports
  | D_API
  | DValidation
  | DUI
  | DSystem
  deriving (Show, Eq, Ord)

newtype TransKey = TransKey (Domain, String)
  deriving (Show, Eq, Ord)

type Translations = Map Language (Map TransKey Text)

allTranslations :: Translations
allTranslations =
  Map.fromList
    [ (RU, ruTranslations),
      (EN, enTranslations),
      (DE, deTranslations),
      (FR, frTranslations),
      (ZH, zhTranslations)
    ]

-- ============================================================================
-- RUSSIAN TRANSLATIONS
-- ============================================================================

ruTranslations :: Map TransKey Text
ruTranslations =
  Map.fromList
    [ (k DCore "id", T.pack "Идентификатор"),
      (k DCore "name", T.pack "Наименование"),
      (k DCore "code", T.pack "Код"),
      (k DCore "status", T.pack "Статус"),
      (k DCore "active", T.pack "Активный"),
      (k DCore "blocked", T.pack "Заблокирован"),
      (k DCore "deleted", T.pack "Удален"),
      (k DCore "draft", T.pack "Черновик"),
      (k DCore "created_at", T.pack "Дата создания"),
      (k DCore "updated_at", T.pack "Дата изменения"),
      (k DCore "notes", T.pack "Комментарий"),
      (k DCore "address", T.pack "Адрес"),
      (k DCore "phone", T.pack "Телефон"),
      (k DCore "email", T.pack "Email"),
      (k DCore "inn", T.pack "ИНН"),
      (k DCore "kpp", T.pack "КПП"),
      (k DPersons "person", T.pack "Контрагент"),
      (k DPersons "company", T.pack "Юридическое лицо"),
      (k DPersons "individual", T.pack "Физическое лицо"),
      (k DPersons "entrepreneur", T.pack "ИП"),
      (k DPersons "credit_limit", T.pack "Кредитный лимит"),
      (k DPersons "discount", T.pack "Скидка"),
      (k DGoods "goods", T.pack "Товар"),
      (k DGoods "product", T.pack "Продукция"),
      (k DGoods "service", T.pack "Услуга"),
      (k DGoods "barcode", T.pack "Штрих-код"),
      (k DGoods "unit", T.pack "Единица измерения"),
      (k DGoods "quantity", T.pack "Количество"),
      (k DGoods "price", T.pack "Цена"),
      (k DGoods "cost", T.pack "Себестоимость"),
      (k DWarehouse "warehouse", T.pack "Склад"),
      (k DWarehouse "location", T.pack "Местоположение"),
      (k DWarehouse "stock", T.pack "Остаток"),
      (k DWarehouse "reserved", T.pack "Резерв"),
      (k DWarehouse "available", T.pack "Доступно"),
      (k DWarehouse "movement", T.pack "Перемещение"),
      (k DWarehouse "receipt", T.pack "Приход"),
      (k DWarehouse "issue", T.pack "Расход"),
      (k DWarehouse "transfer", T.pack "Перемещение"),
      (k DWarehouse "inventory", T.pack "Инвентаризация"),
      (k DBills "bill", T.pack "Документ"),
      (k DBills "sale", T.pack "Продажа"),
      (k DBills "purchase", T.pack "Закупка"),
      (k DBills "pure", T.pack "Возврат"),
      (k DBills "invoice", T.pack "Счет-фактура"),
      (k DBills "order", T.pack "Заказ"),
      (k DBills "total", T.pack "Итого"),
      (k DBills "tax", T.pack "Налог"),
      (k DBills "discount", T.pack "Скидка"),
      (k DBills "date", T.pack "Дата"),
      (k DAccounting "account", T.pack "Счет"),
      (k DAccounting "debit", T.pack "Дебет"),
      (k DAccounting "credit", T.pack "Кредит"),
      (k DAccounting "entry", T.pack "Проводка"),
      (k DAccounting "asset", T.pack "Актив"),
      (k DAccounting "liability", T.pack "Пассив"),
      (k DAccounting "equity", T.pack "Капитал"),
      (k DAccounting "revenue", T.pack "Доходы"),
      (k DAccounting "expense", T.pack "Расходы"),
      (k DAccounting "balance", T.pack "Остаток"),
      (k DAccounting "currency", T.pack "Валюта"),
      (k DAccounting "vat", T.pack "НДС"),
      (k DReports "report", T.pack "Отчет"),
      (k DReports "sales_report", T.pack "Продажи"),
      (k DReports "purchase_report", T.pack "Закупки"),
      (k D_API "not_found", T.pack "Объект не найден"),
      (k D_API "unauthorized", T.pack "Не авторизован"),
      (k D_API "forbidden", T.pack "Доступ запрещен"),
      (k D_API "bad_request", T.pack "Неверный запрос"),
      (k D_API "created", T.pack "Создано"),
      (k D_API "updated", T.pack "Обновлено"),
      (k D_API "deleted", T.pack "Удалено"),
      (k DValidation "required", T.pack "Обязательное поле"),
      (k DValidation "invalid_inn", T.pack "Неверный ИНН"),
      (k DValidation "invalid_email", T.pack "Неверный Email"),
      (k DValidation "insufficient_stock", T.pack "Недостаточно товара"),
      (k DValidation "credit_exceeded", T.pack "Превышен кредитный лимит"),
      (k DUI "save", T.pack "Сохранить"),
      (k DUI "cancel", T.pack "Отмена"),
      (k DUI "delete", T.pack "Удалить"),
      (k DUI "edit", T.pack "Редактировать"),
      (k DUI "create", T.pack "Создать"),
      (k DUI "search", T.pack "Поиск"),
      (k DUI "filter", T.pack "Фильтр"),
      (k DUI "refresh", T.pack "Обновить"),
      (k DUI "export", T.pack "Экспорт"),
      (k DUI "import", T.pack "Импорт"),
      (k DUI "print", T.pack "Печать"),
      (k DUI "close", T.pack "Закрыть"),
      (k DUI "yes", T.pack "Да"),
      (k DUI "no", T.pack "Нет"),
      (k DUI "ok", T.pack "ОК"),
      (k DUI "apply", T.pack "Применить"),
      (k DUI "loading", T.pack "Загрузка..."),
      (k DUI "no_data", T.pack "Нет данных"),
      (k DSystem "success", T.pack "Успешно"),
      (k DSystem "error", T.pack "Ошибка"),
      (k DSystem "warning", T.pack "Предупреждение"),
      (k DSystem "info", T.pack "Информация")
    ]
  where
    k d txt = TransKey (d, txt)

-- ============================================================================
-- ENGLISH TRANSLATIONS
-- ============================================================================

enTranslations :: Map TransKey Text
enTranslations =
  Map.fromList
    [ (k DCore "id", T.pack "ID"),
      (k DCore "name", T.pack "Name"),
      (k DCore "code", T.pack "Code"),
      (k DCore "status", T.pack "Status"),
      (k DCore "active", T.pack "Active"),
      (k DCore "blocked", T.pack "Blocked"),
      (k DCore "deleted", T.pack "Deleted"),
      (k DCore "draft", T.pack "Draft"),
      (k DCore "created_at", T.pack "Created at"),
      (k DCore "updated_at", T.pack "Updated at"),
      (k DCore "notes", T.pack "Notes"),
      (k DCore "address", T.pack "Address"),
      (k DCore "phone", T.pack "Phone"),
      (k DCore "email", T.pack "Email"),
      (k DCore "inn", T.pack "INN"),
      (k DCore "kpp", T.pack "KPP"),
      (k DPersons "person", T.pack "Counteragent"),
      (k DPersons "company", T.pack "Company"),
      (k DPersons "individual", T.pack "Individual"),
      (k DPersons "entrepreneur", T.pack "Entrepreneur"),
      (k DPersons "credit_limit", T.pack "Credit limit"),
      (k DPersons "discount", T.pack "Discount"),
      (k DGoods "goods", T.pack "Goods"),
      (k DGoods "product", T.pack "Product"),
      (k DGoods "service", T.pack "Service"),
      (k DGoods "barcode", T.pack "Barcode"),
      (k DGoods "unit", T.pack "Unit"),
      (k DGoods "quantity", T.pack "Quantity"),
      (k DGoods "price", T.pack "Price"),
      (k DGoods "cost", T.pack "Cost"),
      (k DWarehouse "warehouse", T.pack "Warehouse"),
      (k DWarehouse "location", T.pack "Location"),
      (k DWarehouse "stock", T.pack "Stock"),
      (k DWarehouse "reserved", T.pack "Reserved"),
      (k DWarehouse "available", T.pack "Available"),
      (k DWarehouse "movement", T.pack "Movement"),
      (k DWarehouse "receipt", T.pack "Receipt"),
      (k DWarehouse "issue", T.pack "Issue"),
      (k DWarehouse "transfer", T.pack "Transfer"),
      (k DWarehouse "inventory", T.pack "Inventory"),
      (k DBills "bill", T.pack "Document"),
      (k DBills "sale", T.pack "Sale"),
      (k DBills "purchase", T.pack "Purchase"),
      (k DBills "pure", T.pack "Return"),
      (k DBills "invoice", T.pack "Invoice"),
      (k DBills "order", T.pack "Order"),
      (k DBills "total", T.pack "Total"),
      (k DBills "tax", T.pack "Tax"),
      (k DBills "discount", T.pack "Discount"),
      (k DBills "date", T.pack "Date"),
      (k DAccounting "account", T.pack "Account"),
      (k DAccounting "debit", T.pack "Debit"),
      (k DAccounting "credit", T.pack "Credit"),
      (k DAccounting "entry", T.pack "Entry"),
      (k DAccounting "asset", T.pack "Asset"),
      (k DAccounting "liability", T.pack "Liability"),
      (k DAccounting "equity", T.pack "Equity"),
      (k DAccounting "revenue", T.pack "Revenue"),
      (k DAccounting "expense", T.pack "Expense"),
      (k DAccounting "balance", T.pack "Balance"),
      (k DAccounting "currency", T.pack "Currency"),
      (k DAccounting "vat", T.pack "VAT"),
      (k DReports "report", T.pack "Report"),
      (k DReports "sales_report", T.pack "Sales"),
      (k DReports "purchase_report", T.pack "Purchases"),
      (k D_API "not_found", T.pack "Not found"),
      (k D_API "unauthorized", T.pack "Unauthorized"),
      (k D_API "forbidden", T.pack "Forbidden"),
      (k D_API "bad_request", T.pack "Bad request"),
      (k D_API "created", T.pack "Created"),
      (k D_API "updated", T.pack "Updated"),
      (k D_API "deleted", T.pack "Deleted"),
      (k DValidation "required", T.pack "Required field"),
      (k DValidation "invalid_inn", T.pack "Invalid INN"),
      (k DValidation "invalid_email", T.pack "Invalid email"),
      (k DValidation "insufficient_stock", T.pack "Insufficient stock"),
      (k DValidation "credit_exceeded", T.pack "Credit limit exceeded"),
      (k DUI "save", T.pack "Save"),
      (k DUI "cancel", T.pack "Cancel"),
      (k DUI "delete", T.pack "Delete"),
      (k DUI "edit", T.pack "Edit"),
      (k DUI "create", T.pack "Create"),
      (k DUI "search", T.pack "Search"),
      (k DUI "filter", T.pack "Filter"),
      (k DUI "refresh", T.pack "Refresh"),
      (k DUI "export", T.pack "Export"),
      (k DUI "import", T.pack "Import"),
      (k DUI "print", T.pack "Print"),
      (k DUI "close", T.pack "Close"),
      (k DUI "yes", T.pack "Yes"),
      (k DUI "no", T.pack "No"),
      (k DUI "ok", T.pack "OK"),
      (k DUI "apply", T.pack "Apply"),
      (k DUI "loading", T.pack "Loading..."),
      (k DUI "no_data", T.pack "No data"),
      (k DSystem "success", T.pack "Success"),
      (k DSystem "error", T.pack "Error"),
      (k DSystem "warning", T.pack "Warning"),
      (k DSystem "info", T.pack "Info")
    ]
  where
    k d txt = TransKey (d, txt)

-- ============================================================================
-- GERMAN TRANSLATIONS (Partial)
-- ============================================================================

deTranslations :: Map TransKey Text
deTranslations =
  Map.fromList
    [ (k DCore "id", T.pack "ID"),
      (k DCore "name", T.pack "Name"),
      (k DCore "code", T.pack "Code"),
      (k DCore "status", T.pack "Status"),
      (k DCore "active", T.pack "Aktiv"),
      (k DCore "blocked", T.pack "Gesperrt"),
      (k DUI "save", T.pack "Speichern"),
      (k DUI "cancel", T.pack "Abbrechen"),
      (k DUI "delete", T.pack "Löschen"),
      (k DUI "yes", T.pack "Ja"),
      (k DUI "no", T.pack "Nein"),
      (k DUI "ok", T.pack "OK"),
      (k DSystem "success", T.pack "Erfolg"),
      (k DSystem "error", T.pack "Fehler")
    ]
  where
    k d txt = TransKey (d, txt)

-- ============================================================================
-- FRENCH TRANSLATIONS (Partial)
-- ============================================================================

frTranslations :: Map TransKey Text
frTranslations =
  Map.fromList
    [ (k DCore "id", T.pack "ID"),
      (k DCore "name", T.pack "Nom"),
      (k DCore "code", T.pack "Code"),
      (k DCore "status", T.pack "Statut"),
      (k DCore "active", T.pack "Actif"),
      (k DCore "blocked", T.pack "Bloqué"),
      (k DUI "save", T.pack "Enregistrer"),
      (k DUI "cancel", T.pack "Annuler"),
      (k DUI "delete", T.pack "Supprimer"),
      (k DUI "yes", T.pack "Oui"),
      (k DUI "no", T.pack "Non"),
      (k DUI "ok", T.pack "OK"),
      (k DSystem "success", T.pack "Succès"),
      (k DSystem "error", T.pack "Erreur")
    ]
  where
    k d tx = TransKey (d, tx)

-- ============================================================================
-- CHINESE TRANSLATIONS (Partial)
-- ============================================================================

zhTranslations :: Map TransKey Text
zhTranslations =
  Map.fromList
    [ (k DCore "id", T.pack "Bian Hao"),
      (k DCore "name", T.pack "Ming Cheng"),
      (k DCore "code", T.pack "Dai Ma"),
      (k DCore "status", T.pack "Zhuang Tai"),
      (k DCore "active", T.pack "Huo Yue"),
      (k DCore "blocked", T.pack "Yi Ping Bi"),
      (k DUI "save", T.pack "Bao Cun"),
      (k DUI "cancel", T.pack "Qu Xiao"),
      (k DUI "delete", T.pack "Shan Chu"),
      (k DUI "yes", T.pack "Shi"),
      (k DUI "no", T.pack "Fou"),
      (k DUI "ok", T.pack "Que Ren"),
      (k DSystem "success", T.pack "Cheng Gong"),
      (k DSystem "error", T.pack "Cuo Wu")
    ]
  where
    k d txt = TransKey (d, txt)

-- ============================================================================
-- TRANSLATION FUNCTIONS
-- ============================================================================

translate :: Language -> Domain -> String -> Text
translate lang domain key =
  let transKey = TransKey (domain, key)
   in case Map.lookup lang allTranslations of
        Just langMap -> case Map.lookup transKey langMap of
          Just text -> text
          Nothing -> T.pack key
        Nothing -> T.pack key

t :: Language -> Domain -> String -> Text
t = translate

t' :: Domain -> String -> Text
t' = translate EN

tRu :: Domain -> String -> Text
tRu = translate RU

-- ============================================================================
-- PLURALIZATION
-- ============================================================================

data PluralForms = PluralForms
  { pfOne :: Text,
    pfFew :: Text,
    pfMany :: Text
  }

plural :: Int -> PluralForms -> Text
plural n nforms
  | n == 1 = pfOne nforms
  | n >= 2 && n <= 4 = pfFew nforms
  | otherwise = pfMany nforms

itemsPluralRu :: Int -> Text
itemsPluralRu n =
  plural n $
    PluralForms
      { pfOne = T.pack "элемент",
        pfFew = T.pack "элемента",
        pfMany = T.pack "элементов"
      }

itemsPluralEn :: Int -> Text
itemsPluralEn n = if n == 1 then T.pack "item" else T.pack "items"

-- ============================================================================
-- FORMATTING
-- ============================================================================

formatCurrency :: Double -> Text -> Text
formatCurrency amount currency =
  T.pack (show amount) <> T.pack " " <> currency

formatQty :: Double -> Text
formatQty qty = T.pack (show qty)

data DateFormat = DF_ISO | DF_US | DF_EU | DF_RU

formatDate :: DateFormat -> (Int, Int, Int) -> Text
formatDate fmt (y, m, d) = case fmt of
  DF_ISO -> T.pack (show y <> "-" <> pad m <> "-" <> pad d)
  DF_US -> T.pack (pad m <> "/" <> pad d <> "/" <> show y)
  DF_EU -> T.pack (pad d <> "." <> pad m <> "." <> show y)
  DF_RU -> T.pack (pad d <> "." <> pad m <> "." <> show y)
  where
    pad n = if n < 10 then "0" <> show n else show n
