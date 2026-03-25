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
  { jbX :: Int,
    jbY :: Int,
    jbWidth :: Int,
    jbHeight :: Int,
    jbExpression :: Text,
    jbType :: Text, -- "CODE128", "EAN13", "QR_CODE", etc.
    jbApplicationIdentifier :: Maybe Text
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
      jrFields = convertDatabaseFields (crDatabaseFields cr),
      jrVariables = convertFormulaFields (crFormulaFields cr),
      jrGroups = convertGroups (crGroups cr),
      jrTitleBand = convertToBand $ getSection cr ReportHeaderSection,
      jrPageHeaderBand = convertToBand $ getSection cr PageHeaderSection,
      jrColumnHeaderBand = Nothing,
      jrDetailBand = convertToBand $ getSection cr DetailSection,
      jrColumnFooterBand = Nothing,
      jrPageFooterBand = convertToBand $ getSection cr PageFooterSection,
      jrSummaryBand = convertToBand $ getSection cr ReportFooterSection
    }

getSection :: CrystalReport -> (a -> Bool) -> Maybe a
getSection cr pred' = case filter pred' (crSections cr) of
  (s : _) -> Just s
  _ -> Nothing

convertToBand :: Maybe CrystalSection -> Maybe JasperBand
convertToBand Nothing = Nothing
convertToBand (Just (ReportHeaderSection objs)) = Just $ convertObjectsToBand objs
convertToBand (Just (PageHeaderSection objs)) = Just $ convertObjectsToBand objs
convertToBand (Just (DetailSection objs)) = Just $ convertObjectsToBand objs
convertToBand (Just (ReportFooterSection objs)) = Just $ convertObjectsToBand objs
convertToBand (Just (PageFooterSection objs)) = Just $ convertObjectsToBand objs
convertToBand (Just (GroupHeaderSection _ objs)) = Just $ convertObjectsToBand objs
convertToBand (Just (GroupFooterSection _ objs)) = Just $ convertObjectsToBand objs

convertObjectsToBand :: [CrystalReportObject] -> JasperBand
convertObjectsToBand objs =
  JasperBand
    { jbHeight = 50, -- default
      jbIsSplitAllowed = False,
      jbElements = fmap convertElement objs
    }

convertElement :: CrystalReportObject -> JasperElement
convertElement (TextObject cto) =
  JStaticText
    JasperStaticText
      { jstX = round (ctoX cto * 2.83), -- mm to points (1mm = 2.83pt)
        jstY = round (ctoY cto * 2.83),
        jstWidth = round (ctoWidth cto * 2.83),
        jstHeight = round (ctoHeight cto * 2.83),
        jstText = ctoText cto,
        jstFontName = ctoFontName cto,
        jstFontSize = ctoFontSize cto,
        jstIsBold = ctoBold cto,
        jstIsItalic = ctoItalic cto,
        jstIsUnderline = False,
        jstForecolor = "#000000",
        jstBackcolor = Nothing,
        jstHorizontalAlignment = case ctoAlignment cto of
          "center" -> "Center"
          "right" -> "Right"
          _ -> "Left",
        jstVerticalAlignment = "Middle"
      }
convertElement (FieldObject cfo) =
  JTextField
    JasperTextField
      { jtfX = round (cfoX cfo * 2.83),
        jtfY = round (cfoY cfo * 2.83),
        jtfWidth = round (cfoWidth cfo * 2.83),
        jtfHeight = round (cfoHeight cfo * 2.83),
        jtfExpression = "$F{" <> cfoFieldName cfo <> "}",
        jtfPattern = cfoFormat cfo,
        jtfFontName = Nothing,
        jtfFontSize = Nothing,
        jtfIsBold = False,
        jtfIsItalic = False,
        jtfForecolor = "#000000",
        jtfHorizontalAlignment = "Left",
        jtfVerticalAlignment = "Middle",
        jtfEvaluationTime = "Now",
        jtfEvaluationGroup = Nothing
      }
convertElement (FormulaObject cformula) =
  JTextField
    JasperTextField
      { jtfX = round (cformulaX cformula * 2.83),
        jtfY = round (cformulaY cformula * 2.83),
        jtfWidth = round (cformulaWidth cformula * 2.83),
        jtfHeight = round (cformulaHeight cformula * 2.83),
        jtfExpression = "$V{" <> cformulaName cformula <> "}",
        jtfPattern = Nothing,
        jtfFontName = Nothing,
        jtfFontSize = Nothing,
        jtfIsBold = False,
        jtfIsItalic = False,
        jtfForecolor = "#0000FF",
        jtfHorizontalAlignment = "Left",
        jtfVerticalAlignment = "Middle",
        jtfEvaluationTime = "Now",
        jtfEvaluationGroup = Nothing
      }
convertElement (LineObject clo) =
  JLine
    JasperLine
      { jlX = round (cloX1 clo * 2.83),
        jlY = round (cloY1 clo * 2.83),
        jlWidth = round ((cloX2 clo - cloX1 clo) * 2.83),
        jlHeight = 1,
        jlForecolor = "#000000",
        jlStrokeWidth = fmap fromIntegral (cloThickness clo),
        jlPosition = "Top"
      }
convertElement (BoxObject cbo) =
  JRectangle
    JasperRectangle
      { jrX = round (cboX cbo * 2.83),
        jrY = round (cboY cbo * 2.83),
        jrWidth = round (cboWidth cbo * 2.83),
        jrHeight = round (cboHeight cbo * 2.83),
        jrectForecolor = "#000000",
        jrectBackcolor = cboBackgroundColor cbo,
        jrectRadius = Nothing,
        jrectBorder = case cboBorder cbo of
          Just 1 -> "1Point"
          Just 2 -> "2Point"
          _ -> "1Point"
      }
convertElement (SubreportObject cs) =
  JSubreport
    JasperSubreport
      { jsX = round (csX cs * 2.83),
        jsY = round (csY cs * 2.83),
        jsWidth = round (csWidth cs * 2.83),
        jsHeight = round (csHeight cs * 2.83),
        jsReportExpression = "\"" <> csReportName cs <> ".jasper\"",
        jsConnectionExpression = Nothing,
        jsParameters = fmap (\(a, b) -> (a, "$P{" <> b <> "}")) (csLinkFields cs)
      }
convertElement (GraphObject cgo) =
  JChart
    JasperChart
      { jchX = round (cgoX cgo * 2.83),
        jchY = round (cgoY cgo * 2.83),
        jchWidth = round (cgoWidth cgo * 2.83),
        jchHeight = round (cgoHeight cgo * 2.83),
        jchChartType = case cgoChartType cgo of
          "bar" -> "barChart"
          "pie" -> "pieChart"
          "line" -> "lineChart"
          _ -> "barChart",
        jchTitle = Nothing,
        jchDomainAxisLabel = Just (cgoCategoryField cgo),
        jchRangeAxisLabel = Just (cgoDataField cgo),
        jchSeriesExpression = Nothing,
        jchCategoryExpression = "$F{" <> cgoCategoryField cgo <> "}",
        jchValueExpression = "$F{" <> cgoDataField cgo <> "}"
      }

convertDatabaseFields :: [CrystalDatabaseField] -> [JasperField]
convertDatabaseFields = fmap convertField
  where
    convertField cdf =
      JasperField
        { jfName = cdfName cdf,
          jfClass = case cdfType cdf of
            "string" -> "java.lang.String"
            "number" -> "java.lang.Double"
            "integer" -> "java.lang.Integer"
            "date" -> "java.util.Date"
            "boolean" -> "java.lang.Boolean"
            _ -> "java.lang.String"
        }

convertFormulaFields :: [CrystalFormulaField] -> [JasperVariable]
convertFormulaFields = fmap convertFormula
  where
    convertFormula cff =
      JasperVariable
        { jvName = cffName cff,
          jvClass = case cffReturnType cff of
            "string" -> "java.lang.String"
            "number" -> "java.lang.Double"
            "boolean" -> "java.lang.Boolean"
            _ -> "java.lang.String",
          jvResetType = "Report",
          jvResetGroup = Nothing,
          jvCalculation = "Nothing",
          jvIncrementType = Nothing,
          jvIncrementGroup = Nothing,
          jvExpression = Just (convertCrystalFormula (cffFormula cff)),
          jvInitialValueExpression = Nothing
        }

convertCrystalFormula :: Text -> Text
convertCrystalFormula formula =
  -- Convert Crystal formula syntax to Jasper expression
  T.replace "{" "$F{" (T.replace "}" "}" formula)

convertGroups :: [CrystalGroup] -> [JasperGroup]
convertGroups = fmap convertGroup
  where
    convertGroup cg =
      JasperGroup
        { jgName = cgName cg,
          jgExpression = "$F{" <> cgField cg <> "}",
          jgIsStartNewColumn = False,
          jgIsStartNewPage = False,
          jgIsResetPageNumber = False,
          jgGroupHeader = convertToBand $ Just (GroupHeaderSection (cgName cg) (cgHeaderSection cg)),
          jgGroupFooter = convertToBand $ Just (GroupFooterSection (cgName cg) (cgFooterSection cg))
        }

-- ============================================================================
-- JRXML OUTPUT
-- ============================================================================

renderJasperXml :: JasperReport -> Text
renderJasperXml jr =
  T.concat
    [ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n",
      "<jasperReport xmlns=\"http://jasperreports.sourceforge.net/jasperreports\" ",
      "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" ",
      "xsi:schemaLocation=\"http://jasperreports.sourceforge.net/jasperreports ",
      "http://jasperreports.sourceforge.net/xsd/jasperreport.xsd\" ",
      "name=\"",
      jrName jr,
      "\" ",
      "columnCount=\"",
      T.pack (show (jrColumnCount jr)),
      "\" ",
      "printOrder=\"",
      jrPrintOrder jr,
      "\" ",
      "orientation=\"",
      jrOrientation jr,
      "\" ",
      "pageWidth=\"",
      T.pack (show (jrPageWidth jr)),
      "\" ",
      "pageHeight=\"",
      T.pack (show (jrPageHeight jr)),
      "\" ",
      "columnWidth=\"",
      T.pack (show (jrColumnWidth jr)),
      "\" ",
      "columnSpacing=\"",
      T.pack (show (jrColumnSpacing jr)),
      "\" ",
      "leftMargin=\"",
      T.pack (show (jrLeftMargin jr)),
      "\" ",
      "rightMargin=\"",
      T.pack (show (jrRightMargin jr)),
      "\" ",
      "topMargin=\"",
      T.pack (show (jrTopMargin jr)),
      "\" ",
      "bottomMargin=\"",
      T.pack (show (jrBottomMargin jr)),
      "\" ",
      "isTitleNewPage=\"",
      if jrIsTitleNewPage jr then "true" else "false",
      "\" ",
      "isSummaryNewPage=\"",
      if jrIsSummaryNewPage jr then "true" else "false",
      "\">\n",
      renderFields (jrFields jr),
      renderVariables (jrVariables jr),
      renderGroups (jrGroups jr),
      maybe "" renderBand (jrTitleBand jr),
      maybe "" renderBand (jrPageHeaderBand jr),
      maybe "" renderBand (jrDetailBand jr),
      maybe "" renderBand (jrPageFooterBand jr),
      maybe "" renderBand (jrSummaryBand jr),
      "</jasperReport>\n"
    ]

renderFields :: [JasperField] -> Text
renderFields fields = T.concat $ fmap renderField fields

renderField :: JasperField -> Text
renderField jf =
  T.concat
    [ "  <field name=\"",
      jfName jf,
      "\" class=\"",
      jfClass jf,
      "\"/>\n"
    ]

renderVariables :: [JasperVariable] -> Text
renderVariables vars = T.concat $ fmap renderVariable vars

renderVariable :: JasperVariable -> Text
renderVariable jv =
  T.concat
    [ "  <variable name=\"",
      jvName jv,
      "\" class=\"",
      jvClass jv,
      "\" ",
      "resetType=\"",
      jvResetType jv,
      "\" ",
      "calculation=\"",
      jvCalculation jv,
      "\">\n",
      case jvExpression jv of
        Just expr -> T.concat ["    <variableExpression><![CDATA[", expr, "]]></variableExpression>\n"]
        Nothing -> "",
      "  </variable>\n"
    ]

renderGroups :: [JasperGroup] -> Text
renderGroups groups = T.concat $ fmap renderGroup groups

renderGroup :: JasperGroup -> Text
renderGroup jg =
  T.concat
    [ "  <group name=\"",
      jgName jg,
      "\" ",
      "isStartNewColumn=\"",
      if jgIsStartNewColumn jg then "true" else "false",
      "\" ",
      "isStartNewPage=\"",
      if jgIsStartNewPage jg then "true" else "false",
      "\" ",
      "isResetPageNumber=\"",
      if jgIsResetPageNumber jg then "true" else "false",
      "\">\n",
      "    <groupExpression><![CDATA[",
      jgExpression jg,
      "]]></groupExpression>\n",
      maybe "" renderBand (jgGroupHeader jg),
      maybe "" renderBand (jgGroupFooter jg),
      "  </group>\n"
    ]

renderBand :: JasperBand -> Text
renderBand jb =
  T.concat
    [ "  <band height=\"",
      T.pack (show (jbHeight jb)),
      "\" ",
      "isSplitAllowed=\"",
      if jbIsSplitAllowed jb then "true" else "false",
      "\">\n",
      T.concat $ fmap renderElement (jbElements jb),
      "  </band>\n"
    ]

renderElement :: JasperElement -> Text
renderElement (JStaticText jst) =
  T.concat
    [ "    <staticText>\n",
      "      <reportElement x=\"",
      T.pack (show (jstX jst)),
      "\" ",
      "y=\"",
      T.pack (show (jstY jst)),
      "\" ",
      "width=\"",
      T.pack (show (jstWidth jst)),
      "\" ",
      "height=\"",
      T.pack (show (jstHeight jst)),
      "\"/>\n",
      "      <text><![CDATA[",
      jstText jst,
      "]]></text>\n",
      "    </staticText>\n"
    ]
renderElement (JTextField jtf) =
  T.concat
    [ "    <textField>\n",
      "      <reportElement x=\"",
      T.pack (show (jtfX jtf)),
      "\" ",
      "y=\"",
      T.pack (show (jtfY jtf)),
      "\" ",
      "width=\"",
      T.pack (show (jtfWidth jtf)),
      "\" ",
      "height=\"",
      T.pack (show (jtfHeight jtf)),
      "\"/>\n",
      "      <textFieldExpression><![CDATA[",
      jtfExpression jtf,
      "]]></textFieldExpression>\n",
      "    </textField>\n"
    ]
renderElement (JLine jl) =
  T.concat
    [ "    <line>\n",
      "      <reportElement x=\"",
      T.pack (show (jlX jl)),
      "\" ",
      "y=\"",
      T.pack (show (jlY jl)),
      "\" ",
      "width=\"",
      T.pack (show (jlWidth jl)),
      "\" ",
      "height=\"",
      T.pack (show (jlHeight jl)),
      "\"/>\n",
      "    </line>\n"
    ]
renderElement (JRectangle jr) =
  T.concat
    [ "    <rectangle>\n",
      "      <reportElement x=\"",
      T.pack (show (jrX jr)),
      "\" ",
      "y=\"",
      T.pack (show (jrY jr)),
      "\" ",
      "width=\"",
      T.pack (show (jrWidth jr)),
      "\" ",
      "height=\"",
      T.pack (show (jrHeight jr)),
      "\"/>\n",
      "    </rectangle>\n"
    ]
renderElement (JImage ji) =
  T.concat
    [ "    <image>\n",
      "      <reportElement x=\"",
      T.pack (show (jiX ji)),
      "\" ",
      "y=\"",
      T.pack (show (jiY ji)),
      "\" ",
      "width=\"",
      T.pack (show (jiWidth ji)),
      "\" ",
      "height=\"",
      T.pack (show (jiHeight ji)),
      "\"/>\n",
      "      <imageExpression><![CDATA[",
      jiExpression ji,
      "]]></imageExpression>\n",
      "    </image>\n"
    ]
renderElement (JSubreport js) =
  T.concat
    [ "    <subreport>\n",
      "      <reportElement x=\"",
      T.pack (show (jsX js)),
      "\" ",
      "y=\"",
      T.pack (show (jsY js)),
      "\" ",
      "width=\"",
      T.pack (show (jsWidth js)),
      "\" ",
      "height=\"",
      T.pack (show (jsHeight js)),
      "\"/>\n",
      "      <subreportExpression><![CDATA[",
      jsReportExpression js,
      "]]></subreportExpression>\n",
      "    </subreport>\n"
    ]
renderElement (JChart jch) =
  T.concat
    [ "    <",
      jchChartType jch,
      ">\n",
      "      <chart>\n",
      "        <reportElement x=\"",
      T.pack (show (jchX jch)),
      "\" ",
      "y=\"",
      T.pack (show (jchY jch)),
      "\" ",
      "width=\"",
      T.pack (show (jchWidth jch)),
      "\" ",
      "height=\"",
      T.pack (show (jchHeight jch)),
      "\"/>\n",
      "      </chart>\n",
      "    </",
      jchChartType jch,
      ">\n"
    ]

-- ============================================================================
-- EXAMPLE
-- ============================================================================

renderExample :: IO ()
renderExample = do
  let jasper = convertCrystalToJasper exampleCrystalReport
  let xml = renderJasperXml jasper
  TIO.writeFile "example_report.jrxml" xml
  putStrLn "Created example_report.jrxml"
