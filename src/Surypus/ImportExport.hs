{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.ImportExport
  ( CSVConfig (..),
    ExportResult (..),
    ImportResult (..),
    exportToCSV,
    exportGoodsToCSV,
    exportPersonsToCSV,
    exportBillsToCSV,
    importFromCSV,
    importGoodsFromCSV,
    importPersonsFromCSV,
    parseCSVLine,
    encodeCSVLine,
    defaultCSVConfig,
  )
where

import Control.Monad (foldM, forM, forM_)
import Data.Csv (DefaultOrdered (..), FromNamedRecord, ToNamedRecord (..), header, toNamedRecord, (.=))
import qualified Data.Csv as Csv
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Vector (Vector)
import qualified Data.Vector as V
import Text.Read (readMaybe)

data CSVConfig = CSVConfig
  { csvDelimiter :: !Char,
    csvHasHeader :: !Bool,
    csvEncoding :: !Text,
    csvSkipEmpty :: !Bool
  }

defaultCSVConfig :: CSVConfig
defaultCSVConfig =
  CSVConfig
    { csvDelimiter = ';',
      csvHasHeader = True,
      csvEncoding = "UTF-8",
      csvSkipEmpty = True
    }

data ExportResult = ExportResult
  { exportSuccess :: !Bool,
    exportFilePath :: !Text,
    exportRecordCount :: !Int,
    exportError :: !(Maybe Text)
  }

data ImportResult = ImportResult
  { importSuccess :: !Bool,
    importRecordCount :: !Int,
    importErrors :: ![Text],
    importSkipped :: !Int
  }

parseCSVLine :: Char -> Text -> Maybe (Vector Text)
parseCSVLine delimiter line =
  let parts = T.splitOn (T.singleton delimiter) line
   in if null parts
        then Nothing
        else
          let cleaned = fmap (T.strip . removeQuotes) parts
           in Just $ V.fromList cleaned
  where
    removeQuotes t =
      case (T.uncons t, T.unsnoc t) of
        (Just ('"', _), Just (_, '"')) -> T.init (T.tail t)
        _ -> t

encodeCSVLine :: Char -> [Text] -> Text
encodeCSVLine delimiter fields =
  T.intercalate (T.singleton delimiter) $
    fmap
      ( \case
          t
            | T.isInfixOf "\"" t
                || T.isInfixOf (T.singleton delimiter) t
                || T.isInfixOf "\n" t ->
                "\"" <> T.replace "\"" "\"\"" t <> "\""
            | otherwise -> t
      )
      fields

exportToCSV :: (ToNamedRecord a, DefaultOrdered a) => CSVConfig -> FilePath -> [a] -> IO ExportResult
exportToCSV config filePath records = do
  let options =
        Csv.defaultOptions
          { Csv.delimiter = fromEnum (csvDelimiter config)
          }
  case records of
    [] ->
      pure $
        ExportResult
          { exportSuccess = False,
            exportFilePath = T.pack filePath,
            exportRecordCount = 0,
            exportError = Just "No records to export"
          }
    (firstRecord : _) -> do
      let csvData = Csv.encodeByNameOrdered (header (V.toList (Csv.headerOrder firstRecord))) records
      TIO.writeFile filePath (Csv.toLazyByteString csvData)
      pure $
        ExportResult
          { exportSuccess = True,
            exportFilePath = T.pack filePath,
            exportRecordCount = length records,
            exportError = Nothing
          }

exportGoodsToCSV :: CSVConfig -> FilePath -> [(Text, Text, Text, Text, Text)] -> IO ExportResult
exportGoodsToCSV config filePath goods =
  let headerLine = encodeCSVLine (csvDelimiter config) ["Код", "Наименование", "Ед.изм", "Цена", "Остаток"]
      lines = headerLine : fmap (encodeCSVLine (csvDelimiter config) fields) goods
      fields (code, name, unit, price, qty) = [code, name, unit, price, qty]
   in do
        TIO.writeFile filePath (T.unlines lines)
        pure $
          ExportResult
            { exportSuccess = True,
              exportFilePath = T.pack filePath,
              exportRecordCount = length goods,
              exportError = Nothing
            }

exportPersonsToCSV :: CSVConfig -> FilePath -> [(Text, Text, Text, Text, Text, Text)] -> IO ExportResult
exportPersonsToCSV config filePath persons =
  let headerLine = encodeCSVLine (csvDelimiter config) ["Код", "Наименование", "ИНН", "Тип", "Телефон", "Email"]
      lines = headerLine : fmap (encodeCSVLine (csvDelimiter config) fields) persons
      fields (code, name, inn, ptype, phone, email) = [code, name, inn, ptype, phone, email]
   in do
        TIO.writeFile filePath (T.unlines lines)
        pure $
          ExportResult
            { exportSuccess = True,
              exportFilePath = T.pack filePath,
              exportRecordCount = length persons,
              exportError = Nothing
            }

exportBillsToCSV :: CSVConfig -> FilePath -> [(Text, Text, Text, Text, Text, Text)] -> IO ExportResult
exportBillsToCSV config filePath bills =
  let headerLine = encodeCSVLine (csvDelimiter config) ["Номер", "Дата", "Тип", "Контрагент", "Сумма", "Статус"]
      lines = headerLine : fmap (encodeCSVLine (csvDelimiter config) fields) bills
      fields (num, date, btype, person, total, status) = [num, date, btype, person, total, status]
   in do
        TIO.writeFile filePath (T.unlines lines)
        pure $
          ExportResult
            { exportSuccess = True,
              exportFilePath = T.pack filePath,
              exportRecordCount = length bills,
              exportError = Nothing
            }

importFromCSV :: CSVConfig -> FilePath -> (Vector Text -> Either Text a) -> IO ImportResult
importFromCSV config filePath parser = do
  content <- TIO.readFile filePath
  let allLines = T.lines content
      linesToProcess =
        if csvHasHeader config
          then drop 1 allLines
          else allLines
      filteredLines =
        if csvSkipEmpty config
          then filter (not . T.null . T.strip) linesToProcess
          else linesToProcess

  (successes, errors, skipped) <- foldM processLine ([], [], 0) filteredLines

  pure $
    ImportResult
      { importSuccess = null errors,
        importRecordCount = length successes,
        importErrors = errors,
        importSkipped = skipped
      }
  where
    processLine (accOk, accErr, accSkip) line = do
      case parseCSVLine (csvDelimiter config) line of
        Nothing -> pure (accOk, "Failed to parse CSV line" : accErr, accSkip + 1)
        Just fields ->
          case parser fields of
            Left err -> pure (accOk, err : accErr, accSkip + 1)
            Right record -> pure (record : accOk, accErr, accSkip)

importGoodsFromCSV :: CSVConfig -> FilePath -> IO ImportResult
importGoodsFromCSV config filePath =
  importFromCSV config filePath $ \fields ->
    if V.length fields < 5
      then Left "Недостаточно полей"
      else
        let code = fields V.! 0
            name = fields V.! 1
            unit = fields V.! 2
            price = fields V.! 3
            qty = fields V.! 4
         in if T.null code || T.null name
              then Left "Код и наименование обязательны"
              else case (readMaybe (T.unpack price) :: Maybe Double) of
                Nothing -> Left "Неверная цена"
                Just _ ->
                  case readMaybe (T.unpack qty) :: Maybe Double of
                    Nothing -> Left "Неверное количество"
                    Just _ -> Right (code, name, unit, price, qty)

importPersonsFromCSV :: CSVConfig -> FilePath -> IO ImportResult
importPersonsFromCSV config filePath =
  importFromCSV config filePath $ \fields ->
    if V.length fields < 2
      then Left "Недостаточно полей"
      else
        let code = fields V.! 0
            name = fields V.! 1
            inn = if V.length fields > 2 then fields V.! 2 else ""
            ptype = if V.length fields > 3 then fields V.! 3 else "Юр. лицо"
         in if T.null code || T.null name
              then Left "Код и наименование обязательны"
              else Right (code, name, inn, ptype)

validateRequired :: Text -> Maybe Text
validateRequired t
  | T.null (T.strip t) = Just "Обязательное поле"
  | otherwise = Nothing

validateINN :: Text -> Maybe Text
validateINN t
  | T.null t = Nothing
  | T.length t < 10 || T.length t > 12 = Just "ИНН должен быть 10-12 символов"
  | T.all isDigit t = Nothing
  | otherwise = Just "ИНН должен содержать только цифры"

validatePhone :: Text -> Maybe Text
validatePhone t
  | T.null t = Nothing
  | T.length t < 7 = Just "Слишком короткий номер"
  | otherwise = Nothing
