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
import qualified Data.Text.IO as TIO
import qualified Data.Yaml as Yaml
import GHC.Generics (Generic)
import System.Directory (listDirectory)
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
-- TEMPLATE STRUCTURE (simplified YAML)
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

instance Yaml.FromJSON ReportTemplate

data TemplateMeta = TemplateMeta
  { tmTitle :: Text,
    tmAuthor :: Text,
    tmSubject :: Maybe Text,
    tmKeywords :: Maybe Text,
    tmCreator :: Text
  }
  deriving (Show, Generic)

instance Yaml.FromJSON TemplateMeta

data TemplatePage = TemplatePage
  { tpPaperSize :: Text,
    tpOrientation :: Text,
    tpMarginTop :: Double,
    tpMarginBottom :: Double,
    tpMarginLeft :: Double,
    tpMarginRight :: Double
  }
  deriving (Show, Generic)

instance Yaml.FromJSON TemplatePage

data TemplateSection = TemplateSection
  { tsHeight :: Double,
    tsRepeat :: Maybe Bool,
    tsElements :: [TemplateElement]
  }
  deriving (Show, Generic)

instance Yaml.FromJSON TemplateSection

data TemplateElement
  = TextElement TemplateText
  | TableElement TemplateTable
  | LineElement TemplateLine
  | RectElement TemplateRect
  deriving (Show, Generic)

instance Yaml.FromJSON TemplateElement

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

instance Yaml.FromJSON TemplateText

data TemplateTable = TemplateTable
  { ttblX :: Double,
    ttblY :: Double,
    ttblWidth :: Double,
    ttblRepeatHeader :: Bool,
    ttblColumns :: [TemplateColumn],
    ttblRows :: [[TemplateCell]]
  }
  deriving (Show, Generic)

instance Yaml.FromJSON TemplateTable

data TemplateColumn = TemplateColumn
  { tcolWidth :: Double,
    tcolAlign :: Text
  }
  deriving (Show, Generic)

instance Yaml.FromJSON TemplateColumn

data TemplateCell = TemplateCell
  { tcellText :: Text,
    tcellFontSize :: Maybe Int,
    tcellFontWeight :: Maybe Text,
    tcellBackgroundColor :: Maybe Text,
    tcellAlign :: Maybe Text
  }
  deriving (Show, Generic)

instance Yaml.FromJSON TemplateCell

data TemplateLine = TemplateLine
  { tlX1 :: Double,
    tlY1 :: Double,
    tlX2 :: Double,
    tlY2 :: Double,
    tlStrokeWidth :: Maybe Double
  }
  deriving (Show, Generic)

instance Yaml.FromJSON TemplateLine

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

instance Yaml.FromJSON TemplateRect

-- ============================================================================
-- LOADER FUNCTIONS
-- ============================================================================

-- | Get template directory path
getTemplateDir :: IO FilePath
getTemplateDir = do
  pure "templates/reports"

-- | Get full path to template file
getTemplatePath :: TemplateType -> IO FilePath
getTemplatePath tpl = do
  dir <- getTemplateDir
  pure $ dir </> T.unpack (templateTypeToFile tpl)

-- | Load template by type
loadTemplate :: TemplateType -> IO (Either String ReportTemplate)
loadTemplate tpl = do
  path <- getTemplatePath tpl
  loadTemplateFromFile path

-- | Load template from file path
loadTemplateFromFile :: FilePath -> IO (Either String ReportTemplate)
loadTemplateFromFile path = do
  content <- TIO.readFile path
  pure $ Yaml.decodeEither content

-- | List all available templates
listTemplates :: IO [(TemplateType, Text)]
listTemplates = do
  dir <- getTemplateDir
  files <- listDirectory dir
  pure $ fmap (\f -> (Custom (T.pack (dropExtension f)), T.pack f)) files
  where
    dropExtension :: String -> String
    dropExtension = reverse . drop1 . reverse . dropWhile (/= '.')

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
