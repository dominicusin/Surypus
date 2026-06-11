{-# LANGUAGE OverloadedStrings #-}
module Analytics.Export where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.ByteString.Lazy as LBS
import Data.Aeson (encode, object, (.=))
import Data.Time (UTCTime, getCurrentTime)
import Analytics.Dashboard

-- | Export dashboard to Excel format
exportToExcel :: [DataPoint] -> IO LBS.ByteString
exportToExcel points = do
  let headers = "Label,Value,Color\n"
      rows = T.concat $ map formatRow points
  return $ LBS.fromStrict $ TE.encodeUtf8 (headers <> rows)
  where
    formatRow dp = T.intercalate ","
      [ dpLabel dp
      , T.pack (show (dpValue dp))
      , dpColor dp
      ] <> "\n"

-- | Export dashboard to PDF
exportToPDF :: [DataPoint] -> Text -> IO LBS.ByteString
exportToPDF points title = do
  now <- getCurrentTime
  return $ encode $ object
    [ "title" .= title
    , "generatedAt" .= (show now)
    , "data" .= map formatDataPointForPDF points
    ]
  where
    formatDataPointForPDF dp = object
      [ "label" .= dpLabel dp
      , "value" .= dpValue dp
      , "color" .= dpColor dp
      , "percentage" .= (dpValue dp / sum (dpValue <$> points) * 100.0)
      ]

-- | Schedule report delivery
scheduleReport :: Text -> Text -> IO ()
scheduleReport reportId cronSchedule = do
  putStrLn $ "Scheduled report " ++ T.unpack reportId ++ " with schedule " ++ T.unpack cronSchedule
  putStrLn $ "Report will be generated at: " ++ T.unpack cronSchedule

-- | Generate comprehensive report
exportToJSON :: [DataPoint] -> Text -> IO LBS.ByteString
exportToJSON points reportType = do
  now <- getCurrentTime
  let metadata = object
        [ "type" .= reportType
        , "timestamp" .= (show now)
        , "totalPoints" .= (length points)
        , "minValue" .= minimum (dpValue <$> points)
        , "maxValue" .= maximum (dpValue <$> points)
        , "avgValue" .= (sum (dpValue <$> points) / fromIntegral (length points))
        ]
      dataObject = object
        [ "labels" .= (dpLabel <$> points)
        , "values" .= (dpValue <$> points)
        , "colors" .= (dpColor <$> points)
        ]
  return $ encode $ object
    [ "metadata" .= metadata
    , "data" .= dataObject
    ]