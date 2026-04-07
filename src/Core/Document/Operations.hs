{-# LANGUAGE OverloadedStrings #-}

-- | Document Operations with Formal Verification
-- Модуль содержит инварианты и проверенные операции для работы с документами
module Core.Document.Operations
  ( DocumentOpResult (..),
    validateDocumentRegister,
    validateDocumentRegisterType,
    validateDocumentOpCounter,
    documentRegisterTypeAllowsDuplicateNumbers,
    documentRegisterTypeForLocation,
    documentRegisterTypeInsertOnCreate,
    documentRegisterTypeOnlyNumber,
    documentRegisterTypeRequiresUnique,
    documentRegisterTypeWarnsAbsence,
    documentRegisterTypeWarnsExpiry,
    documentRegisterTypeHasFlag,
    generateDocumentNumber,
    calcDocumentTotal,
    validateDocumentAmounts,
    checkDocumentDates,
    isDocumentExpired,
    prop_documentTotalNonNeg,
    prop_validateDocumentAmounts,
  )
where

import Core.Document.Types
  ( DocumentOpCounter (..),
    DocumentRegister (..),
    DocumentRegisterFlag (..),
    DocumentRegisterType (..),
  )
import qualified Core.Document.Types as CDT
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import Test.QuickCheck

{-@ type NonNeg = {v:Double | v >= 0} @-}

-- | Document operation result
data DocumentOpResult
  = DocumentOpSuccess
  | DocumentOpInvalidNumber
  | DocumentOpInvalidDate
  | DocumentOpInvalidAmount
  | DocumentOpInvalidType
  | DocumentOpStatusMismatch
  deriving (Show, Eq)

-- ============================================================================
-- VALIDATORS (re-exported from Core.Document.Types for convenience)
-- ============================================================================

-- | Validate document register
-- Инвариант: номер не пустой, дата выдачи не позже срока действия (если задан)
validateDocumentRegister :: DocumentRegister -> Either Text DocumentRegister
validateDocumentRegister = CDT.validateDocumentRegister

-- | Validate document register type
-- Инвариант: название не пустое, код не длиннее 32 символов
validateDocumentRegisterType :: DocumentRegisterType -> Either Text DocumentRegisterType
validateDocumentRegisterType = CDT.validateDocumentRegisterType

-- | Validate document operation counter
-- Инвариант: префикс не длиннее 16 символов
validateDocumentOpCounter :: DocumentOpCounter -> Either Text DocumentOpCounter
validateDocumentOpCounter = CDT.validateDocumentOpCounter

-- | Check if document register type allows duplicate numbers
-- Инвариант: результат - булево значение
documentRegisterTypeAllowsDuplicateNumbers :: DocumentRegisterType -> Bool
documentRegisterTypeAllowsDuplicateNumbers = CDT.documentRegisterTypeAllowsDuplicateNumbers

-- | Check if document register type is for location
-- Инвариант: результат - булево значение
documentRegisterTypeForLocation :: DocumentRegisterType -> Bool
documentRegisterTypeForLocation = CDT.documentRegisterTypeForLocation

-- | Check if document register type inserts on create
-- Инвариант: результат - булево значение
documentRegisterTypeInsertOnCreate :: DocumentRegisterType -> Bool
documentRegisterTypeInsertOnCreate = CDT.documentRegisterTypeInsertOnCreate

-- | Check if document register type only uses number (no series)
-- Инвариант: результат - булево значение
documentRegisterTypeOnlyNumber :: DocumentRegisterType -> Bool
documentRegisterTypeOnlyNumber = CDT.documentRegisterTypeOnlyNumber

-- | Check if document register type requires unique number
-- Инвариант: результат - булево значение
documentRegisterTypeRequiresUnique :: DocumentRegisterType -> Bool
documentRegisterTypeRequiresUnique = CDT.documentRegisterTypeRequiresUnique

-- | Check if document register type warns on absence
-- Инвариант: результат - булево значение
documentRegisterTypeWarnsAbsence :: DocumentRegisterType -> Bool
documentRegisterTypeWarnsAbsence = CDT.documentRegisterTypeWarnsAbsence

-- | Check if document register type warns on expiry
-- Инвариант: результат - булево значение
documentRegisterTypeWarnsExpiry :: DocumentRegisterType -> Bool
documentRegisterTypeWarnsExpiry = CDT.documentRegisterTypeWarnsExpiry

-- | Check if document register type has flag
-- Инвариант: результат - булево значение
documentRegisterTypeHasFlag :: DocumentRegisterType -> DocumentRegisterFlag -> Bool
documentRegisterTypeHasFlag = CDT.documentRegisterTypeHasFlag

-- ============================================================================
-- DOCUMENT OPERATIONS
-- ============================================================================

-- | Generate document number based on type and counter
-- Инвариант: результат не пустой
generateDocumentNumber :: DocumentRegisterType -> Maybe Text -> Int -> Text
generateDocumentNumber drt seriesCounter counter =
  let series = fromMaybe "" seriesCounter
      number = T.pack (show counter)
      prefix = case drtCode drt of
        Just c -> c <> "-"
        Nothing -> ""
   in if documentRegisterTypeOnlyNumber drt
        then number
        else
          if T.null series
            then prefix <> number
            else prefix <> series <> "-" <> number

-- | Calculate document total from lines
-- Инвариант: результат >= 0
calcDocumentTotal :: [(Double, Double, Double)] -> Double
calcDocumentTotal docLines' = sum $ fmap (\(price, qty, discount) -> (price * qty) - discount) docLines'

-- | Validate document amounts
-- Инвариант: сумма >= 0, НДС >= 0 и <= сумма, скидка >= 0 и <= сумма
validateDocumentAmounts :: Double -> Double -> Double -> DocumentOpResult
validateDocumentAmounts docTotal vat discount
  | docTotal < 0 = DocumentOpInvalidAmount
  | vat < 0 = DocumentOpInvalidAmount
  | vat > docTotal = DocumentOpInvalidAmount
  | discount < 0 = DocumentOpInvalidAmount
  | discount > docTotal = DocumentOpInvalidAmount
  | otherwise = DocumentOpSuccess

-- | Check document dates
-- Инвариант: дата expiry >= дата issue (если expiry задан)
checkDocumentDates :: Day -> Maybe Day -> DocumentOpResult
checkDocumentDates issueDate maybeExpiryDate =
  case maybeExpiryDate of
    Just expiryDate
      | expiryDate < issueDate -> DocumentOpInvalidDate
      | otherwise -> DocumentOpSuccess
    Nothing -> DocumentOpSuccess

-- | Check if document is expired
-- Инвариант: результат - булево значение
isDocumentExpired :: DocumentRegister -> Day -> Bool
isDocumentExpired doc today =
  case drExpiryDate doc of
    Just expiryDate -> today > expiryDate
    Nothing -> False

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

-- | Property: document total is non-negative
prop_documentTotalNonNeg :: Property
prop_documentTotalNonNeg =
  forAll (listOf docLineGen `suchThat` (not . null)) $ \docLines ->
    calcDocumentTotal docLines >= 0

-- | Property: validateDocumentAmounts returns success for valid amounts
prop_validateDocumentAmounts :: Property
prop_validateDocumentAmounts =
  forAll docAmountGen $ \amtTuple ->
    let (docTotal, vat, discount) = amtTuple
     in validateDocumentAmounts docTotal vat discount == DocumentOpSuccess

docLineGen :: Gen (Double, Double, Double)
docLineGen = do
  p <- suchThat arbitrary (> 0)
  q <- suchThat arbitrary (> 0)
  d <- choose (0, p * q)
  pure (p, q, d)

docAmountGen :: Gen (Double, Double, Double)
docAmountGen = do
  docTotal <- suchThat arbitrary (> 0)
  vat <- choose (0, docTotal)
  discount <- choose (0, docTotal)
  pure (docTotal, vat, discount)
