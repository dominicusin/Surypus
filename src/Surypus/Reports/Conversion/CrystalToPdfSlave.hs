{-# LANGUAGE DeriveGeneric #-}
-- ============================================================================
-- CRYSTAL REPORTS TO PDF-SLAVE YAML CONVERTER
-- ============================================================================
{-# LANGUAGE OverloadedStrings #-}

module Surypus.Reports.Conversion.CrystalToPdfSlave
  ( convertCrystalToPdfSlave,
    PdfSlaveTemplate (..),
    PdfSlaveSection (..),
    PdfSlaveElement (..),
    ReportContext (..),
    renderPdfSlave,
    exampleCrystalReport,
    convertExample,
  )
where

import Data.Aeson (FromJSON, ToJSON, defaultOptions, encode, genericToJSON)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import GHC.Generics (Generic)
import Numeric (showFFloat)
import Surypus.Reports.Conversion.CrystalTypes

-- ============================================================================
-- PDF-SLAVE TEMPLATE STRUCTURE
-- ============================================================================

data PdfSlaveTemplate = PdfSlaveTemplate
  { ptMeta :: PdfSlaveMeta,
    ptPage :: PdfSlavePage,
    ptHeader :: Maybe PdfSlaveSection,
    ptPageHeader :: Maybe PdfSlaveSection,
    ptBody :: Maybe PdfSlaveSection,
    ptFooter :: Maybe PdfSlaveSection,
    ptPageFooter :: Maybe PdfSlaveSection
  }
  deriving (Show, Generic)

instance ToJSON PdfSlaveTemplate where
  toJSON = genericToJSON defaultOptions

data PdfSlaveMeta = PdfSlaveMeta
  { pmTitle :: Text,
    pmAuthor :: Text,
    pmSubject :: Maybe Text,
    pmKeywords :: Maybe Text,
    pmCreator :: Text
  }
  deriving (Show, Generic)

instance ToJSON PdfSlaveMeta where
  toJSON = genericToJSON defaultOptions

data PdfSlavePage = PdfSlavePage
  { ppPaperSize :: Text,
    ppOrientation :: Text, -- "portrait" or "landscape"
    ppMarginTop :: Double,
    ppMarginBottom :: Double,
    ppMarginLeft :: Double,
    ppMarginRight :: Double
  }
  deriving (Show, Generic)

instance ToJSON PdfSlavePage where
  toJSON = genericToJSON defaultOptions

data PdfSlaveSection = PdfSlaveSection
  { psHeight :: Maybe Double,
    psElements :: [PdfSlaveElement]
  }
  deriving (Show, Generic)

instance ToJSON PdfSlaveSection where
  toJSON = genericToJSON defaultOptions

data PdfSlaveElement
  = TextElement PdfSlaveText
  | ImageElement PdfSlaveImage
  | TableElement PdfSlaveTable
  | BarcodeElement PdfSlaveBarcode
  | LineElement PdfSlaveLine
  | RectElement PdfSlaveRect
  deriving (Show, Generic)

instance ToJSON PdfSlaveElement where
  toJSON = genericToJSON defaultOptions

data PdfSlaveText = PdfSlaveText
  { ptX :: Double,
    ptY :: Double,
    ptWidth :: Maybe Double,
    ptHeight :: Maybe Double,
    ptValue :: Text,
    ptFontSize :: Maybe Int,
    ptFontFamily :: Maybe Text,
    ptFontWeight :: Maybe Text, -- "normal" or "bold"
    ptFontStyle :: Maybe Text, -- "normal" or "italic"
    ptTextAlign :: Maybe Text, -- "left", "center", "right"
    ptColor :: Maybe Text, -- hex color
    ptBackgroundColor :: Maybe Text
  }
  deriving (Show, Generic)

instance ToJSON PdfSlaveText where
  toJSON = genericToJSON defaultOptions

data PdfSlaveImage = PdfSlaveImage
  { piX :: Double,
    piY :: Double,
    piWidth :: Maybe Double,
    piHeight :: Maybe Double,
    piSrc :: Text
  }
  deriving (Show, Generic)

instance ToJSON PdfSlaveImage where
  toJSON = genericToJSON defaultOptions

data PdfSlaveTable = PdfSlaveTable
  { pttX :: Double,
    pttY :: Double,
    pttWidth :: Double,
    pttRepeatHeader :: Bool,
    pttColumns :: [PdfSlaveColumn],
    pttRows :: [[PdfSlaveCell]]
  }
  deriving (Show, Generic)

instance ToJSON PdfSlaveTable where
  toJSON = genericToJSON defaultOptions

data PdfSlaveColumn = PdfSlaveColumn
  { pcWidth :: Double,
    pcAlign :: Text
  }
  deriving (Show, Generic)

instance ToJSON PdfSlaveColumn where
  toJSON = genericToJSON defaultOptions

data PdfSlaveCell = PdfSlaveCell
  { pceValue :: Text,
    pceFontSize :: Maybe Int,
    pceBackgroundColor :: Maybe Text,
    pceAlign :: Maybe Text
  }
  deriving (Show, Generic)

instance ToJSON PdfSlaveCell where
  toJSON = genericToJSON defaultOptions

data PdfSlaveBarcode = PdfSlaveBarcode
  { pbX :: Double,
    pbY :: Double,
    pbWidth :: Maybe Double,
    pbHeight :: Maybe Double,
    pbValue :: Text,
    pbType :: Text -- "qr", "code128", "ean13", etc.
  }
  deriving (Show, Generic)

instance ToJSON PdfSlaveBarcode where
  toJSON = genericToJSON defaultOptions

data PdfSlaveLine = PdfSlaveLine
  { plX1 :: Double,
    plY1 :: Double,
    plX2 :: Double,
    plY2 :: Double,
    plStrokeWidth :: Maybe Double,
    plColor :: Maybe Text
  }
  deriving (Show, Generic)

instance ToJSON PdfSlaveLine where
  toJSON = genericToJSON defaultOptions

data PdfSlaveRect = PdfSlaveRect
  { prX :: Double,
    prY :: Double,
    prWidth :: Double,
    prHeight :: Double,
    prBorderWidth :: Maybe Double,
    prBorderColor :: Maybe Text,
    prFillColor :: Maybe Text
  }
  deriving (Show, Generic)

instance ToJSON PdfSlaveRect where
  toJSON = genericToJSON defaultOptions

-- ============================================================================
-- REPORT CONTEXT (Data from JSON)
-- ============================================================================

data ReportContext = ReportContext
  { rcCompanyName :: Text,
    rcCompanyAddress :: Maybe Text,
    rcCompanyInn :: Maybe Text,
    rcCompanyKpp :: Maybe Text,
    rcReportDate :: Text,
    rcReportNumber :: Maybe Text,
    rcUserName :: Text,
    rcData :: [ReportDataRow]
  }
  deriving (Show, Generic)

instance FromJSON ReportContext

data ReportDataRow = ReportDataRow
  { rdId :: Int,
    rdName :: Text,
    rdQuantity :: Double,
    rdPrice :: Double,
    rdSum :: Double,
    rdVat :: Double,
    rdTotal :: Double
  }
  deriving (Show, Generic)

instance FromJSON ReportDataRow

-- | Main conversion function
convertCrystalToPdfSlave :: CrystalReport -> PdfSlaveTemplate
convertCrystalToPdfSlave cr =
  PdfSlaveTemplate
    { ptMeta =
        PdfSlaveMeta
          { pmTitle = crName cr,
            pmAuthor = "Surypus ERP",
            pmSubject = Nothing,
            pmKeywords = Nothing,
            pmCreator = "Crystal to PdfSlave Converter"
          },
      ptPage =
        PdfSlavePage
          { ppPaperSize = "A4",
            ppOrientation = "portrait",
            ppMarginTop = 20.0,
            ppMarginBottom = 20.0,
            ppMarginLeft = 20.0,
            ppMarginRight = 20.0
          },
      ptHeader = convertSection $ findSection isReportHeader cr,
      ptPageHeader = convertSection $ findSection isPageHeader cr,
      ptBody = convertDetailSection $ findSection isDetail cr,
      ptFooter = convertSection $ findSection isReportFooter cr,
      ptPageFooter = convertSection $ findSection isPageFooter cr
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
    isReportFooter (ReportFooterSection _) = True
    isReportFooter _ = False
    isPageFooter (PageFooterSection _) = True
    isPageFooter _ = False

convertSection :: Maybe CrystalSection -> Maybe PdfSlaveSection
convertSection Nothing = Nothing
convertSection (Just (ReportHeaderSection objs)) =
  Just
    PdfSlaveSection
      { psHeight = Nothing,
        psElements = fmap convertObject objs
      }
convertSection (Just (PageHeaderSection objs)) =
  Just
    PdfSlaveSection
      { psHeight = Nothing,
        psElements = fmap convertObject objs
      }
convertSection (Just (ReportFooterSection objs)) =
  Just
    PdfSlaveSection
      { psHeight = Nothing,
        psElements = fmap convertObject objs
      }
convertSection (Just (PageFooterSection objs)) =
  Just
    PdfSlaveSection
      { psHeight = Nothing,
        psElements = fmap convertObject objs
      }
convertSection (Just (GroupHeaderSection _ objs)) =
  Just
    PdfSlaveSection
      { psHeight = Nothing,
        psElements = fmap convertObject objs
      }
convertSection (Just (GroupFooterSection _ objs)) =
  Just
    PdfSlaveSection
      { psHeight = Nothing,
        psElements = fmap convertObject objs
      }
convertSection (Just (DetailSection _)) = Nothing -- Handled separately

convertDetailSection :: Maybe CrystalSection -> Maybe PdfSlaveSection
convertDetailSection Nothing = Nothing
convertDetailSection (Just (DetailSection objs)) =
  Just
    PdfSlaveSection
      { psHeight = Nothing,
        psElements = fmap convertObject objs
      }
convertDetailSection _ = Nothing

convertObject :: CrystalReportObject -> PdfSlaveElement
convertObject (TextObject cto) =
  TextElement
    PdfSlaveText
      { ptX = ctoX cto,
        ptY = ctoY cto,
        ptWidth = Just (ctoWidth cto),
        ptHeight = Just (ctoHeight cto),
        ptValue = ctoText cto,
        ptFontSize = ctoFontSize cto,
        ptFontFamily = ctoFontName cto,
        ptFontWeight = if ctoBold cto then Just "bold" else Nothing,
        ptFontStyle = if ctoItalic cto then Just "italic" else Nothing,
        ptTextAlign = Just (ctoAlignment cto),
        ptColor = Nothing,
        ptBackgroundColor = Nothing
      }
convertObject (FieldObject cfo) =
  TextElement
    PdfSlaveText
      { ptX = cfoX cfo,
        ptY = cfoY cfo,
        ptWidth = Just (cfoWidth cfo),
        ptHeight = Just (cfoHeight cfo),
        ptValue = "{{" <> cfoFieldName cfo <> "}}",
        ptFontSize = Nothing,
        ptFontFamily = Nothing,
        ptFontWeight = Nothing,
        ptFontStyle = Nothing,
        ptTextAlign = Nothing,
        ptColor = Nothing,
        ptBackgroundColor = Nothing
      }
convertObject (FormulaObject cformula) =
  TextElement
    PdfSlaveText
      { ptX = cformulaX cformula,
        ptY = cformulaY cformula,
        ptWidth = Just (cformulaWidth cformula),
        ptHeight = Just (cformulaHeight cformula),
        ptValue = "{{" <> cformulaName cformula <> "}}",
        ptFontSize = Nothing,
        ptFontFamily = Nothing,
        ptFontWeight = Nothing,
        ptFontStyle = Nothing,
        ptTextAlign = Nothing,
        ptColor = Nothing,
        ptBackgroundColor = Nothing
      }
convertObject (LineObject clo) =
  LineElement
    PdfSlaveLine
      { plX1 = cloX1 clo,
        plY1 = cloY1 clo,
        plX2 = cloX2 clo,
        plY2 = cloY2 clo,
        plStrokeWidth = fmap fromIntegral (cloThickness clo),
        plColor = Nothing
      }
convertObject (BoxObject cbo) =
  RectElement
    PdfSlaveRect
      { prX = cboX cbo,
        prY = cboY cbo,
        prWidth = cboWidth cbo,
        prHeight = cboHeight cbo,
        prBorderWidth = fmap fromIntegral (cboBorder cbo),
        prBorderColor = Nothing,
        prFillColor = cboBackgroundColor cbo
      }
convertObject (SubreportObject cs) =
  TextElement
    PdfSlaveText
      { ptX = csX cs,
        ptY = csY cs,
        ptWidth = Just (csWidth cs),
        ptHeight = Just (csHeight cs),
        ptValue = "[Subreport: " <> csReportName cs <> "]",
        ptFontSize = Nothing,
        ptFontFamily = Nothing,
        ptFontWeight = Nothing,
        ptFontStyle = Nothing,
        ptTextAlign = Nothing,
        ptColor = Nothing,
        ptBackgroundColor = Nothing
      }
convertObject (GraphObject cgo) =
  TextElement
    PdfSlaveText
      { ptX = cgoX cgo,
        ptY = cgoY cgo,
        ptWidth = Just (cgoWidth cgo),
        ptHeight = Just (cgoHeight cgo),
        ptValue = "[Chart: " <> cgoChartType cgo <> "]",
        ptFontSize = Nothing,
        ptFontFamily = Nothing,
        ptFontWeight = Nothing,
        ptFontStyle = Nothing,
        ptTextAlign = Nothing,
        ptColor = Nothing,
        ptBackgroundColor = Nothing
      }

-- ============================================================================
-- RENDER FUNCTION (stubbed - yaml dependency not available)
-- ============================================================================

-- | Render template to YAML file (stub - yaml dependency not available)
renderPdfSlave :: PdfSlaveTemplate -> FilePath -> IO ()
renderPdfSlave _template path = do
  putStrLn $ "YAML rendering not available (missing yaml dependency). Would write to: " <> path

-- | Render template to Text
renderPdfSlaveToText :: PdfSlaveTemplate -> Text
renderPdfSlaveToText = TE.decodeUtf8 . encode

-- ============================================================================
-- EXAMPLE CONVERSION
-- ============================================================================

exampleCrystalReport :: CrystalReport
exampleCrystalReport =
  CrystalReport
    { crName = "Invoice",
      crSections =
        [ ReportHeaderSection
            [ TextObject
                CrystalTextObject
                  { ctoX = 10,
                    ctoY = 10,
                    ctoWidth = 190,
                    ctoHeight = 10,
                    ctoText = "INVOICE",
                    ctoFontSize = Just 18,
                    ctoFontName = Just "Arial",
                    ctoBold = True,
                    ctoItalic = False,
                    ctoAlignment = "center"
                  },
              TextObject
                CrystalTextObject
                  { ctoX = 10,
                    ctoY = 25,
                    ctoWidth = 190,
                    ctoHeight = 5,
                    ctoText = "{{companyName}}",
                    ctoFontSize = Just 12,
                    ctoFontName = Just "Arial",
                    ctoBold = True,
                    ctoItalic = False,
                    ctoAlignment = "center"
                  }
            ],
          PageHeaderSection
            [ TextObject
                CrystalTextObject
                  { ctoX = 10,
                    ctoY = 40,
                    ctoWidth = 30,
                    ctoHeight = 5,
                    ctoText = "Name",
                    ctoFontSize = Just 10,
                    ctoFontName = Just "Arial",
                    ctoBold = True,
                    ctoItalic = False,
                    ctoAlignment = "left"
                  },
              TextObject
                CrystalTextObject
                  { ctoX = 50,
                    ctoY = 40,
                    ctoWidth = 30,
                    ctoHeight = 5,
                    ctoText = "Qty",
                    ctoFontSize = Just 10,
                    ctoFontName = Just "Arial",
                    ctoBold = True,
                    ctoItalic = False,
                    ctoAlignment = "right"
                  },
              TextObject
                CrystalTextObject
                  { ctoX = 90,
                    ctoY = 40,
                    ctoWidth = 30,
                    ctoHeight = 5,
                    ctoText = "Price",
                    ctoFontSize = Just 10,
                    ctoFontName = Just "Arial",
                    ctoBold = True,
                    ctoItalic = False,
                    ctoAlignment = "right"
                  },
              TextObject
                CrystalTextObject
                  { ctoX = 130,
                    ctoY = 40,
                    ctoWidth = 30,
                    ctoHeight = 5,
                    ctoText = "Sum",
                    ctoFontSize = Just 10,
                    ctoFontName = Just "Arial",
                    ctoBold = True,
                    ctoItalic = False,
                    ctoAlignment = "right"
                  },
              LineObject
                CrystalLineObject
                  { cloX1 = 10,
                    cloY1 = 47,
                    cloX2 = 190,
                    cloY2 = 47,
                    cloThickness = Just 1
                  }
            ],
          DetailSection
            [ FieldObject
                CrystalFieldObject
                  { cfoX = 10,
                    cfoY = 50,
                    cfoWidth = 30,
                    cfoHeight = 5,
                    cfoFieldName = "name",
                    cfoFormat = Nothing
                  },
              FieldObject
                CrystalFieldObject
                  { cfoX = 50,
                    cfoY = 50,
                    cfoWidth = 30,
                    cfoHeight = 5,
                    cfoFieldName = "quantity",
                    cfoFormat = Nothing
                  },
              FieldObject
                CrystalFieldObject
                  { cfoX = 90,
                    cfoY = 50,
                    cfoWidth = 30,
                    cfoHeight = 5,
                    cfoFieldName = "price",
                    cfoFormat = Nothing
                  },
              FieldObject
                CrystalFieldObject
                  { cfoX = 130,
                    cfoY = 50,
                    cfoWidth = 30,
                    cfoHeight = 5,
                    cfoFieldName = "sum",
                    cfoFormat = Nothing
                  }
            ],
          ReportFooterSection
            [ LineObject
                CrystalLineObject
                  { cloX1 = 10,
                    cloY1 = 270,
                    cloX2 = 190,
                    cloY2 = 270,
                    cloThickness = Just 1
                  },
              TextObject
                CrystalTextObject
                  { ctoX = 130,
                    ctoY = 275,
                    ctoWidth = 30,
                    ctoHeight = 5,
                    ctoText = "Total: {{total}}",
                    ctoFontSize = Just 10,
                    ctoFontName = Just "Arial",
                    ctoBold = True,
                    ctoItalic = False,
                    ctoAlignment = "right"
                  }
            ]
        ],
      crGroups = [],
      crParameters = [],
      crDatabaseFields = [],
      crFormulaFields = [],
      crSubreports = []
    }

-- | Convert example report
convertExample :: IO ()
convertExample = do
  let template = convertCrystalToPdfSlave exampleCrystalReport
  renderPdfSlave template "example_invoice.yaml"
  putStrLn "Converted example_invoice.yaml"
