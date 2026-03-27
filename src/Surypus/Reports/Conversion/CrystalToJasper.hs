{-# LANGUAGE DeriveGeneric #-}
-- ============================================================================
-- CRYSTAL REPORTS TO JASPERREPORTS JRXML CONVERTER
-- ============================================================================
{-# LANGUAGE OverloadedStrings #-}

module Surypus.Reports.Conversion.CrystalToJasper
  ( convertCrystalToJasper,
    JasperReport (..),
    JasperBand (..),
    JasperElement (..),
    JasperField (..),
    JasperVariable (..),
    JasperGroup (..),
    JasperSubreport (..),
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import GHC.Generics (Generic)
import Numeric (showFFloat)
import Surypus.Reports.Conversion.CrystalTypes

-- ============================================================================
-- JASPERREPORTS JRXML STRUCTURE
-- ============================================================================

data JasperReport = JasperReport
  { jrName :: Text,
    jrColumnCount :: Int,
    jrPrintOrder :: Text, -- "Vertical" or "Horizontal"
    jrOrientation :: Text, -- "Portrait" or "Landscape"
    jrPageWidth :: Int,
    jrPageHeight :: Int,
    jrColumnWidth :: Int,
    jrColumnSpacing :: Int,
    jrLeftMargin :: Int,
    jrRightMargin :: Int,
    jrTopMargin :: Int,
    jrBottomMargin :: Int,
    jrIsTitleNewPage :: Bool,
    jrIsSummaryNewPage :: Bool,
    jrFields :: [JasperField],
    jrVariables :: [JasperVariable],
    jrGroups :: [JasperGroup],
    jrTitleBand :: Maybe JasperBand,
    jrPageHeaderBand :: Maybe JasperBand,
    jrColumnHeaderBand :: Maybe JasperBand,
    jrDetailBand :: Maybe JasperBand,
    jrColumnFooterBand :: Maybe JasperBand,
    jrPageFooterBand :: Maybe JasperBand,
    jrSummaryBand :: Maybe JasperBand
  }
  deriving (Show, Generic)

data JasperBand = JasperBand
  { jbHeight :: Int,
    jbIsSplitAllowed :: Bool,
    jbElements :: [JasperElement]
  }
  deriving (Show, Generic)

data JasperElement
  = JStaticText JasperStaticText
  | JTextField JasperTextField
  | JLine JasperLine
  | JRectangle JasperRectangle
  | JImage JasperImage
  | JBarcode JasperBarcode
  | JSubreport JasperSubreport
  | JChart JasperChart
  deriving (Show, Generic)

data JasperStaticText = JasperStaticText
  { jstX :: Int,
    jstY :: Int,
    jstWidth :: Int,
    jstHeight :: Int,
    jstText :: Text,
    jstFontName :: Maybe Text,
    jstFontSize :: Maybe Int,
    jstIsBold :: Bool,
    jstIsItalic :: Bool,
    jstIsUnderline :: Bool,
    jstForecolor :: Text, -- hex
    jstBackcolor :: Maybe Text,
    jstHorizontalAlignment :: Text, -- "Left", "Center", "Right"
    jstVerticalAlignment :: Text -- "Top", "Middle", "Bottom"
  }
  deriving (Show, Generic)

data JasperTextField = JasperTextField
  { jtfX :: Int,
    jtfY :: Int,
    jtfWidth :: Int,
    jtfHeight :: Int,
    jtfExpression :: Text,
    -- \$F{field} or $V{variable} or formula
    jtfPattern :: Maybe Text, -- date/number format
    jtfFontName :: Maybe Text,
    jtfFontSize :: Maybe Int,
    jtfIsBold :: Bool,
    jtfIsItalic :: Bool,
    jtfForecolor :: Text,
    jtfHorizontalAlignment :: Text,
    jtfVerticalAlignment :: Text,
    jtfEvaluationTime :: Text, -- "Now", "Band", "Group"
    jtfEvaluationGroup :: Maybe Text
  }
  deriving (Show, Generic)

data JasperLine = JasperLine
  { jlX :: Int,
    jlY :: Int,
    jlWidth :: Int,
    jlHeight :: Int,
    jlForecolor :: Text,
    jlStrokeWidth :: Maybe Double,
    jlPosition :: Text -- "Top", "Middle", "Bottom"
  }
  deriving (Show, Generic)

data JasperRectangle = JasperRectangle
  { jrX :: Int,
    jrY :: Int,
    jrWidth :: Int,
    jrHeight :: Int,
    jrectForecolor :: Text,
    jrectBackcolor :: Maybe Text,
    jrectRadius :: Maybe Int,
    jrectBorder :: Text -- "None", "1Point", etc.
  }
  deriving (Show, Generic)

data JasperImage = JasperImage
  { jiX :: Int,
    jiY :: Int,
    jiWidth :: Int,
    jiHeight :: Int,
    jiExpression :: Text,
    -- \$F{image} or URL
    jiScaleImage :: Text, -- "Clip", "Fill", "RetainShape", "RealHeight", "RealSize"
    jiHorizontalAlignment :: Text,
    jiVerticalAlignment :: Text
  }
  deriving (Show, Generic)

data JasperBarcode = JasperBarcode
  { jbcX :: Int,
    jbcY :: Int,
    jbcWidth :: Int,
    jbcHeight :: Int,
    jbcExpression :: Text,
    jbcType :: Text, -- "CODE128", "EAN13", "QR_CODE", etc.
    jbcApplicationIdentifier :: Maybe Text
  }
  deriving (Show, Generic)

data JasperSubreport = JasperSubreport
  { jsX :: Int,
    jsY :: Int,
    jsWidth :: Int,
    jsHeight :: Int,
    jsReportExpression :: Text, -- path to subreport .jasper
    jsConnectionExpression :: Maybe Text,
    jsParameters :: [(Text, Text)] -- (name, expression)
  }
  deriving (Show, Generic)

data JasperChart = JasperChart
  { jchX :: Int,
    jchY :: Int,
    jchWidth :: Int,
    jchHeight :: Int,
    jchChartType :: Text, -- "barChart", "pieChart", "lineChart", "stackedBarChart"
    jchTitle :: Maybe Text,
    jchDomainAxisLabel :: Maybe Text,
    jchRangeAxisLabel :: Maybe Text,
    jchSeriesExpression :: Maybe Text,
    jchCategoryExpression :: Text,
    jchValueExpression :: Text
  }
  deriving (Show, Generic)

data JasperField = JasperField
  { jfName :: Text,
    jfClass :: Text -- Java class (java.lang.String, java.lang.Integer, etc.)
  }
  deriving (Show, Generic)

data JasperVariable = JasperVariable
  { jvName :: Text,
    jvClass :: Text,
    jvResetType :: Text, -- "Report", "Page", "Column", "Group"
    jvResetGroup :: Maybe Text,
    jvCalculation :: Text, -- "Sum", "Count", "Average", "Nothing"
    jvIncrementType :: Maybe Text,
    jvIncrementGroup :: Maybe Text,
    jvExpression :: Maybe Text,
    jvInitialValueExpression :: Maybe Text
  }
  deriving (Show, Generic)

data JasperGroup = JasperGroup
  { jgName :: Text,
    jgExpression :: Text,
    jgIsStartNewColumn :: Bool,
    jgIsStartNewPage :: Bool,
    jgIsResetPageNumber :: Bool,
    jgGroupHeader :: Maybe JasperBand,
    jgGroupFooter :: Maybe JasperBand
  }
  deriving (Show, Generic)

-- ============================================================================
-- CONVERSION FUNCTION
-- ============================================================================

convertCrystalToJasper :: CrystalReport -> JasperReport
convertCrystalToJasper cr =
  JasperReport
    { jrName = crName cr,
      jrColumnCount = 1,
      jrPrintOrder = "Vertical",
      jrOrientation = "Portrait",
      jrPageWidth = 595, -- A4 points
      jrPageHeight = 842,
      jrColumnWidth = 555,
      jrColumnSpacing = 0,
      jrLeftMargin = 20,
      jrRightMargin = 20,
      jrTopMargin = 20,
      jrBottomMargin = 20,
      jrIsTitleNewPage = False,
      jrIsSummaryNewPage = True,
      jrFields = undefined -- convertDatabaseFields (crDatabaseFields cr),
      jrVariables = undefined -- convertFormulaFields (crFormulaFields cr),
      jrGroups = undefined -- convertGroups (crGroups cr),
      jrTitleBand = undefined -- convertToBand $ findSection isReportHeader cr,
      jrPageHeaderBand = undefined -- convertToBand $ findSection isPageHeader cr,
      jrColumnHeaderBand = Nothing,
      jrDetailBand = undefined -- convertToBand $ findSection isDetail cr,
      jrColumnFooterBand = Nothing,
      jrPageFooterBand = undefined -- convertToBand $ findSection isPageFooter cr,
      jrSummaryBand = undefined -- convertToBand $ findSection isReportFooter cr
    }
  where
    findSection pred' c = case filter pred' (crSections c) of
      (s : _) -> Just s
      _ -> Nothing
    isReportHeader (ReportHeaderSection _) = True
    isReportHeader _ = False
    isPageHeader (PageHeaderSection _) = True
    isPageHeader _ = False
    isDetail (DetailSection _) = True
    isDetail _ = False
    isPageFooter (PageFooterSection _) = True
    isPageFooter _ = False
    isReportFooter (ReportFooterSection _) = True
    isReportFooter _ = False

getSection :: CrystalReport -> (CrystalSection -> Bool) -> Maybe CrystalSection
getSection cr pred' = case filter pred' (crSections cr) of
  (s : _) -> Just s
  _ -> Nothing

-- ============================================================================
-- EXAMPLE
-- ============================================================================

renderExample :: IO ()
renderExample = do
  putStrLn "CrystalToJasper example: no example report defined"
