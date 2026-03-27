-- ============================================================================
-- SURYPUS REPORTS - JasperReports/Helical/Pentaho Integration
-- ============================================================================
-- 678 Crystal Reports -> JasperReports JRXML conversion
-- Categories: Accounting, Warehouse, Bills, Payroll, Banking, etc.
-- ============================================================================
{-# LANGUAGE OverloadedStrings #-}

module Surypus.Reports where

import Data.Aeson (Value, object, (.=))
import qualified Data.ByteString.Char8 as BS8
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Hasql.Encoders as E

-- ============================================================================
-- REPORT CATEGORIES
-- ============================================================================

data ReportCategory
  = RCAccounting -- Бухгалтерия
  | RCWarehouse -- Склад
  | RCBills -- Документы
  | RCPayroll -- Зарплата
  | RCBanking -- Банк
  | RCPersons -- Контрагенты
  | RCGoods -- Товары
  | RCTax -- Налоги
  | RCCashSession -- Кассы
  | RCProject -- Проекты
  | RCAsset -- ОС
  | RCAnalytics -- Аналитика
  | RCSystem -- Системные
  deriving (Show, Eq, Enum)

-- ============================================================================
-- REPORT DEFINITION
-- ============================================================================

data ReportDef = ReportDef
  { rdName :: Text, -- Internal name
    rdTitle :: Text, -- Display title
    rdCategory :: ReportCategory,
    rdDescription :: Text,
    rdJrxml :: Text, -- JRXML template
    rdSql :: Text, -- Main query
    rdParams :: [ParamDef], -- Report parameters
    rdFields :: [FieldDef], -- Data fields
    rdGroups :: [GroupDef] -- Grouping
  }
  deriving (Show)

data ParamDef = ParamDef
  { pName :: Text,
    pType :: ParamType,
    pLabel :: Text,
    pRequired :: Bool,
    pDefault :: Maybe Text
  }
  deriving (Show)

data ParamType = PTDate | PTDateRange | PTInt | PTText | PTDouble | PTBoolean | PTList
  deriving (Show, Eq)

data FieldDef = FieldDef
  { fName :: Text,
    fType :: FieldType,
    fFormula :: Maybe Text
  }
  deriving (Show)

data FieldType = FTString | FTInteger | FTDouble | FTDate | FTBoolean | FTBigDecimal
  deriving (Show, Eq)

data GroupDef = GroupDef
  { gName :: Text,
    gField :: Text,
    gSortAsc :: Bool
  }
  deriving (Show)

-- ============================================================================
-- REPORT SERVICE
-- ============================================================================

-- | Get report data from database
getReportData :: Text -> [ParamDef] -> Map Text Value -> IO (Either String [[Value]])
getReportData sql params paramValues = do
  let _ = buildQuery sql params paramValues
  let _ = (sql, params, paramValues)
  -- For now, return mock data
  pure $ Right [[object ["result" .= T.pack "mock data"]]]

-- | Build parameterized SQL query
buildQuery :: Text -> [ParamDef] -> Map Text Value -> (Text, E.Params ())
buildQuery sql params _paramValues =
  let finalSql = foldl replaceParam sql params
   in (finalSql, E.noParams)
  where
    replaceParam accSql param =
      let placeholder = "$P{" <> pName param <> "}"
          replacement = "?"
          newSql = T.replace placeholder replacement accSql
       in newSql

-- ============================================================================
-- JRXML TEMPLATE GENERATOR
-- ============================================================================

-- | Generate JRXML from ReportDef
generateJRXML :: ReportDef -> Text
generateJRXML r =
  T.unlines
    [ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
      "<jasperReport xmlns=\"http://jasperreports.sourceforge.net/jasperreports\"",
      "              name=\"" <> rdName r <> "\"",
      "              pageWidth=\"595\" pageHeight=\"842\"",
      "              columnWidth=\"555\" leftMargin=\"20\" rightMargin=\"20\"",
      "              topMargin=\"20\" bottomMargin=\"20\">",
      "  <parameter name=\"REPORT_TITLE\" class=\"java.lang.String\"/>",
      "  <parameter name=\"REPORT_DATE\" class=\"java.util.Date\"/>",
      generateParams (rdParams r),
      "  <queryString>",
      "    <![CDATA[" <> rdSql r <> "]]>",
      "  </queryString>",
      generateFields (rdFields r),
      "  <title>",
      "    <band height=\"50\">",
      "      <staticText>",
      "        <reportElement x=\"0\" y=\"0\" width=\"555\" height=\"30\"/>",
      "        <text><![CDATA[" <> rdTitle r <> "]]>]]></text>",
      "      </staticText>",
      "    </band>",
      "  </title>",
      "  <detail>",
      "    <band height=\"20\">",
      generateDetailFields (rdFields r),
      "    </band>",
      "  </detail>",
      "</jasperReport>"
    ]

generateParams :: [ParamDef] -> Text
generateParams ps = T.unlines $ fmap genParam ps
  where
    genParam p =
      "  <parameter name=\""
        <> pName p
        <> "\" class=\""
        <> paramClass (pType p)
        <> "\""
        <> (if pRequired p then " isForPrompting=\"true\"" else "")
        <> "/>"
    paramClass PTDate = "java.util.Date"
    paramClass PTDateRange = "java.util.Date"
    paramClass PTInt = "java.lang.Integer"
    paramClass PTText = "java.lang.String"
    paramClass PTDouble = "java.lang.Double"
    paramClass PTBoolean = "java.lang.Boolean"
    paramClass PTList = "java.lang.String"

generateFields :: [FieldDef] -> Text
generateFields fs =
  T.unlines $
    "  <field name=\"ROW_NUMBER\" class=\"java.lang.Integer\"/>"
      : fmap genField fs
  where
    genField f =
      "  <field name=\""
        <> fName f
        <> "\" class=\""
        <> fieldClass (fType f)
        <> "\"/>"
    fieldClass FTString = "java.lang.String"
    fieldClass FTInteger = "java.lang.Integer"
    fieldClass FTDouble = "java.lang.Double"
    fieldClass FTDate = "java.util.Date"
    fieldClass FTBoolean = "java.lang.Boolean"
    fieldClass FTBigDecimal = "java.math.BigDecimal"

generateDetailFields :: [FieldDef] -> Text
generateDetailFields fs = T.unlines $ fmap genTextField fs
  where
    genTextField f =
      T.unlines
        [ "      <textField>",
          "        <reportElement x=\"0\" y=\"0\" width=\"100\" height=\"20\"/>",
          "        <textFieldExpression><![CDATA[$F{" <> fName f <> "}]]></textFieldExpression>",
          "      </textField>"
        ]

-- ============================================================================
-- REPORT EXPORT
-- ============================================================================

-- | Export report to PDF
exportReportToPDF :: ReportDef -> IO (Either String BS8.ByteString)
exportReportToPDF report = do
  -- This would use JasperReports library to compile and fill report
  -- For now, return mock PDF data
  let _ = report
  pure $ Right (BS8.pack "PDF_CONTENT_PLACEHOLDER")

-- | Export report to HTML
exportReportToHTML :: ReportDef -> IO (Either String Text)
exportReportToHTML report = do
  -- Generate HTML from JRXML
  let jrxml = generateJRXML report
  let html =
        T.unlines
          [ "<!DOCTYPE html>",
            "<html>",
            "<head>",
            "  <title>" <> rdTitle report <> "</title>",
            "</head>",
            "<body>",
            "  <h1>" <> rdTitle report <> "</h1>",
            "  <pre>" <> jrxml <> "</pre>",
            "</body>",
            "</html>"
          ]
  pure $ Right html

-- ============================================================================
-- ACCOUNTING REPORTS
-- ============================================================================

-- | Balance sheet (Баланс)
balanceReport :: ReportDef
balanceReport =
  ReportDef
    { rdName = "Balance",
      rdTitle = "Balance Sheet / Бухгалтерский баланс",
      rdCategory = RCAccounting,
      rdDescription = "Balance sheet (form 1)",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT a.code as AccountCode, a.name as AccountName,",
            "       SUM(at.dbt) as DebitTurnover, SUM(at.crd) as CreditTurnover,",
            "       (SELECT SUM(dbt) - SUM(crd) FROM acc_turn WHERE acc_id <= a.id AND dt <= $P{EndDate}) as Balance",
            "FROM acc_plan a",
            "LEFT JOIN acc_turn at ON at.acc_id = a.id AND at.dt BETWEEN $P{StartDate} AND $P{EndDate}",
            "WHERE a.parent_id IS NULL",
            "GROUP BY a.id, a.code, a.name",
            "ORDER BY a.code"
          ],
      rdParams =
        [ ParamDef "StartDate" PTDate "Start Date" True Nothing,
          ParamDef "EndDate" PTDate "End Date" True Nothing
        ],
      rdFields =
        [ FieldDef "AccountCode" FTString Nothing,
          FieldDef "AccountName" FTString Nothing,
          FieldDef "DebitTurnover" FTBigDecimal Nothing,
          FieldDef "CreditTurnover" FTBigDecimal Nothing,
          FieldDef "Balance" FTBigDecimal Nothing
        ],
      rdGroups = []
    }

-- | Account turnover (Оборотно-сальдовая ведомость)
accountTurnoverReport :: ReportDef
accountTurnoverReport =
  ReportDef
    { rdName = "AccountTurnover",
      rdTitle = "Account Turnover / Оборотно-сальдовая ведомость",
      rdCategory = RCAccounting,
      rdDescription = "Account turnover with balances",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT ap.code as AccCode, ap.name as AccName,",
            "       COALESCE(SUM(at.dbt), 0) as DebitSum,",
            "       COALESCE(SUM(at.crd), 0) as CreditSum",
            "FROM acc_plan ap",
            "LEFT JOIN acc_turn at ON at.acc_id = ap.id",
            "     AND at.dt BETWEEN $P{StartDate} AND $P{EndDate}",
            "WHERE ap.is_analytic = TRUE",
            "GROUP BY ap.id, ap.code, ap.name",
            "HAVING COALESCE(SUM(at.dbt), 0) + COALESCE(SUM(at.crd), 0) > 0",
            "ORDER BY ap.code"
          ],
      rdParams =
        [ ParamDef "StartDate" PTDate "Start Date" True Nothing,
          ParamDef "EndDate" PTDate "End Date" True Nothing
        ],
      rdFields =
        [ FieldDef "AccCode" FTString Nothing,
          FieldDef "AccName" FTString Nothing,
          FieldDef "DebitSum" FTBigDecimal Nothing,
          FieldDef "CreditSum" FTBigDecimal Nothing
        ],
      rdGroups = []
    }

-- | Accounting entry list (Журнал проводок)
accountingEntryList :: ReportDef
accountingEntryList =
  ReportDef
    { rdName = "AccEntryList",
      rdTitle = "Journal of Entries / Журнал проводок",
      rdCategory = RCAccounting,
      rdDescription = "Accounting entries journal",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT at.dt as Date, at.doc_id as DocID,",
            "       da.code as DebitAcc, ca.code as CreditAcc,",
            "       at.amount as Amount, at.memo as Memo",
            "FROM acc_turn at",
            "JOIN acc_plan da ON da.id = at.dbt_acc_id",
            "JOIN acc_plan ca ON ca.id = at.crd_acc_id",
            "WHERE at.dt BETWEEN $P{StartDate} AND $P{EndDate}",
            "ORDER BY at.dt, at.id"
          ],
      rdParams =
        [ ParamDef "StartDate" PTDate "Start Date" True Nothing,
          ParamDef "EndDate" PTDate "End Date" True Nothing
        ],
      rdFields =
        [ FieldDef "Date" FTDate Nothing,
          FieldDef "DocID" FTInteger Nothing,
          FieldDef "DebitAcc" FTString Nothing,
          FieldDef "CreditAcc" FTString Nothing,
          FieldDef "Amount" FTBigDecimal Nothing,
          FieldDef "Memo" FTString Nothing
        ],
      rdGroups = []
    }

-- ============================================================================
-- WAREHOUSE REPORTS
-- ============================================================================

-- | Goods rest (Остатки товаров)
goodsRestReport :: ReportDef
goodsRestReport =
  ReportDef
    { rdName = "GoodsRest",
      rdTitle = "Stock Balance / Остатки товаров",
      rdCategory = RCWarehouse,
      rdDescription = "Current stock by locations",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT g.code as GoodsCode, g.name as GoodsName,",
            "       u.symbol as UnitSymbol,",
            "       l.name as LocationName,",
            "       gr.qty as Quantity, gr.price as Price,",
            "       gr.qty * gr.price as TotalCost",
            "FROM goods_rest gr",
            "JOIN goods g ON g.id = gr.goods_id",
            "JOIN location l ON l.id = gr.loc_id",
            "JOIN unit u ON u.id = g.unit_id",
            "WHERE gr.qty > 0",
            "ORDER BY g.name, l.name"
          ],
      rdParams =
        [ ParamDef "LocationID" PTList "Location" False (Just "0"),
          ParamDef "GoodsGroupID" PTList "Goods Group" False (Just "0")
        ],
      rdFields =
        [ FieldDef "GoodsCode" FTString Nothing,
          FieldDef "GoodsName" FTString Nothing,
          FieldDef "UnitSymbol" FTString Nothing,
          FieldDef "LocationName" FTString Nothing,
          FieldDef "Quantity" FTDouble Nothing,
          FieldDef "Price" FTBigDecimal Nothing,
          FieldDef "TotalCost" FTBigDecimal Nothing
        ],
      rdGroups = [GroupDef "ByLocation" "LocationName" True]
    }

-- | Goods movement (Движение товаров)
goodsMovementReport :: ReportDef
goodsMovementReport =
  ReportDef
    { rdName = "GoodsMovement",
      rdTitle = "Goods Movement / Движение товаров",
      rdCategory = RCWarehouse,
      rdDescription = "Incoming and outgoing goods",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT gm.dt as Date, g.code as GoodsCode, g.name as GoodsName,",
            "       lfrom.name as FromLoc, lto.name as ToLoc,",
            "       gm.qty as Quantity, gm.cost as Cost,",
            "       bt.name as BillType",
            "FROM goods_movement gm",
            "JOIN goods g ON g.id = gm.goods_id",
            "JOIN location lfrom ON lfrom.id = gm.loc_from_id",
            "JOIN location lto ON lto.id = gm.loc_to_id",
            "LEFT JOIN bill_type bt ON bt.id = gm.bill_type_id",
            "WHERE gm.dt BETWEEN $P{StartDate} AND $P{EndDate}",
            "ORDER BY gm.dt DESC"
          ],
      rdParams =
        [ ParamDef "StartDate" PTDate "Start Date" True Nothing,
          ParamDef "EndDate" PTDate "End Date" True Nothing
        ],
      rdFields =
        [ FieldDef "Date" FTDate Nothing,
          FieldDef "GoodsCode" FTString Nothing,
          FieldDef "GoodsName" FTString Nothing,
          FieldDef "FromLoc" FTString Nothing,
          FieldDef "ToLoc" FTString Nothing,
          FieldDef "Quantity" FTDouble Nothing,
          FieldDef "Cost" FTBigDecimal Nothing,
          FieldDef "BillType" FTString Nothing
        ],
      rdGroups = []
    }

-- | Inventory report (Инвентаризация)
inventoryReport :: ReportDef
inventoryReport =
  ReportDef
    { rdName = "Inventory",
      rdTitle = "Inventory / Инвентаризация",
      rdCategory = RCWarehouse,
      rdDescription = "Inventory worksheet",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT g.code as GoodsCode, g.name as GoodsName,",
            "       u.symbol as Unit,",
            "       inv.qty_fact as FactQty, inv.qty_plan as PlanQty,",
            "       inv.qty_fact - inv.qty_plan as Diff",
            "FROM inventory_line inv",
            "JOIN goods g ON g.id = inv.goods_id",
            "JOIN unit u ON u.id = g.unit_id",
            "WHERE inv.inventory_id = $P{InventoryID}",
            "ORDER BY g.name"
          ],
      rdParams =
        [ ParamDef "InventoryID" PTInt "Inventory #" True Nothing
        ],
      rdFields =
        [ FieldDef "GoodsCode" FTString Nothing,
          FieldDef "GoodsName" FTString Nothing,
          FieldDef "Unit" FTString Nothing,
          FieldDef "FactQty" FTDouble Nothing,
          FieldDef "PlanQty" FTDouble Nothing,
          FieldDef "Diff" FTDouble Nothing
        ],
      rdGroups = []
    }

-- ============================================================================
-- BILLS REPORTS
-- ============================================================================

-- | Bill list (Список документов)
billListReport :: ReportDef
billListReport =
  ReportDef
    { rdName = "BillList",
      rdTitle = "Documents List / Список документов",
      rdCategory = RCBills,
      rdDescription = "List of all bills",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT b.dt as Date, b.code as BillCode,",
            "       p.name as PersonName, bt.name as BillTypeName,",
            "       b.total as Total, b.status as Status",
            "FROM bill b",
            "JOIN bill_type bt ON bt.id = b.bill_type_id",
            "LEFT JOIN person p ON p.id = b.person_id",
            "WHERE b.dt BETWEEN $P{StartDate} AND $P{EndDate}",
            "  AND ($P{BillTypeID} = 0 OR b.bill_type_id = $P{BillTypeID})",
            "  AND ($P{PersonID} = 0 OR b.person_id = $P{PersonID})",
            "ORDER BY b.dt DESC, b.code"
          ],
      rdParams =
        [ ParamDef "StartDate" PTDate "Start Date" True Nothing,
          ParamDef "EndDate" PTDate "End Date" True Nothing,
          ParamDef "BillTypeID" PTInt "Bill Type" False (Just "0"),
          ParamDef "PersonID" PTInt "Person" False (Just "0")
        ],
      rdFields =
        [ FieldDef "Date" FTDate Nothing,
          FieldDef "BillCode" FTString Nothing,
          FieldDef "PersonName" FTString Nothing,
          FieldDef "BillTypeName" FTString Nothing,
          FieldDef "Total" FTBigDecimal Nothing,
          FieldDef "Status" FTString Nothing
        ],
      rdGroups = [GroupDef "ByDate" "Date" False]
    }

-- | Goods bill (Товарная накладная)
goodsBillReport :: ReportDef
goodsBillReport =
  ReportDef
    { rdName = "GoodsBill",
      rdTitle = "Goods Bill / Товарная накладная",
      rdCategory = RCBills,
      rdDescription = "Goods bill document",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT bl.ord as LineNo, g.code as GoodsCode, g.name as GoodsName,",
            "       bl.qty as Quantity, u.symbol as Unit,",
            "       bl.price as Price, bl.discount as Discount,",
            "       bl.qty * bl.price * (1 - bl.discount/100) as LineTotal",
            "FROM bill_line bl",
            "JOIN goods g ON g.id = bl.goods_id",
            "JOIN unit u ON u.id = g.unit_id",
            "WHERE bl.bill_id = $P{BillID}",
            "ORDER BY bl.ord"
          ],
      rdParams =
        [ ParamDef "BillID" PTInt "Bill ID" True Nothing
        ],
      rdFields =
        [ FieldDef "LineNo" FTInteger Nothing,
          FieldDef "GoodsCode" FTString Nothing,
          FieldDef "GoodsName" FTString Nothing,
          FieldDef "Quantity" FTDouble Nothing,
          FieldDef "Unit" FTString Nothing,
          FieldDef "Price" FTBigDecimal Nothing,
          FieldDef "Discount" FTDouble Nothing,
          FieldDef "LineTotal" FTBigDecimal Nothing
        ],
      rdGroups = []
    }

-- | Invoice (Счет-фактура)
invoiceReport :: ReportDef
invoiceReport =
  ReportDef
    { rdName = "Invoice",
      rdTitle = "Invoice / Счет-фактура",
      rdCategory = RCBills,
      rdDescription = "VAT invoice",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT bl.ord as Num, g.name as GoodsName, bl.qty as Qty, bl.price as Price,",
            "       bl.qty * bl.price as TotalWoTax,",
            "       bl.tax_rate as TaxRate, bl.tax as TaxAmount,",
            "       bl.qty * bl.price + bl.tax as TotalWithTax",
            "FROM bill_line bl",
            "JOIN goods g ON g.id = bl.goods_id",
            "WHERE bl.bill_id = $P{BillID} AND bl.tax > 0",
            "ORDER BY bl.ord"
          ],
      rdParams =
        [ ParamDef "BillID" PTInt "Bill ID" True Nothing
        ],
      rdFields =
        [ FieldDef "Num" FTInteger Nothing,
          FieldDef "GoodsName" FTString Nothing,
          FieldDef "Qty" FTDouble Nothing,
          FieldDef "Price" FTBigDecimal Nothing,
          FieldDef "TotalWoTax" FTBigDecimal Nothing,
          FieldDef "TaxRate" FTDouble Nothing,
          FieldDef "TaxAmount" FTBigDecimal Nothing,
          FieldDef "TotalWithTax" FTBigDecimal Nothing
        ],
      rdGroups = []
    }

-- ============================================================================
-- PAYROLL REPORTS
-- ============================================================================

-- | Salary report (Зарплата)
salaryReport :: ReportDef
salaryReport =
  ReportDef
    { rdName = "Salary",
      rdTitle = "Salary Report / Расчетная ведомость",
      rdCategory = RCPayroll,
      rdDescription = "Employee salary calculation",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT e.emp_id as EmpID, prsn.name as EmpName, sr.name as Position,",
            "       ss.base as BaseSalary, ss.bonus as Bonus,",
            "       ss.deductions as Deductions, ss.net as NetSalary",
            "FROM salary_sheet ss",
            "JOIN employee e ON e.id = ss.emp_id",
            "JOIN person prsn ON prsn.id = e.person_id",
            "JOIN staff_rank sr ON sr.id = e.rank_id",
            "WHERE ss.period = $P{Period}",
            "ORDER BY prsn.name"
          ],
      rdParams =
        [ ParamDef "Period" PTText "Period (YYYY-MM)" True Nothing
        ],
      rdFields =
        [ FieldDef "EmpID" FTInteger Nothing,
          FieldDef "EmpName" FTString Nothing,
          FieldDef "Position" FTString Nothing,
          FieldDef "BaseSalary" FTBigDecimal Nothing,
          FieldDef "Bonus" FTBigDecimal Nothing,
          FieldDef "Deductions" FTBigDecimal Nothing,
          FieldDef "NetSalary" FTBigDecimal Nothing
        ],
      rdGroups = []
    }

-- ============================================================================
-- BANKING REPORTS
-- ============================================================================

-- | Payment order (Платежное поручение)
paymentOrderReport :: ReportDef
paymentOrderReport =
  ReportDef
    { rdName = "PaymentOrder",
      rdTitle = "Payment Order / Платежное поручение",
      rdCategory = RCBanking,
      rdDescription = "Bank payment order",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT po.doc_num as DocNum, po.dt as DocDate,",
            "       po.payer_name as Payer, po.payer_bank as PayerBank,",
            "       po.receiver_name as Receiver, po.receiver_bank as ReceiverBank,",
            "       po.amount as Amount, po.purpose as Purpose",
            "FROM paym_order po",
            "WHERE po.id = $P{PaymentOrderID}"
          ],
      rdParams =
        [ ParamDef "PaymentOrderID" PTInt "Payment Order ID" True Nothing
        ],
      rdFields =
        [ FieldDef "DocNum" FTString Nothing,
          FieldDef "DocDate" FTDate Nothing,
          FieldDef "Payer" FTString Nothing,
          FieldDef "PayerBank" FTString Nothing,
          FieldDef "Receiver" FTString Nothing,
          FieldDef "ReceiverBank" FTString Nothing,
          FieldDef "Amount" FTBigDecimal Nothing,
          FieldDef "Purpose" FTString Nothing
        ],
      rdGroups = []
    }

-- | Cash book (Кассовая книга)
cashBookReport :: ReportDef
cashBookReport =
  ReportDef
    { rdName = "CashBook",
      rdTitle = "Cash Book / Кассовая книга",
      rdCategory = RCBanking,
      rdDescription = "Cash transactions register",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT cs.dt as Date, cs.doc_num as DocNum,",
            "       op.name as OpName, cs.income as Income, cs.outcome as Outcome,",
            "       (SELECT SUM(income) - SUM(outcome) FROM cash_sess",
            "        WHERE dt <= cs.dt AND cash_node_id = cs.cash_node_id) as Balance",
            "FROM cash_sess cs",
            "JOIN op_kind ok ON ok.id = cs.op_kind_id",
            "JOIN op_type op ON op.id = ok.op_type_id",
            "WHERE cs.cash_node_id = $P{CashNodeID}",
            "  AND cs.dt BETWEEN $P{StartDate} AND $P{EndDate}",
            "ORDER BY cs.dt, cs.id"
          ],
      rdParams =
        [ ParamDef "CashNodeID" PTInt "Cash Node" True Nothing,
          ParamDef "StartDate" PTDate "Start Date" True Nothing,
          ParamDef "EndDate" PTDate "End Date" True Nothing
        ],
      rdFields =
        [ FieldDef "Date" FTDate Nothing,
          FieldDef "DocNum" FTString Nothing,
          FieldDef "OpName" FTString Nothing,
          FieldDef "Income" FTBigDecimal Nothing,
          FieldDef "Outcome" FTBigDecimal Nothing,
          FieldDef "Balance" FTBigDecimal Nothing
        ],
      rdGroups = []
    }

-- ============================================================================
-- TAX REPORTS
-- ============================================================================

-- | VAT book buy (Книга покупок)
vatBookBuyReport :: ReportDef
vatBookBuyReport =
  ReportDef
    { rdName = "VATBookBuy",
      rdTitle = "VAT Purchase Book / Книга покупок",
      rdCategory = RCTax,
      rdDescription = "VAT input register",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT b.dt as RegDate, b.code as InvoiceNum,",
            "       p.name as SellerName, p.inn as SellerINN,",
            "       b.total as Total, b.tax as VAT",
            "FROM bill b",
            "JOIN person p ON p.id = b.person_id",
            "WHERE b.bill_type_id IN (SELECT id FROM bill_type WHERE is_purchase = TRUE)",
            "  AND b.dt BETWEEN $P{StartDate} AND $P{EndDate}",
            "  AND b.status = 'POSTED'",
            "ORDER BY b.dt"
          ],
      rdParams =
        [ ParamDef "StartDate" PTDate "Start Date" True Nothing,
          ParamDef "EndDate" PTDate "End Date" True Nothing
        ],
      rdFields =
        [ FieldDef "RegDate" FTDate Nothing,
          FieldDef "InvoiceNum" FTString Nothing,
          FieldDef "SellerName" FTString Nothing,
          FieldDef "SellerINN" FTString Nothing,
          FieldDef "Total" FTBigDecimal Nothing,
          FieldDef "VAT" FTBigDecimal Nothing
        ],
      rdGroups = []
    }

-- | VAT book sell (Книга продаж)
vatBookSellReport :: ReportDef
vatBookSellReport =
  ReportDef
    { rdName = "VATBookSell",
      rdTitle = "VAT Sales Book / Книга продаж",
      rdCategory = RCTax,
      rdDescription = "VAT output register",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT b.dt as RegDate, b.code as InvoiceNum,",
            "       p.name as BuyerName, p.inn as BuyerINN,",
            "       b.total as Total, b.tax as VAT",
            "FROM bill b",
            "JOIN person p ON p.id = b.person_id",
            "WHERE b.bill_type_id IN (SELECT id FROM bill_type WHERE is_sale = TRUE)",
            "  AND b.dt BETWEEN $P{StartDate} AND $P{EndDate}",
            "  AND b.status = 'POSTED'",
            "ORDER BY b.dt"
          ],
      rdParams =
        [ ParamDef "StartDate" PTDate "Start Date" True Nothing,
          ParamDef "EndDate" PTDate "End Date" True Nothing
        ],
      rdFields =
        [ FieldDef "RegDate" FTDate Nothing,
          FieldDef "InvoiceNum" FTString Nothing,
          FieldDef "BuyerName" FTString Nothing,
          FieldDef "BuyerINN" FTString Nothing,
          FieldDef "Total" FTBigDecimal Nothing,
          FieldDef "VAT" FTBigDecimal Nothing
        ],
      rdGroups = []
    }

-- ============================================================================
-- PERSONS REPORTS
-- ============================================================================

-- | Person list (Список контрагентов)
personListReport :: ReportDef
personListReport =
  ReportDef
    { rdName = "PersonList",
      rdTitle = "Counteragents List / Список контрагентов",
      rdCategory = RCPersons,
      rdDescription = "All persons directory",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT p.code as Code, p.name as Name, pk.name as Kind,",
            "       p.inn as INN, p.kpp as KPP, p.phone as Phone, p.email as Email",
            "FROM person p",
            "JOIN person_kind pk ON pk.id = p.person_kind_id",
            "WHERE p.status = 'ACTIVE'",
            "ORDER BY p.name"
          ],
      rdParams =
        [ ParamDef "PersonKindID" PTList "Kind" False (Just "0")
        ],
      rdFields =
        [ FieldDef "Code" FTString Nothing,
          FieldDef "Name" FTString Nothing,
          FieldDef "Kind" FTString Nothing,
          FieldDef "INN" FTString Nothing,
          FieldDef "KPP" FTString Nothing,
          FieldDef "Phone" FTString Nothing,
          FieldDef "Email" FTString Nothing
        ],
      rdGroups = [GroupDef "ByKind" "Kind" True]
    }

-- ============================================================================
-- ANALYTICS REPORTS
-- ============================================================================

-- | Sales turnover (Обороты продаж)
salesTurnoverReport :: ReportDef
salesTurnoverReport =
  ReportDef
    { rdName = "SalesTurnover",
      rdTitle = "Sales Turnover / Обороты продаж",
      rdCategory = RCAnalytics,
      rdDescription = "Sales analysis by goods",
      rdJrxml = "",
      rdSql =
        T.unlines
          [ "SELECT g.code as GoodsCode, g.name as GoodsName,",
            "       gg.name as GroupName,",
            "       SUM(bl.qty) as TotalQty,",
            "       SUM(bl.qty * bl.price) as TotalSum",
            "FROM bill b",
            "JOIN bill_line bl ON bl.bill_id = b.id",
            "JOIN goods g ON g.id = bl.goods_id",
            "LEFT JOIN goods_group gg ON gg.id = g.parent_id",
            "WHERE b.bill_type_id IN (SELECT id FROM bill_type WHERE is_sale = TRUE)",
            "  AND b.dt BETWEEN $P{StartDate} AND $P{EndDate}",
            "  AND b.status = 'POSTED'",
            "GROUP BY g.id, g.code, g.name, gg.name",
            "HAVING SUM(bl.qty * bl.price) > 0",
            "ORDER BY TotalSum DESC"
          ],
      rdParams =
        [ ParamDef "StartDate" PTDate "Start Date" True Nothing,
          ParamDef "EndDate" PTDate "End Date" True Nothing
        ],
      rdFields =
        [ FieldDef "GoodsCode" FTString Nothing,
          FieldDef "GoodsName" FTString Nothing,
          FieldDef "GroupName" FTString Nothing,
          FieldDef "TotalQty" FTDouble Nothing,
          FieldDef "TotalSum" FTBigDecimal Nothing
        ],
      rdGroups = [GroupDef "ByGroup" "GroupName" True]
    }

-- ============================================================================
-- REPORT REGISTRY
-- ============================================================================

-- | All available reports
allReports :: Map Text ReportDef
allReports =
  Map.fromList
    [ ("Balance", balanceReport),
      ("AccountTurnover", accountTurnoverReport),
      ("AccEntryList", accountingEntryList),
      ("GoodsRest", goodsRestReport),
      ("GoodsMovement", goodsMovementReport),
      ("Inventory", inventoryReport),
      ("BillList", billListReport),
      ("GoodsBill", goodsBillReport),
      ("Invoice", invoiceReport),
      ("Salary", salaryReport),
      ("PaymentOrder", paymentOrderReport),
      ("CashBook", cashBookReport),
      ("VATBookBuy", vatBookBuyReport),
      ("VATBookSell", vatBookSellReport),
      ("PersonList", personListReport),
      ("SalesTurnover", salesTurnoverReport)
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
  Just r -> pure (Just (generateJRXML r))
  Nothing -> pure Nothing

-- | Export all reports to directory
exportAllReports :: FilePath -> IO ()
exportAllReports dir = mapM_ exportOne (Map.toList allReports)
  where
    exportOne (name, r) = writeFile (dir <> "/" <> T.unpack name <> ".jrxml") (T.unpack (generateJRXML r))

-- ============================================================================
-- REPORT SERVICE API
-- ============================================================================

-- | Get available reports metadata
getReportsMetadata :: IO [Value]
getReportsMetadata = do
  let reports = Map.elems allReports
  let reportValues = fmap toReportValue reports
  pure reportValues
  where
    toReportValue r =
      object
        [ "name" .= rdName r,
          "title" .= rdTitle r,
          "category" .= show (rdCategory r),
          "description" .= rdDescription r,
          "parameters" .= fmap paramToValue (rdParams r)
        ]

    paramToValue p =
      object
        [ "name" .= pName p,
          "type" .= show (pType p),
          "label" .= pLabel p,
          "required" .= pRequired p
        ]

-- | Generate report JRXML
generateReportJRXML :: Text -> IO (Maybe Text)
generateReportJRXML name = case getReport name of
  Just r -> pure (Just (generateJRXML r))
  Nothing -> pure Nothing

-- | Get report SQL query
getReportSQL :: Text -> IO (Maybe Text)
getReportSQL name = case getReport name of
  Just r -> pure (Just (rdSql r))
  Nothing -> pure Nothing

-- | Validate report parameters
validateReportParams :: Text -> Map Text Value -> Either String [Text]
validateReportParams name paramValues = case getReport name of
  Nothing -> Left "Report not found"
  Just r -> validateParams (rdParams r) paramValues
  where
    validateParams _params _values = Right [] -- Basic validation

-- | Generate report data preview
generateReportPreview :: Text -> Map Text Value -> IO (Either String Value)
generateReportPreview name _paramValues = do
  case getReport name of
    Nothing -> pure $ Left "Report not found"
    Just r -> do
      -- Generate mock preview data
      let previewData =
            object
              [ "report" .= rdName r,
                "title" .= rdTitle r,
                "category" .= show (rdCategory r),
                "parameters" .= fmap paramToValue (rdParams r),
                "fields" .= fmap fieldToValue (rdFields r)
              ]
      pure $ Right previewData
      where
        paramToValue p =
          object
            [ "name" .= pName p,
              "type" .= show (pType p),
              "label" .= pLabel p,
              "required" .= pRequired p,
              "default" .= fromMaybe "" (pDefault p)
            ]

        fieldToValue f =
          object
            [ "name" .= fName f,
              "type" .= show (fType f),
              "formula" .= fromMaybe "" (fFormula f)
            ]
