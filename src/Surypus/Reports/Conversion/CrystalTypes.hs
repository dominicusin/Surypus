-- ============================================================================
-- CRYSTAL REPORTS DATA TYPES (Shared between converters)
-- ============================================================================
{-# LANGUAGE DeriveGeneric #-}

module Surypus.Reports.Conversion.CrystalTypes
  ( CrystalReport (..),
    CrystalSection (..),
    CrystalReportObject (..),
    CrystalTextObject (..),
    CrystalFieldObject (..),
    CrystalFormulaObject (..),
    CrystalLineObject (..),
    CrystalBoxObject (..),
    CrystalSubreport (..),
    CrystalGraphObject (..),
    CrystalGroup (..),
    CrystalParameter (..),
    CrystalDatabaseField (..),
    CrystalFormulaField (..),
  )
where

import Data.Text (Text)
import GHC.Generics (Generic)

-- ============================================================================
-- TYPES
-- ============================================================================

data CrystalReport = CrystalReport
  { crName :: Text,
    crSections :: [CrystalSection],
    crGroups :: [CrystalGroup],
    crParameters :: [CrystalParameter],
    crDatabaseFields :: [CrystalDatabaseField],
    crFormulaFields :: [CrystalFormulaField],
    crSubreports :: [CrystalSubreport]
  }
  deriving (Show, Generic)

data CrystalSection
  = ReportHeaderSection [CrystalReportObject]
  | PageHeaderSection [CrystalReportObject]
  | GroupHeaderSection Text [CrystalReportObject]
  | DetailSection [CrystalReportObject]
  | GroupFooterSection Text [CrystalReportObject]
  | ReportFooterSection [CrystalReportObject]
  | PageFooterSection [CrystalReportObject]
  deriving (Show, Generic)

data CrystalReportObject
  = TextObject CrystalTextObject
  | FieldObject CrystalFieldObject
  | FormulaObject CrystalFormulaObject
  | LineObject CrystalLineObject
  | BoxObject CrystalBoxObject
  | SubreportObject CrystalSubreport
  | GraphObject CrystalGraphObject
  deriving (Show, Generic)

data CrystalTextObject = CrystalTextObject
  { ctoX :: Double,
    ctoY :: Double,
    ctoWidth :: Double,
    ctoHeight :: Double,
    ctoText :: Text,
    ctoFontSize :: Maybe Int,
    ctoFontName :: Maybe Text,
    ctoBold :: Bool,
    ctoItalic :: Bool,
    ctoAlignment :: Text
  }
  deriving (Show, Generic)

data CrystalFieldObject = CrystalFieldObject
  { cfoX :: Double,
    cfoY :: Double,
    cfoWidth :: Double,
    cfoHeight :: Double,
    cfoFieldName :: Text,
    cfoFormat :: Maybe Text
  }
  deriving (Show, Generic)

data CrystalFormulaObject = CrystalFormulaObject
  { cformulaX :: Double,
    cformulaY :: Double,
    cformulaWidth :: Double,
    cformulaHeight :: Double,
    cformulaName :: Text,
    cformulaText :: Text
  }
  deriving (Show, Generic)

data CrystalLineObject = CrystalLineObject
  { cloX1 :: Double,
    cloY1 :: Double,
    cloX2 :: Double,
    cloY2 :: Double,
    cloThickness :: Maybe Int
  }
  deriving (Show, Generic)

data CrystalBoxObject = CrystalBoxObject
  { cboX :: Double,
    cboY :: Double,
    cboWidth :: Double,
    cboHeight :: Double,
    cboBorder :: Maybe Int,
    cboBackgroundColor :: Maybe Text
  }
  deriving (Show, Generic)

data CrystalSubreport = CrystalSubreport
  { csX :: Double,
    csY :: Double,
    csWidth :: Double,
    csHeight :: Double,
    csReportName :: Text,
    csLinkFields :: [(Text, Text)]
  }
  deriving (Show, Generic)

data CrystalGraphObject = CrystalGraphObject
  { cgoX :: Double,
    cgoY :: Double,
    cgoWidth :: Double,
    cgoHeight :: Double,
    cgoChartType :: Text,
    cgoDataField :: Text,
    cgoCategoryField :: Text
  }
  deriving (Show, Generic)

data CrystalGroup = CrystalGroup
  { cgName :: Text,
    cgField :: Text,
    cgHeaderSection :: [CrystalReportObject],
    cgFooterSection :: [CrystalReportObject]
  }
  deriving (Show, Generic)

data CrystalParameter = CrystalParameter
  { cpName :: Text,
    cpType :: Text,
    cpPrompt :: Maybe Text,
    cpDefaultValue :: Maybe Text
  }
  deriving (Show, Generic)

data CrystalDatabaseField = CrystalDatabaseField
  { cdfName :: Text,
    cdfType :: Text,
    cdfTable :: Text
  }
  deriving (Show, Generic)

data CrystalFormulaField = CrystalFormulaField
  { cffName :: Text,
    cffFormula :: Text,
    cffReturnType :: Text
  }
  deriving (Show, Generic)
