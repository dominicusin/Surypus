-- ============================================================================
-- SURYPUS REPORTS - JasperReports/Helical/Pentaho Integration
-- ============================================================================
-- 678 Crystal Reports -> JasperReports JRXML conversion
-- Categories: Accounting, Warehouse, Bills, Payroll, Banking, etc.
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}

module Surypus.Reports where

import           Data.Map  (Map)
import qualified Data.Map  as Map
import           Data.Text (Text)
import qualified Data.Text as T

-- ============================================================================
-- REPORT CATEGORIES
-- ============================================================================

data ReportCategory
    = RC_Accounting      -- Бухгалтерия
    | RC_Warehouse       -- Склад
    | RC_Bills           -- Документы
    | RC_Payroll         -- Зарплата
    | RC_Banking         -- Банк
    | RC_Persons         -- Контрагенты
    | RC_Goods           -- Товары
    | RC_Tax             -- Налоги
    | RC_CashSession     -- Кассы
    | RC_Project         -- Проекты
    | RC_Asset           -- ОС
    | RC_Analytics       -- Аналитика
    | RC_System          -- Системные
    deriving (Show, Eq, Enum)

-- ============================================================================
-- REPORT DEFINITION
-- ============================================================================

data ReportDef = ReportDef
    { rdName        :: Text           -- Internal name
    , rdTitle       :: Text           -- Display title
    , rdCategory    :: ReportCategory
    , rdDescription :: Text
    , rdJrxml       :: Text           -- JRXML template
    , rdSql         :: Text           -- Main query
    , rdParams      :: [ParamDef]     -- Report parameters
    , rdFields      :: [FieldDef]     -- Data fields
    , rdGroups      :: [GroupDef]     -- Grouping
    } deriving (Show)

data ParamDef = ParamDef
    { pName     :: Text
    , pType     :: ParamType
    , pLabel    :: Text
    , pRequired :: Bool
    , pDefault  :: Maybe Text
    } deriving (Show)

data ParamType = PT_Date | PT_DateRange | PT_Int | PT_Text | PT_Double | PT_Boolean | PT_List
    deriving (Show, Eq)

data FieldDef = FieldDef
    { fName    :: Text
    , fType    :: FieldType
    , fFormula :: Maybe Text
    } deriving (Show)

data FieldType = FT_String | FT_Integer | FT_Double | FT_Date | FT_Boolean | FT_BigDecimal
    deriving (Show, Eq)

data GroupDef = GroupDef
    { gName    :: Text
    , gField   :: Text
    , gSortAsc :: Bool
    } deriving (Show)

-- ============================================================================
-- JRXML TEMPLATE GENERATOR
-- ============================================================================

-- | Generate JRXML from ReportDef
generateJRXML :: ReportDef -> Text
generateJRXML r = T.unlines
    [ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    , "<jasperReport xmlns=\"http://jasperreports.sourceforge.net/jasperreports\""
    , "              name=\"" <> rdName r <> "\""
    , "              pageWidth=\"595\" pageHeight=\"842\""
    , "              columnWidth=\"555\" leftMargin=\"20\" rightMargin=\"20\""
    , "              topMargin=\"20\" bottomMargin=\"20\">"
    , "  <parameter name=\"REPORT_TITLE\" class=\"java.lang.String\"/>"
    , "  <parameter name=\"REPORT_DATE\" class=\"java.util.Date\"/>"
    , generateParams (rdParams r)
    , "  <queryString>"
    , "    <![CDATA[" <> rdSql r <> "]]>"
    , "  </queryString>"
    , generateFields (rdFields r)
    , "  <title>"
    , "    <band height=\"50\">"
    , "      <staticText>"
    , "        <reportElement x=\"0\" y=\"0\" width=\"555\" height=\"30\"/>"
    , "        <text><![CDATA[" <> rdTitle r <> "]]></text>"
    , "      </staticText>"
    , "    </band>"
    , "  </title>"
    , "  <detail>"
    , "    <band height=\"20\">"
    , generateDetailFields (rdFields r)
    , "    </band>"
    , "  </detail>"
    , "</jasperReport>"
    ]

generateParams :: [ParamDef] -> Text
generateParams ps = T.unlines $ map genParam ps
    where
        genParam p = "  <parameter name=\"" <> pName p <> "\" class=\""
            <> paramClass (pType p) <> "\""
            <> (if pRequired p then " isForPrompting=\"true\"" else "")
            <> "/>"
        paramClass PT_Date      = "java.util.Date"
        paramClass PT_DateRange = "java.util.Date"
        paramClass PT_Int       = "java.lang.Integer"
        paramClass PT_Text      = "java.lang.String"
        paramClass PT_Double    = "java.lang.Double"
        paramClass PT_Boolean   = "java.lang.Boolean"
        paramClass PT_List      = "java.lang.String"

generateFields :: [FieldDef] -> Text
generateFields fs = T.unlines $ "  <field name=\"ROW_NUMBER\" class=\"java.lang.Integer\"/>"
    : map genField fs
    where
        genField f = "  <field name=\"" <> fName f <> "\" class=\""
            <> fieldClass (fType f) <> "\"/>"
        fieldClass FT_String     = "java.lang.String"
        fieldClass FT_Integer    = "java.lang.Integer"
        fieldClass FT_Double     = "java.lang.Double"
        fieldClass FT_Date       = "java.util.Date"
        fieldClass FT_Boolean    = "java.lang.Boolean"
        fieldClass FT_BigDecimal = "java.math.BigDecimal"

generateDetailFields :: [FieldDef] -> Text
generateDetailFields fs = T.unlines $ map genTextField fs
    where
        genTextField f = T.unlines
            [ "      <textField>"
            , "        <reportElement x=\"0\" y=\"0\" width=\"100\" height=\"20\"/>"
            , "        <textFieldExpression><![CDATA[$F{" <> fName f <> "}]]></textFieldExpression>"
            , "      </textField>"
            ]

-- ============================================================================
-- ACCOUNTING REPORTS
-- ============================================================================

-- | Balance sheet (Баланс)
balanceReport :: ReportDef
balanceReport = ReportDef
    { rdName = "Balance"
    , rdTitle = "Balance Sheet / Бухгалтерский баланс"
    , rdCategory = RC_Accounting
    , rdDescription = "Balance sheet (form 1)"
    , rdJrxml = generateJRXML balanceReport
    , rdSql = T.unlines
        [ "SELECT a.code as AccountCode, a.name as AccountName,"
        , "       SUM(at.dbt) as DebitTurnover, SUM(at.crd) as CreditTurnover,"
        , "       (SELECT SUM(dbt) - SUM(crd) FROM acc_turn WHERE acc_id <= a.id AND dt <= $P{EndDate}) as Balance"
        , "FROM acc_plan a"
        , "LEFT JOIN acc_turn at ON at.acc_id = a.id AND at.dt BETWEEN $P{StartDate} AND $P{EndDate}"
        , "WHERE a.parent_id IS NULL"
        , "GROUP BY a.id, a.code, a.name"
        , "ORDER BY a.code"
        ]
    , rdParams =
        [ ParamDef "StartDate" PT_Date "Start Date" True Nothing
        , ParamDef "EndDate" PT_Date "End Date" True Nothing
        ]
    , rdFields =
        [ FieldDef "AccountCode" FT_String Nothing
        , FieldDef "AccountName" FT_String Nothing
        , FieldDef "DebitTurnover" FT_BigDecimal Nothing
        , FieldDef "CreditTurnover" FT_BigDecimal Nothing
        , FieldDef "Balance" FT_BigDecimal Nothing
        ]
    , rdGroups = []
    }

-- | Account turnover (Обороты по счету)
accountTurnoverReport :: ReportDef
accountTurnoverReport = ReportDef
    { rdName = "AccountTurnover"
    , rdTitle = "Account Turnover / Оборотно-сальдовая ведомость"
    , rdCategory = RC_Accounting
    , rdDescription = "Account turnover with balances"
    , rdJrxml = generateJRXML accountTurnoverReport
    , rdSql = T.unlines
        [ "SELECT ap.code as AccCode, ap.name as AccName,"
        , "       COALESCE(SUM(at.dbt), 0) as DebitSum,"
        , "       COALESCE(SUM(at.crd), 0) as CreditSum"
        , "FROM acc_plan ap"
        , "LEFT JOIN acc_turn at ON at.acc_id = ap.id"
        , "     AND at.dt BETWEEN $P{StartDate} AND $P{EndDate}"
        , "WHERE ap.is_analytic = TRUE"
        , "GROUP BY ap.id, ap.code, ap.name"
        , "HAVING COALESCE(SUM(at.dbt), 0) + COALESCE(SUM(at.crd), 0) > 0"
        , "ORDER BY ap.code"
        ]
    , rdParams =
        [ ParamDef "StartDate" PT_Date "Start Date" True Nothing
        , ParamDef "EndDate" PT_Date "End Date" True Nothing
        ]
    , rdFields =
        [ FieldDef "AccCode" FT_String Nothing
        , FieldDef "AccName" FT_String Nothing
        , FieldDef "DebitSum" FT_BigDecimal Nothing
        , FieldDef "CreditSum" FT_BigDecimal Nothing
        ]
    , rdGroups = []
    }

-- | Accounting entry list (Журнал проводок)
accountingEntryList :: ReportDef
accountingEntryList = ReportDef
    { rdName = "AccEntryList"
    , rdTitle = "Journal of Entries / Журнал проводок"
    , rdCategory = RC_Accounting
    , rdDescription = "Accounting entries journal"
    , rdJrxml = generateJRXML accountingEntryList
    , rdSql = T.unlines
        [ "SELECT at.dt as Date, at.doc_id as DocID,"
        , "       da.code as DebitAcc, ca.code as CreditAcc,"
        , "       at.amount as Amount, at.memo as Memo"
        , "FROM acc_turn at"
        , "JOIN acc_plan da ON da.id = at.dbt_acc_id"
        , "JOIN acc_plan ca ON ca.id = at.crd_acc_id"
        , "WHERE at.dt BETWEEN $P{StartDate} AND $P{EndDate}"
        , "ORDER BY at.dt, at.id"
        ]
    , rdParams =
        [ ParamDef "StartDate" PT_Date "Start Date" True Nothing
        , ParamDef "EndDate" PT_Date "End Date" True Nothing
        ]
    , rdFields =
        [ FieldDef "Date" FT_Date Nothing
        , FieldDef "DocID" FT_Integer Nothing
        , FieldDef "DebitAcc" FT_String Nothing
        , FieldDef "CreditAcc" FT_String Nothing
        , FieldDef "Amount" FT_BigDecimal Nothing
        , FieldDef "Memo" FT_String Nothing
        ]
    , rdGroups = []
    }

-- ============================================================================
-- WAREHOUSE REPORTS
-- ============================================================================

-- | Goods rest (Остатки товаров)
goodsRestReport :: ReportDef
goodsRestReport = ReportDef
    { rdName = "GoodsRest"
    , rdTitle = "Stock Balance / Остатки товаров"
    , rdCategory = RC_Warehouse
    , rdDescription = "Current stock by locations"
    , rdJrxml = generateJRXML goodsRestReport
    , rdSql = T.unlines
        [ "SELECT g.code as GoodsCode, g.name as GoodsName,"
        , "       u.symbol as UnitSymbol,"
        , "       l.name as LocationName,"
        , "       gr.qty as Quantity, gr.price as Price,"
        , "       gr.qty * gr.price as TotalCost"
        , "FROM goods_rest gr"
        , "JOIN goods g ON g.id = gr.goods_id"
        , "JOIN location l ON l.id = gr.loc_id"
        , "JOIN unit u ON u.id = g.unit_id"
        , "WHERE gr.qty > 0"
        , "ORDER BY g.name, l.name"
        ]
    , rdParams =
        [ ParamDef "LocationID" PT_List "Location" False (Just "0")
        , ParamDef "GoodsGroupID" PT_List "Goods Group" False (Just "0")
        ]
    , rdFields =
        [ FieldDef "GoodsCode" FT_String Nothing
        , FieldDef "GoodsName" FT_String Nothing
        , FieldDef "UnitSymbol" FT_String Nothing
        , FieldDef "LocationName" FT_String Nothing
        , FieldDef "Quantity" FT_Double Nothing
        , FieldDef "Price" FT_BigDecimal Nothing
        , FieldDef "TotalCost" FT_BigDecimal Nothing
        ]
    , rdGroups = [GroupDef "ByLocation" "LocationName" True]
    }

-- | Goods movement (Движение товаров)
goodsMovementReport :: ReportDef
goodsMovementReport = ReportDef
    { rdName = "GoodsMovement"
    , rdTitle = "Goods Movement / Движение товаров"
    , rdCategory = RC_Warehouse
    , rdDescription = "Incoming and outgoing goods"
    , rdJrxml = generateJRXML goodsMovementReport
    , rdSql = T.unlines
        [ "SELECT gm.dt as Date, g.code as GoodsCode, g.name as GoodsName,"
        , "       lfrom.name as FromLoc, lto.name as ToLoc,"
        , "       gm.qty as Quantity, gm.cost as Cost,"
        , "       bt.name as BillType"
        , "FROM goods_movement gm"
        , "JOIN goods g ON g.id = gm.goods_id"
        , "JOIN location lfrom ON lfrom.id = gm.loc_from_id"
        , "JOIN location lto ON lto.id = gm.loc_to_id"
        , "LEFT JOIN bill_type bt ON bt.id = gm.bill_type_id"
        , "WHERE gm.dt BETWEEN $P{StartDate} AND $P{EndDate}"
        , "ORDER BY gm.dt DESC"
        ]
    , rdParams =
        [ ParamDef "StartDate" PT_Date "Start Date" True Nothing
        , ParamDef "EndDate" PT_Date "End Date" True Nothing
        ]
    , rdFields =
        [ FieldDef "Date" FT_Date Nothing
        , FieldDef "GoodsCode" FT_String Nothing
        , FieldDef "GoodsName" FT_String Nothing
        , FieldDef "FromLoc" FT_String Nothing
        , FieldDef "ToLoc" FT_String Nothing
        , FieldDef "Quantity" FT_Double Nothing
        , FieldDef "Cost" FT_BigDecimal Nothing
        , FieldDef "BillType" FT_String Nothing
        ]
    , rdGroups = []
    }

-- | Inventory report (Инвентаризация)
inventoryReport :: ReportDef
inventoryReport = ReportDef
    { rdName = "Inventory"
    , rdTitle = "Inventory / Инвентаризация"
    , rdCategory = RC_Warehouse
    , rdDescription = "Inventory worksheet"
    , rdJrxml = generateJRXML inventoryReport
    , rdSql = T.unlines
        [ "SELECT g.code as GoodsCode, g.name as GoodsName,"
        , "       u.symbol as Unit,"
        , "       inv.qty_fact as FactQty, inv.qty_plan as PlanQty,"
        , "       inv.qty_fact - inv.qty_plan as Diff"
        , "FROM inventory_line inv"
        , "JOIN goods g ON g.id = inv.goods_id"
        , "JOIN unit u ON u.id = g.unit_id"
        , "WHERE inv.inventory_id = $P{InventoryID}"
        , "ORDER BY g.name"
        ]
    , rdParams =
        [ ParamDef "InventoryID" PT_Int "Inventory #" True Nothing
        ]
    , rdFields =
        [ FieldDef "GoodsCode" FT_String Nothing
        , FieldDef "GoodsName" FT_String Nothing
        , FieldDef "Unit" FT_String Nothing
        , FieldDef "FactQty" FT_Double Nothing
        , FieldDef "PlanQty" FT_Double Nothing
        , FieldDef "Diff" FT_Double Nothing
        ]
    , rdGroups = []
    }

-- ============================================================================
-- BILLS REPORTS
-- ============================================================================

-- | Bill list (Список документов)
billListReport :: ReportDef
billListReport = ReportDef
    { rdName = "BillList"
    , rdTitle = "Documents List / Список документов"
    , rdCategory = RC_Bills
    , rdDescription = "List of all bills"
    , rdJrxml = generateJRXML billListReport
    , rdSql = T.unlines
        [ "SELECT b.dt as Date, b.code as BillCode,"
        , "       p.name as PersonName, bt.name as BillTypeName,"
        , "       b.total as Total, b.status as Status"
        , "FROM bill b"
        , "JOIN bill_type bt ON bt.id = b.bill_type_id"
        , "LEFT JOIN person p ON p.id = b.person_id"
        , "WHERE b.dt BETWEEN $P{StartDate} AND $P{EndDate}"
        , "  AND ($P{BillTypeID} = 0 OR b.bill_type_id = $P{BillTypeID})"
        , "  AND ($P{PersonID} = 0 OR b.person_id = $P{PersonID})"
        , "ORDER BY b.dt DESC, b.code"
        ]
    , rdParams =
        [ ParamDef "StartDate" PT_Date "Start Date" True Nothing
        , ParamDef "EndDate" PT_Date "End Date" True Nothing
        , ParamDef "BillTypeID" PT_Int "Bill Type" False (Just "0")
        , ParamDef "PersonID" PT_Int "Person" False (Just "0")
        ]
    , rdFields =
        [ FieldDef "Date" FT_Date Nothing
        , FieldDef "BillCode" FT_String Nothing
        , FieldDef "PersonName" FT_String Nothing
        , FieldDef "BillTypeName" FT_String Nothing
        , FieldDef "Total" FT_BigDecimal Nothing
        , FieldDef "Status" FT_String Nothing
        ]
    , rdGroups = [GroupDef "ByDate" "Date" False]
    }

-- | Goods bill (Товарная накладная)
goodsBillReport :: ReportDef
goodsBillReport = ReportDef
    { rdName = "GoodsBill"
    , rdTitle = "Goods Bill / Товарная накладная"
    , rdCategory = RC_Bills
    , rdDescription = "Goods bill document"
    , rdJrxml = generateJRXML goodsBillReport
    , rdSql = T.unlines
        [ "SELECT bl.ord as LineNo, g.code as GoodsCode, g.name as GoodsName,"
        , "       bl.qty as Quantity, u.symbol as Unit,"
        , "       bl.price as Price, bl.discount as Discount,"
        , "       bl.qty * bl.price * (1 - bl.discount/100) as LineTotal"
        , "FROM bill_line bl"
        , "JOIN goods g ON g.id = bl.goods_id"
        , "JOIN unit u ON u.id = g.unit_id"
        , "WHERE bl.bill_id = $P{BillID}"
        , "ORDER BY bl.ord"
        ]
    , rdParams =
        [ ParamDef "BillID" PT_Int "Bill ID" True Nothing
        ]
    , rdFields =
        [ FieldDef "LineNo" FT_Integer Nothing
        , FieldDef "GoodsCode" FT_String Nothing
        , FieldDef "GoodsName" FT_String Nothing
        , FieldDef "Quantity" FT_Double Nothing
        , FieldDef "Unit" FT_String Nothing
        , FieldDef "Price" FT_BigDecimal Nothing
        , FieldDef "Discount" FT_Double Nothing
        , FieldDef "LineTotal" FT_BigDecimal Nothing
        ]
    , rdGroups = []
    }

-- | Invoice (Счет-фактура)
invoiceReport :: ReportDef
invoiceReport = ReportDef
    { rdName = "Invoice"
    , rdTitle = "Invoice / Счет-фактура"
    , rdCategory = RC_Bills
    , rdDescription = "VAT invoice"
    , rdJrxml = generateJRXML invoiceReport
    , rdSql = T.unlines
        [ "SELECT bl.ord as Num, g.name as GoodsName, bl.qty as Qty, bl.price as Price,"
        , "       bl.qty * bl.price as TotalWoTax,"
        , "       bl.tax_rate as TaxRate, bl.tax as TaxAmount,"
        , "       bl.qty * bl.price + bl.tax as TotalWithTax"
        , "FROM bill_line bl"
        , "JOIN goods g ON g.id = bl.goods_id"
        , "WHERE bl.bill_id = $P{BillID} AND bl.tax > 0"
        , "ORDER BY bl.ord"
        ]
    , rdParams =
        [ ParamDef "BillID" PT_Int "Bill ID" True Nothing
        ]
    , rdFields =
        [ FieldDef "Num" FT_Integer Nothing
        , FieldDef "GoodsName" FT_String Nothing
        , FieldDef "Qty" FT_Double Nothing
        , FieldDef "Price" FT_BigDecimal Nothing
        , FieldDef "TotalWoTax" FT_BigDecimal Nothing
        , FieldDef "TaxRate" FT_Double Nothing
        , FieldDef "TaxAmount" FT_BigDecimal Nothing
        , FieldDef "TotalWithTax" FT_BigDecimal Nothing
        ]
    , rdGroups = []
    }

-- ============================================================================
-- PAYROLL REPORTS
-- ============================================================================

-- | Salary report (Зарплата)
salaryReport :: ReportDef
salaryReport = ReportDef
    { rdName = "Salary"
    , rdTitle = "Salary Report / Расчетная ведомость"
    , rdCategory = RC_Payroll
    , rdDescription = "Employee salary calculation"
    , rdJrxml = generateJRXML salaryReport
    , rdSql = T.unlines
        [ "SELECT e.emp_id as EmpID, prsn.name as EmpName, sr.name as Position,"
        , "       ss.base as BaseSalary, ss.bonus as Bonus,"
        , "       ss.deductions as Deductions, ss.net as NetSalary"
        , "FROM salary_sheet ss"
        , "JOIN employee e ON e.id = ss.emp_id"
        , "JOIN person prsn ON prsn.id = e.person_id"
        , "JOIN staff_rank sr ON sr.id = e.rank_id"
        , "WHERE ss.period = $P{Period}"
        , "ORDER BY prsn.name"
        ]
    , rdParams =
        [ ParamDef "Period" PT_Text "Period (YYYY-MM)" True Nothing
        ]
    , rdFields =
        [ FieldDef "EmpID" FT_Integer Nothing
        , FieldDef "EmpName" FT_String Nothing
        , FieldDef "Position" FT_String Nothing
        , FieldDef "BaseSalary" FT_BigDecimal Nothing
        , FieldDef "Bonus" FT_BigDecimal Nothing
        , FieldDef "Deductions" FT_BigDecimal Nothing
        , FieldDef "NetSalary" FT_BigDecimal Nothing
        ]
    , rdGroups = []
    }

-- ============================================================================
-- BANKING REPORTS
-- ============================================================================

-- | Payment order (Платежное поручение)
paymentOrderReport :: ReportDef
paymentOrderReport = ReportDef
    { rdName = "PaymentOrder"
    , rdTitle = "Payment Order / Платежное поручение"
    , rdCategory = RC_Banking
    , rdDescription = "Bank payment order"
    , rdJrxml = generateJRXML paymentOrderReport
    , rdSql = T.unlines
        [ "SELECT po.doc_num as DocNum, po.dt as DocDate,"
        , "       po.payer_name as Payer, po.payer_bank as PayerBank,"
        , "       po.receiver_name as Receiver, po.receiver_bank as ReceiverBank,"
        , "       po.amount as Amount, po.purpose as Purpose"
        , "FROM paym_order po"
        , "WHERE po.id = $P{PaymentOrderID}"
        ]
    , rdParams =
        [ ParamDef "PaymentOrderID" PT_Int "Payment Order ID" True Nothing
        ]
    , rdFields =
        [ FieldDef "DocNum" FT_String Nothing
        , FieldDef "DocDate" FT_Date Nothing
        , FieldDef "Payer" FT_String Nothing
        , FieldDef "PayerBank" FT_String Nothing
        , FieldDef "Receiver" FT_String Nothing
        , FieldDef "ReceiverBank" FT_String Nothing
        , FieldDef "Amount" FT_BigDecimal Nothing
        , FieldDef "Purpose" FT_String Nothing
        ]
    , rdGroups = []
    }

-- | Cash book (Кассовая книга)
cashBookReport :: ReportDef
cashBookReport = ReportDef
    { rdName = "CashBook"
    , rdTitle = "Cash Book / Кассовая книга"
    , rdCategory = RC_Banking
    , rdDescription = "Cash transactions register"
    , rdJrxml = generateJRXML cashBookReport
    , rdSql = T.unlines
        [ "SELECT cs.dt as Date, cs.doc_num as DocNum,"
        , "       op.name as OpName, cs.income as Income, cs.outcome as Outcome,"
        , "       (SELECT SUM(income) - SUM(outcome) FROM cash_sess"
        , "        WHERE dt <= cs.dt AND cash_node_id = cs.cash_node_id) as Balance"
        , "FROM cash_sess cs"
        , "JOIN op_kind ok ON ok.id = cs.op_kind_id"
        , "JOIN op_type op ON op.id = ok.op_type_id"
        , "WHERE cs.cash_node_id = $P{CashNodeID}"
        , "  AND cs.dt BETWEEN $P{StartDate} AND $P{EndDate}"
        , "ORDER BY cs.dt, cs.id"
        ]
    , rdParams =
        [ ParamDef "CashNodeID" PT_Int "Cash Node" True Nothing
        , ParamDef "StartDate" PT_Date "Start Date" True Nothing
        , ParamDef "EndDate" PT_Date "End Date" True Nothing
        ]
    , rdFields =
        [ FieldDef "Date" FT_Date Nothing
        , FieldDef "DocNum" FT_String Nothing
        , FieldDef "OpName" FT_String Nothing
        , FieldDef "Income" FT_BigDecimal Nothing
        , FieldDef "Outcome" FT_BigDecimal Nothing
        , FieldDef "Balance" FT_BigDecimal Nothing
        ]
    , rdGroups = []
    }

-- ============================================================================
-- TAX REPORTS
-- ============================================================================

-- | VAT book buy (Книга покупок)
vatBookBuyReport :: ReportDef
vatBookBuyReport = ReportDef
    { rdName = "VATBookBuy"
    , rdTitle = "VAT Purchase Book / Книга покупок"
    , rdCategory = RC_Tax
    , rdDescription = "VAT input register"
    , rdJrxml = generateJRXML vatBookBuyReport
    , rdSql = T.unlines
        [ "SELECT b.dt as RegDate, b.code as InvoiceNum,"
        , "       p.name as SellerName, p.inn as SellerINN,"
        , "       b.total as Total, b.tax as VAT"
        , "FROM bill b"
        , "JOIN person p ON p.id = b.person_id"
        , "WHERE b.bill_type_id IN (SELECT id FROM bill_type WHERE is_purchase = TRUE)"
        , "  AND b.dt BETWEEN $P{StartDate} AND $P{EndDate}"
        , "  AND b.status = 'POSTED'"
        , "ORDER BY b.dt"
        ]
    , rdParams =
        [ ParamDef "StartDate" PT_Date "Start Date" True Nothing
        , ParamDef "EndDate" PT_Date "End Date" True Nothing
        ]
    , rdFields =
        [ FieldDef "RegDate" FT_Date Nothing
        , FieldDef "InvoiceNum" FT_String Nothing
        , FieldDef "SellerName" FT_String Nothing
        , FieldDef "SellerINN" FT_String Nothing
        , FieldDef "Total" FT_BigDecimal Nothing
        , FieldDef "VAT" FT_BigDecimal Nothing
        ]
    , rdGroups = []
    }

-- | VAT book sell (Книга продаж)
vatBookSellReport :: ReportDef
vatBookSellReport = ReportDef
    { rdName = "VATBookSell"
    , rdTitle = "VAT Sales Book / Книга продаж"
    , rdCategory = RC_Tax
    , rdDescription = "VAT output register"
    , rdJrxml = generateJRXML vatBookSellReport
    , rdSql = T.unlines
        [ "SELECT b.dt as RegDate, b.code as InvoiceNum,"
        , "       p.name as BuyerName, p.inn as BuyerINN,"
        , "       b.total as Total, b.tax as VAT"
        , "FROM bill b"
        , "JOIN person p ON p.id = b.person_id"
        , "WHERE b.bill_type_id IN (SELECT id FROM bill_type WHERE is_sale = TRUE)"
        , "  AND b.dt BETWEEN $P{StartDate} AND $P{EndDate}"
        , "  AND b.status = 'POSTED'"
        , "ORDER BY b.dt"
        ]
    , rdParams =
        [ ParamDef "StartDate" PT_Date "Start Date" True Nothing
        , ParamDef "EndDate" PT_Date "End Date" True Nothing
        ]
    , rdFields =
        [ FieldDef "RegDate" FT_Date Nothing
        , FieldDef "InvoiceNum" FT_String Nothing
        , FieldDef "BuyerName" FT_String Nothing
        , FieldDef "BuyerINN" FT_String Nothing
        , FieldDef "Total" FT_BigDecimal Nothing
        , FieldDef "VAT" FT_BigDecimal Nothing
        ]
    , rdGroups = []
    }

-- ============================================================================
-- PERSONS REPORTS
-- ============================================================================

-- | Person list (Список контрагентов)
personListReport :: ReportDef
personListReport = ReportDef
    { rdName = "PersonList"
    , rdTitle = "Counteragents List / Список контрагентов"
    , rdCategory = RC_Persons
    , rdDescription = "All persons directory"
    , rdJrxml = generateJRXML personListReport
    , rdSql = T.unlines
        [ "SELECT p.code as Code, p.name as Name, pk.name as Kind,"
        , "       p.inn as INN, p.kpp as KPP, p.phone as Phone, p.email as Email"
        , "FROM person p"
        , "JOIN person_kind pk ON pk.id = p.person_kind_id"
        , "WHERE p.status = 'ACTIVE'"
        , "ORDER BY p.name"
        ]
    , rdParams =
        [ ParamDef "PersonKindID" PT_List "Kind" False (Just "0")
        ]
    , rdFields =
        [ FieldDef "Code" FT_String Nothing
        , FieldDef "Name" FT_String Nothing
        , FieldDef "Kind" FT_String Nothing
        , FieldDef "INN" FT_String Nothing
        , FieldDef "KPP" FT_String Nothing
        , FieldDef "Phone" FT_String Nothing
        , FieldDef "Email" FT_String Nothing
        ]
    , rdGroups = [GroupDef "ByKind" "Kind" True]
    }

-- ============================================================================
-- ANALYTICS REPORTS
-- ============================================================================

-- | Sales turnover (Обороты продаж)
salesTurnoverReport :: ReportDef
salesTurnoverReport = ReportDef
    { rdName = "SalesTurnover"
    , rdTitle = "Sales Turnover / Обороты продаж"
    , rdCategory = RC_Analytics
    , rdDescription = "Sales analysis by goods"
    , rdJrxml = generateJRXML salesTurnoverReport
    , rdSql = T.unlines
        [ "SELECT g.code as GoodsCode, g.name as GoodsName,"
        , "       gg.name as GroupName,"
        , "       SUM(bl.qty) as TotalQty,"
        , "       SUM(bl.qty * bl.price) as TotalSum"
        , "FROM bill b"
        , "JOIN bill_line bl ON bl.bill_id = b.id"
        , "JOIN goods g ON g.id = bl.goods_id"
        , "LEFT JOIN goods_group gg ON gg.id = g.parent_id"
        , "WHERE b.bill_type_id IN (SELECT id FROM bill_type WHERE is_sale = TRUE)"
        , "  AND b.dt BETWEEN $P{StartDate} AND $P{EndDate}"
        , "  AND b.status = 'POSTED'"
        , "GROUP BY g.id, g.code, g.name, gg.name"
        , "HAVING SUM(bl.qty * bl.price) > 0"
        , "ORDER BY TotalSum DESC"
        ]
    , rdParams =
        [ ParamDef "StartDate" PT_Date "Start Date" True Nothing
        , ParamDef "EndDate" PT_Date "End Date" True Nothing
        ]
    , rdFields =
        [ FieldDef "GoodsCode" FT_String Nothing
        , FieldDef "GoodsName" FT_String Nothing
        , FieldDef "GroupName" FT_String Nothing
        , FieldDef "TotalQty" FT_Double Nothing
        , FieldDef "TotalSum" FT_BigDecimal Nothing
        ]
    , rdGroups = [GroupDef "ByGroup" "GroupName" True]
    }

-- ============================================================================
-- REPORT REGISTRY
-- ============================================================================

-- | All available reports
allReports :: Map Text ReportDef
allReports = Map.fromList
    [ ("Balance", balanceReport)
    , ("AccountTurnover", accountTurnoverReport)
    , ("AccEntryList", accountingEntryList)
    , ("GoodsRest", goodsRestReport)
    , ("GoodsMovement", goodsMovementReport)
    , ("Inventory", inventoryReport)
    , ("BillList", billListReport)
    , ("GoodsBill", goodsBillReport)
    , ("Invoice", invoiceReport)
    , ("Salary", salaryReport)
    , ("PaymentOrder", paymentOrderReport)
    , ("CashBook", cashBookReport)
    , ("VATBookBuy", vatBookBuyReport)
    , ("VATBookSell", vatBookSellReport)
    , ("PersonList", personListReport)
    , ("SalesTurnover", salesTurnoverReport)
    ]

-- | Get report by name
getReport :: Text -> Maybe ReportDef
getReport name = Map.lookup name allReports

-- | Get reports by category
getReportsByCategory :: ReportCategory -> [ReportDef]
getReportsByCategory cat = filter (\r -> rdCategory r == cat) (Map.elems allReports)

-- ============================================================================
-- EXPORT FUNCTIONS
-- ============================================================================

-- | Export single report JRXML
exportReportJRXML :: Text -> IO (Maybe Text)
exportReportJRXML name = case getReport name of
    Just r  -> pure (Just (rdJrxml r))
    Nothing -> pure Nothing

-- | Export all reports to directory
exportAllReports :: FilePath -> IO ()
exportAllReports dir = mapM_ exportOne (Map.toList allReports)
    where
        exportOne (name, r) = writeFile (dir <> "/" <> T.unpack name <> ".jrxml") (T.unpack (rdJrxml r))
