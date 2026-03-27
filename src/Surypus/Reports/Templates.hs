{-# LANGUAGE DeriveGeneric #-}
-- ============================================================================
-- REPORT TEMPLATE LOADER
-- ============================================================================
{-# LANGUAGE OverloadedStrings #-}

module Surypus.Reports.Templates
  ( ReportTemplate (..),
    loadTemplate,
    loadTemplateFromFile,
    listTemplates,
    getTemplatePath,
    TemplateType (..),
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import System.FilePath ((</>))

-- ============================================================================
-- TEMPLATE TYPES
-- ============================================================================

data TemplateType
  = Invoice -- Счёт-фактура
  | Order -- Счёт на оплату
  | GoodsRequisition -- Товарная накладная (ТОРГ-12)
  | Act -- Акт выполненных работ
  | Payroll -- Расчётная ведомость
  | Inventory -- Остатки товаров
  | Balance -- Бухгалтерский баланс
  | CashIn -- Приходный кассовый ордер
  | CashOut -- Расходный кассовый ордер
  | Custom Text -- Пользовательский шаблон
  deriving (Show, Eq)

templateTypeToFile :: TemplateType -> Text
templateTypeToFile Invoice = "invoice.yaml"
templateTypeToFile Order = "order.yaml"
templateTypeToFile GoodsRequisition = "goods_requisition.yaml"
templateTypeToFile Act = "act.yaml"
templateTypeToFile Payroll = "payroll.yaml"
templateTypeToFile Inventory = "inventory.yaml"
templateTypeToFile Balance = "balance.yaml"
templateTypeToFile CashIn = "cash_in.yaml"
templateTypeToFile CashOut = "cash_out.yaml"
templateTypeToFile (Custom name) = name <> ".yaml"

templateTypeToName :: TemplateType -> Text
templateTypeToName Invoice = "Счёт-фактура"
templateTypeToName Order = "Счёт на оплату"
templateTypeToName GoodsRequisition = "Товарная накладная"
templateTypeToName Act = "Акт выполненных работ"
templateTypeToName Payroll = "Расчётная ведомость"
templateTypeToName Inventory = "Остатки товаров"
templateTypeToName Balance = "Бухгалтерский баланс"
templateTypeToName CashIn = "Приходный кассовый ордер"
templateTypeToName CashOut = "Расходный кассовый ордер"
templateTypeToName (Custom name) = name

-- ============================================================================
-- TEMPLATE STRUCTURE (simplified)
-- ============================================================================

data ReportTemplate = ReportTemplate
  { rtMeta :: TemplateMeta,
    rtPage :: TemplatePage,
    rtHeader :: Maybe TemplateSection,
    rtPageHeader :: Maybe TemplateSection,
    rtBody :: Maybe TemplateSection,
    rtFooter :: Maybe TemplateSection,
    rtPageFooter :: Maybe TemplateSection
  }
  deriving (Show, Generic)

data TemplateMeta = TemplateMeta
  { tmTitle :: Text,
    tmAuthor :: Text,
    tmSubject :: Maybe Text,
    tmKeywords :: Maybe Text,
    tmCreator :: Text
  }
  deriving (Show, Generic)

data TemplatePage = TemplatePage
  { tpPaperSize :: Text,
    tpOrientation :: Text,
    tpMarginTop :: Double,
    tpMarginBottom :: Double,
    tpMarginLeft :: Double,
    tpMarginRight :: Double
  }
  deriving (Show, Generic)

data TemplateSection = TemplateSection
  { tsHeight :: Double,
    tsRepeat :: Maybe Bool,
    tsElements :: [TemplateElement]
  }
  deriving (Show, Generic)

data TemplateElement
  = TextElement TemplateText
  | TableElement TemplateTable
  | LineElement TemplateLine
  | RectElement TemplateRect
  deriving (Show, Generic)

data TemplateText = TemplateText
  { ttxtX :: Double,
    ttxtY :: Double,
    ttxtWidth :: Double,
    ttxtHeight :: Double,
    ttxtValue :: Text,
    ttxtFontSize :: Maybe Int,
    ttxtFontWeight :: Maybe Text,
    ttxtFontStyle :: Maybe Text,
    ttxtTextAlign :: Maybe Text,
    ttxtColor :: Maybe Text,
    ttxtBackgroundColor :: Maybe Text
  }
  deriving (Show, Generic)

data TemplateTable = TemplateTable
  { ttblX :: Double,
    ttblY :: Double,
    ttblWidth :: Double,
    ttblRepeatHeader :: Bool,
    ttblColumns :: [TemplateColumn],
    ttblRows :: [[TemplateCell]]
  }
  deriving (Show, Generic)

data TemplateColumn = TemplateColumn
  { tcolWidth :: Double,
    tcolAlign :: Text
  }
  deriving (Show, Generic)

data TemplateCell = TemplateCell
  { tcellText :: Text,
    tcellFontSize :: Maybe Int,
    tcellFontWeight :: Maybe Text,
    tcellBackgroundColor :: Maybe Text,
    tcellAlign :: Maybe Text
  }
  deriving (Show, Generic)

data TemplateLine = TemplateLine
  { tlX1 :: Double,
    tlY1 :: Double,
    tlX2 :: Double,
    tlY2 :: Double,
    tlStrokeWidth :: Maybe Double
  }
  deriving (Show, Generic)

data TemplateRect = TemplateRect
  { trX :: Double,
    trY :: Double,
    trWidth :: Double,
    trHeight :: Double,
    trBorderWidth :: Maybe Double,
    trBorderColor :: Maybe Text,
    trFillColor :: Maybe Text
  }
  deriving (Show, Generic)

-- ============================================================================
-- LOADER FUNCTIONS (stubbed - yaml/directory not available)
-- ============================================================================

-- | Get template directory path
getTemplateDir :: IO FilePath
getTemplateDir = pure "templates/reports"

-- | Get full path to template file
getTemplatePath :: TemplateType -> IO FilePath
getTemplatePath tpl = do
  dir <- getTemplateDir
  pure $ dir </> T.unpack (templateTypeToFile tpl)

-- | Load template by type (stub - yaml dependency not available)
loadTemplate :: TemplateType -> IO (Either String ReportTemplate)
loadTemplate _tpl = pure $ Left "YAML parsing not available (missing yaml dependency)"

-- | Load template from file path (stub)
loadTemplateFromFile :: FilePath -> IO (Either String ReportTemplate)
loadTemplateFromFile _path = pure $ Left "YAML parsing not available (missing yaml dependency)"

-- | List all available templates (stub - directory dependency not available)
listTemplates :: IO [(TemplateType, Text)]
listTemplates = pure []

-- ============================================================================
-- TEMPLATE INFO
-- ============================================================================

templateInfo :: TemplateType -> (Text, Text)
templateInfo tpl = (templateTypeToName tpl, templateTypeToFile tpl)

allTemplates :: [(TemplateType, Text)]
allTemplates =
  [ (Invoice, "Счёт-фактура (для налоговой)"),
    (Order, "Счёт на оплату"),
    (GoodsRequisition, "Товарная накладная ТОРГ-12"),
    (Act, "Акт выполненных работ/услуг"),
    (Payroll, "Расчётная ведомость по зарплате"),
    (Inventory, "Остатки товаров на складе"),
    (Balance, "Бухгалтерский баланс (Форма №1)"),
    (CashIn, "Приходный кассовый ордер (ПКО)"),
    (CashOut, "Расходный кассовый ордер (РКО)")
  ]
