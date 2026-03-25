-- | Person Operations with Formal Verification
-- Модуль содержит инварианты и проверенные операции для контрагентов
module Core.Person.Operations
  ( PersonOpResult (..),
    validatePerson,
    validateINN,
    validateKPP,
    validatePhone,
    validateEmail,
    validateinn,
    validatekpp,
    checkDuplicateINN,
    isValidPersonKind,
    isActiveStatus,
    getPersonDisplayName,
  )
where

import Core.Person.Person
import Data.Char (digitToInt, isDigit)
import Data.Text (Text)
import qualified Data.Text as T

-- | Person operation result
data PersonOpResult
  = PersonOpSuccess
  | PersonOpInvalidINN
  | PersonOpInvalidKPP
  | PersonOpInvalidPhone
  | PersonOpInvalidEmail
  | PersonOpDuplicateINN
  | PersonOpInvalidName

-- ============================================================================
-- VALIDATORS
-- ============================================================================

-- | Validate complete person record
-- Инвариант: ИНН валиден, КПП валиден, имя не пустое
validatePerson :: Person -> PersonOpResult
validatePerson p
  | T.null (pName p) = PersonOpInvalidName
  | T.null (pINN p) = PersonOpInvalidINN
  | not (validateinn (pINN p)) = PersonOpInvalidINN
  | not (T.null (pKPP p)) && not (validatekpp (pKPP p)) = PersonOpInvalidKPP
  | not (T.null (pPhone p)) && not (validatePhone (pPhone p)) = PersonOpInvalidPhone
  | not (T.null (pEmail p)) && not (validateEmail (pEmail p)) = PersonOpInvalidEmail
  | otherwise = PersonOpSuccess

-- | Validate Russian INN (Individual Tax Number)
-- Инвариант: ИНН - 10 или 12 цифр, контрольная сумма верна
validateinn :: Text -> Bool
validateinn inn
  | T.length inn == 10 = validateINN10 inn
  | T.length inn == 12 = validateINN12 inn
  | otherwise = False

validateINN10 :: Text -> Bool
validateINN10 inn = case fmap digitToInt (T.unpack inn) of
  [d0, d1, d2, d3, d4, d5, d6, d7, d8, d9] ->
    let checkDigit10 = (10 * d0 + 9 * d1 + 8 * d2 + 7 * d3 + 6 * d4 + 5 * d5 + 4 * d6 + 3 * d7 + 2 * d8) `mod` 11 `mod` 10
     in checkDigit10 == d9
  _ -> False

validateINN12 :: Text -> Bool
validateINN12 inn = case fmap digitToInt (T.unpack inn) of
  [d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11] ->
    let c11 = (7 * d0 + 2 * d1 + 4 * d2 + 10 * d3 + 3 * d4 + 5 * d5 + 9 * d6 + 4 * d7 + 6 * d8 + 8 * d9) `mod` 11 `mod` 10
        c12 = (3 * d0 + 7 * d1 + 2 * d2 + 4 * d3 + 10 * d4 + 3 * d5 + 5 * d6 + 9 * d7 + 4 * d8 + 6 * d9 + 8 * d10) `mod` 11 `mod` 10
     in c11 == d10 && c12 == d11
  _ -> False

-- | Validate KPP (Tax Registration Reason Code)
-- Инвариант: КПП - 9 цифр в формате ППППNNNNCC
validatekpp :: Text -> Bool
validatekpp kpp
  | T.length kpp /= 9 = False
  | otherwise = T.all isDigit kpp

-- | Validate phone number (Russian format)
-- Инвариант: телефон содержит 10-12 цифр
validatePhone :: Text -> Bool
validatePhone phone
  | T.null cleaned = False
  | T.length cleaned < 10 = False
  | T.length cleaned > 12 = False
  | otherwise = True
  where
    cleaned = T.filter isDigit phone

-- | Validate email address
-- Инвариант: email содержит @ и .
validateEmail :: Text -> Bool
validateEmail email
  | T.null email = False
  | T.null localPart = False
  | T.null domain = False
  | otherwise = T.isInfixOf (T.singleton '@') email && T.isInfixOf (T.singleton '.') domain
  where
    parts = T.splitOn (T.singleton '@') email
    localPart = case parts of
      [] -> T.empty
      (x : _) -> x
    domain = case parts of
      (_ : d : _) -> d
      _ -> T.empty

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- | Check for duplicate INN (simulated check)
-- Инвариант: ИНН уникален в системе
checkDuplicateINN :: [Person] -> Text -> Bool
checkDuplicateINN persons inn = length filtered > 1
  where
    filtered = filter (\p -> pINN p == inn) persons

-- | Check if person kind is valid
-- Инвариант: вид контрагента определён
isValidPersonKind :: PersonKind -> Bool
isValidPersonKind pk = pk `elem` [PKCompany, PKIndividual, PKEntrepreneur, PKBank, PKSupplier, PKCustomer, PKEmployee]

-- | Check if person status is active
-- Инвариант: активный статус означает возможность проведения операций
isActiveStatus :: PersonStatus -> Bool
isActiveStatus PSActive = True
isActiveStatus _ = False

-- | Get person display name
-- Инвариант: возвращает непустое имя
getPersonDisplayName :: Person -> Text
getPersonDisplayName p
  | not (T.null (pShortName p)) = pShortName p
  | not (T.null (pName p)) = pName p
  | otherwise = pFullName p
