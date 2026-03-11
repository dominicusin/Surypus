-- ============================================================================
-- SURYPUS INTERNATIONALIZATION (i18n)
-- ============================================================================
-- Multi-language support: RU, EN, DE, FR, ZH
-- ============================================================================

module Surypus.I18n where

import           Data.Map  (Map)
import qualified Data.Map  as Map
import           Data.Text (Text)
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
    = D_Core | D_Accounting | D_Warehouse | D_Bills
    | D_Persons | D_Goods | D_Reports | D_API
    | D_Validation | D_UI | D_System
    deriving (Show, Eq, Ord)

newtype TransKey = TransKey (Domain, String)
    deriving (Show, Eq, Ord)

type Translations = Map Language (Map TransKey Text)

allTranslations :: Translations
allTranslations = Map.fromList
    [ (RU, ruTranslations)
    , (EN, enTranslations)
    , (DE, deTranslations)
    , (FR, frTranslations)
    , (ZH, zhTranslations)
    ]

-- ============================================================================
-- RUSSIAN TRANSLATIONS
-- ============================================================================

ruTranslations :: Map TransKey Text
ruTranslations = Map.fromList
    [ (k D_Core "id", T.pack "Идентификатор")
    , (k D_Core "name", T.pack "Наименование")
    , (k D_Core "code", T.pack "Код")
    , (k D_Core "status", T.pack "Статус")
    , (k D_Core "active", T.pack "Активный")
    , (k D_Core "blocked", T.pack "Заблокирован")
    , (k D_Core "deleted", T.pack "Удален")
    , (k D_Core "draft", T.pack "Черновик")
    , (k D_Core "created_at", T.pack "Дата создания")
    , (k D_Core "updated_at", T.pack "Дата изменения")
    , (k D_Core "notes", T.pack "Комментарий")
    , (k D_Core "address", T.pack "Адрес")
    , (k D_Core "phone", T.pack "Телефон")
    , (k D_Core "email", T.pack "Email")
    , (k D_Core "inn", T.pack "ИНН")
    , (k D_Core "kpp", T.pack "КПП")
    , (k D_Persons "person", T.pack "Контрагент")
    , (k D_Persons "company", T.pack "Юридическое лицо")
    , (k D_Persons "individual", T.pack "Физическое лицо")
    , (k D_Persons "entrepreneur", T.pack "ИП")
    , (k D_Persons "credit_limit", T.pack "Кредитный лимит")
    , (k D_Persons "discount", T.pack "Скидка")
    , (k D_Goods "goods", T.pack "Товар")
    , (k D_Goods "product", T.pack "Продукция")
    , (k D_Goods "service", T.pack "Услуга")
    , (k D_Goods "barcode", T.pack "Штрих-код")
    , (k D_Goods "unit", T.pack "Единица измерения")
    , (k D_Goods "quantity", T.pack "Количество")
    , (k D_Goods "price", T.pack "Цена")
    , (k D_Goods "cost", T.pack "Себестоимость")
    , (k D_Warehouse "warehouse", T.pack "Склад")
    , (k D_Warehouse "location", T.pack "Местоположение")
    , (k D_Warehouse "stock", T.pack "Остаток")
    , (k D_Warehouse "reserved", T.pack "Резерв")
    , (k D_Warehouse "available", T.pack "Доступно")
    , (k D_Warehouse "movement", T.pack "Перемещение")
    , (k D_Warehouse "receipt", T.pack "Приход")
    , (k D_Warehouse "issue", T.pack "Расход")
    , (k D_Warehouse "transfer", T.pack "Перемещение")
    , (k D_Warehouse "inventory", T.pack "Инвентаризация")
    , (k D_Bills "bill", T.pack "Документ")
    , (k D_Bills "sale", T.pack "Продажа")
    , (k D_Bills "purchase", T.pack "Закупка")
    , (k D_Bills "return", T.pack "Возврат")
    , (k D_Bills "invoice", T.pack "Счет-фактура")
    , (k D_Bills "order", T.pack "Заказ")
    , (k D_Bills "total", T.pack "Итого")
    , (k D_Bills "tax", T.pack "Налог")
    , (k D_Bills "discount", T.pack "Скидка")
    , (k D_Bills "date", T.pack "Дата")
    , (k D_Accounting "account", T.pack "Счет")
    , (k D_Accounting "debit", T.pack "Дебет")
    , (k D_Accounting "credit", T.pack "Кредит")
    , (k D_Accounting "entry", T.pack "Проводка")
    , (k D_Accounting "asset", T.pack "Актив")
    , (k D_Accounting "liability", T.pack "Пассив")
    , (k D_Accounting "equity", T.pack "Капитал")
    , (k D_Accounting "revenue", T.pack "Доходы")
    , (k D_Accounting "expense", T.pack "Расходы")
    , (k D_Accounting "balance", T.pack "Остаток")
    , (k D_Accounting "currency", T.pack "Валюта")
    , (k D_Accounting "vat", T.pack "НДС")
    , (k D_Reports "report", T.pack "Отчет")
    , (k D_Reports "sales_report", T.pack "Продажи")
    , (k D_Reports "purchase_report", T.pack "Закупки")
    , (k D_API "not_found", T.pack "Объект не найден")
    , (k D_API "unauthorized", T.pack "Не авторизован")
    , (k D_API "forbidden", T.pack "Доступ запрещен")
    , (k D_API "bad_request", T.pack "Неверный запрос")
    , (k D_API "created", T.pack "Создано")
    , (k D_API "updated", T.pack "Обновлено")
    , (k D_API "deleted", T.pack "Удалено")
    , (k D_Validation "required", T.pack "Обязательное поле")
    , (k D_Validation "invalid_inn", T.pack "Неверный ИНН")
    , (k D_Validation "invalid_email", T.pack "Неверный Email")
    , (k D_Validation "insufficient_stock", T.pack "Недостаточно товара")
    , (k D_Validation "credit_exceeded", T.pack "Превышен кредитный лимит")
    , (k D_UI "save", T.pack "Сохранить")
    , (k D_UI "cancel", T.pack "Отмена")
    , (k D_UI "delete", T.pack "Удалить")
    , (k D_UI "edit", T.pack "Редактировать")
    , (k D_UI "create", T.pack "Создать")
    , (k D_UI "search", T.pack "Поиск")
    , (k D_UI "filter", T.pack "Фильтр")
    , (k D_UI "refresh", T.pack "Обновить")
    , (k D_UI "export", T.pack "Экспорт")
    , (k D_UI "import", T.pack "Импорт")
    , (k D_UI "print", T.pack "Печать")
    , (k D_UI "close", T.pack "Закрыть")
    , (k D_UI "yes", T.pack "Да")
    , (k D_UI "no", T.pack "Нет")
    , (k D_UI "ok", T.pack "ОК")
    , (k D_UI "apply", T.pack "Применить")
    , (k D_UI "loading", T.pack "Загрузка...")
    , (k D_UI "no_data", T.pack "Нет данных")
    , (k D_System "success", T.pack "Успешно")
    , (k D_System "error", T.pack "Ошибка")
    , (k D_System "warning", T.pack "Предупреждение")
    , (k D_System "info", T.pack "Информация")
    ]
    where k d t = TransKey (d, t)

-- ============================================================================
-- ENGLISH TRANSLATIONS
-- ============================================================================

enTranslations :: Map TransKey Text
enTranslations = Map.fromList
    [ (k D_Core "id", T.pack "ID")
    , (k D_Core "name", T.pack "Name")
    , (k D_Core "code", T.pack "Code")
    , (k D_Core "status", T.pack "Status")
    , (k D_Core "active", T.pack "Active")
    , (k D_Core "blocked", T.pack "Blocked")
    , (k D_Core "deleted", T.pack "Deleted")
    , (k D_Core "draft", T.pack "Draft")
    , (k D_Core "created_at", T.pack "Created at")
    , (k D_Core "updated_at", T.pack "Updated at")
    , (k D_Core "notes", T.pack "Notes")
    , (k D_Core "address", T.pack "Address")
    , (k D_Core "phone", T.pack "Phone")
    , (k D_Core "email", T.pack "Email")
    , (k D_Core "inn", T.pack "INN")
    , (k D_Core "kpp", T.pack "KPP")
    , (k D_Persons "person", T.pack "Counteragent")
    , (k D_Persons "company", T.pack "Company")
    , (k D_Persons "individual", T.pack "Individual")
    , (k D_Persons "entrepreneur", T.pack "Entrepreneur")
    , (k D_Persons "credit_limit", T.pack "Credit limit")
    , (k D_Persons "discount", T.pack "Discount")
    , (k D_Goods "goods", T.pack "Goods")
    , (k D_Goods "product", T.pack "Product")
    , (k D_Goods "service", T.pack "Service")
    , (k D_Goods "barcode", T.pack "Barcode")
    , (k D_Goods "unit", T.pack "Unit")
    , (k D_Goods "quantity", T.pack "Quantity")
    , (k D_Goods "price", T.pack "Price")
    , (k D_Goods "cost", T.pack "Cost")
    , (k D_Warehouse "warehouse", T.pack "Warehouse")
    , (k D_Warehouse "location", T.pack "Location")
    , (k D_Warehouse "stock", T.pack "Stock")
    , (k D_Warehouse "reserved", T.pack "Reserved")
    , (k D_Warehouse "available", T.pack "Available")
    , (k D_Warehouse "movement", T.pack "Movement")
    , (k D_Warehouse "receipt", T.pack "Receipt")
    , (k D_Warehouse "issue", T.pack "Issue")
    , (k D_Warehouse "transfer", T.pack "Transfer")
    , (k D_Warehouse "inventory", T.pack "Inventory")
    , (k D_Bills "bill", T.pack "Document")
    , (k D_Bills "sale", T.pack "Sale")
    , (k D_Bills "purchase", T.pack "Purchase")
    , (k D_Bills "return", T.pack "Return")
    , (k D_Bills "invoice", T.pack "Invoice")
    , (k D_Bills "order", T.pack "Order")
    , (k D_Bills "total", T.pack "Total")
    , (k D_Bills "tax", T.pack "Tax")
    , (k D_Bills "discount", T.pack "Discount")
    , (k D_Bills "date", T.pack "Date")
    , (k D_Accounting "account", T.pack "Account")
    , (k D_Accounting "debit", T.pack "Debit")
    , (k D_Accounting "credit", T.pack "Credit")
    , (k D_Accounting "entry", T.pack "Entry")
    , (k D_Accounting "asset", T.pack "Asset")
    , (k D_Accounting "liability", T.pack "Liability")
    , (k D_Accounting "equity", T.pack "Equity")
    , (k D_Accounting "revenue", T.pack "Revenue")
    , (k D_Accounting "expense", T.pack "Expense")
    , (k D_Accounting "balance", T.pack "Balance")
    , (k D_Accounting "currency", T.pack "Currency")
    , (k D_Accounting "vat", T.pack "VAT")
    , (k D_Reports "report", T.pack "Report")
    , (k D_Reports "sales_report", T.pack "Sales")
    , (k D_Reports "purchase_report", T.pack "Purchases")
    , (k D_API "not_found", T.pack "Not found")
    , (k D_API "unauthorized", T.pack "Unauthorized")
    , (k D_API "forbidden", T.pack "Forbidden")
    , (k D_API "bad_request", T.pack "Bad request")
    , (k D_API "created", T.pack "Created")
    , (k D_API "updated", T.pack "Updated")
    , (k D_API "deleted", T.pack "Deleted")
    , (k D_Validation "required", T.pack "Required field")
    , (k D_Validation "invalid_inn", T.pack "Invalid INN")
    , (k D_Validation "invalid_email", T.pack "Invalid email")
    , (k D_Validation "insufficient_stock", T.pack "Insufficient stock")
    , (k D_Validation "credit_exceeded", T.pack "Credit limit exceeded")
    , (k D_UI "save", T.pack "Save")
    , (k D_UI "cancel", T.pack "Cancel")
    , (k D_UI "delete", T.pack "Delete")
    , (k D_UI "edit", T.pack "Edit")
    , (k D_UI "create", T.pack "Create")
    , (k D_UI "search", T.pack "Search")
    , (k D_UI "filter", T.pack "Filter")
    , (k D_UI "refresh", T.pack "Refresh")
    , (k D_UI "export", T.pack "Export")
    , (k D_UI "import", T.pack "Import")
    , (k D_UI "print", T.pack "Print")
    , (k D_UI "close", T.pack "Close")
    , (k D_UI "yes", T.pack "Yes")
    , (k D_UI "no", T.pack "No")
    , (k D_UI "ok", T.pack "OK")
    , (k D_UI "apply", T.pack "Apply")
    , (k D_UI "loading", T.pack "Loading...")
    , (k D_UI "no_data", T.pack "No data")
    , (k D_System "success", T.pack "Success")
    , (k D_System "error", T.pack "Error")
    , (k D_System "warning", T.pack "Warning")
    , (k D_System "info", T.pack "Info")
    ]
    where k d t = TransKey (d, t)

-- ============================================================================
-- GERMAN TRANSLATIONS (Partial)
-- ============================================================================

deTranslations :: Map TransKey Text
deTranslations = Map.fromList
    [ (k D_Core "id", T.pack "ID")
    , (k D_Core "name", T.pack "Name")
    , (k D_Core "code", T.pack "Code")
    , (k D_Core "status", T.pack "Status")
    , (k D_Core "active", T.pack "Aktiv")
    , (k D_Core "blocked", T.pack "Gesperrt")
    , (k D_UI "save", T.pack "Speichern")
    , (k D_UI "cancel", T.pack "Abbrechen")
    , (k D_UI "delete", T.pack "Löschen")
    , (k D_UI "yes", T.pack "Ja")
    , (k D_UI "no", T.pack "Nein")
    , (k D_UI "ok", T.pack "OK")
    , (k D_System "success", T.pack "Erfolg")
    , (k D_System "error", T.pack "Fehler")
    ]
    where k d t = TransKey (d, t)

-- ============================================================================
-- FRENCH TRANSLATIONS (Partial)
-- ============================================================================

frTranslations :: Map TransKey Text
frTranslations = Map.fromList
    [ (k D_Core "id", T.pack "ID")
    , (k D_Core "name", T.pack "Nom")
    , (k D_Core "code", T.pack "Code")
    , (k D_Core "status", T.pack "Statut")
    , (k D_Core "active", T.pack "Actif")
    , (k D_Core "blocked", T.pack "Bloqué")
    , (k D_UI "save", T.pack "Enregistrer")
    , (k D_UI "cancel", T.pack "Annuler")
    , (k D_UI "delete", T.pack "Supprimer")
    , (k D_UI "yes", T.pack "Oui")
    , (k D_UI "no", T.pack "Non")
    , (k D_UI "ok", T.pack "OK")
    , (k D_System "success", T.pack "Succès")
    , (k D_System "error", T.pack "Erreur")
    ]
    where k d t = TransKey (d, t)

-- ============================================================================
-- CHINESE TRANSLATIONS (Partial)
-- ============================================================================

zhTranslations :: Map TransKey Text
zhTranslations = Map.fromList
    [ (k D_Core "id", T.pack "Bian Hao")
    , (k D_Core "name", T.pack "Ming Cheng")
    , (k D_Core "code", T.pack "Dai Ma")
    , (k D_Core "status", T.pack "Zhuang Tai")
    , (k D_Core "active", T.pack "Huo Yue")
    , (k D_Core "blocked", T.pack "Yi Ping Bi")
    , (k D_UI "save", T.pack "Bao Cun")
    , (k D_UI "cancel", T.pack "Qu Xiao")
    , (k D_UI "delete", T.pack "Shan Chu")
    , (k D_UI "yes", T.pack "Shi")
    , (k D_UI "no", T.pack "Fou")
    , (k D_UI "ok", T.pack "Que Ren")
    , (k D_System "success", T.pack "Cheng Gong")
    , (k D_System "error", T.pack "Cuo Wu")
    ]
    where k d t = TransKey (d, t)

-- ============================================================================
-- TRANSLATION FUNCTIONS
-- ============================================================================

translate :: Language -> Domain -> String -> Text
translate lang domain key =
    let transKey = TransKey (domain, key)
    in case Map.lookup lang allTranslations of
        Just langMap -> case Map.lookup transKey langMap of
            Just text -> text
            Nothing   -> T.pack key
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
    { pfOne  :: Text
    , pfFew  :: Text
    , pfMany :: Text
    }

plural :: Int -> PluralForms -> Text
plural n nforms
    | n == 1 = pfOne nforms
    | n >= 2 && n <= 4 = pfFew nforms
    | otherwise = pfMany nforms

itemsPluralRu :: Int -> Text
itemsPluralRu n = plural n $ PluralForms
    { pfOne = T.pack "элемент"
    , pfFew = T.pack "элемента"
    , pfMany = T.pack "элементов"
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
    DF_US  -> T.pack (pad m <> "/" <> pad d <> "/" <> show y)
    DF_EU  -> T.pack (pad d <> "." <> pad m <> "." <> show y)
    DF_RU  -> T.pack (pad d <> "." <> pad m <> "." <> show y)
    where
        pad n = if n < 10 then "0" ++ show n else show n
