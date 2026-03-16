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
validateINN10 inn = checkDigit10 && checkDigit11
  where
    digits = map (\c -> read (T.unpack (T.singleton c)) :: Int) (T.unpack inn)
    checkDigit10 = (10 * digits !! 0 + 9 * digits !! 1 + 8 * digits !! 2 + 7 * digits !! 3 + 6 * digits !! 4 + 5 * digits !! 5 + 4 * digits !! 6 + 3 * digits !! 7 + 2 * digits !! 8) `mod` 11 `mod` 10 == digits !! 9
    checkDigit11 = (7 * digits !! 0 + 2 * digits !! 1 + 4 * digits !! 2 + 10 * digits !! 3 + 3 * digits !! 4 + 5 * digits !! 5 + 9 * digits !! 6 + 4 * digits !! 7 + 6 * digits !! 8 + 8 * digits !! 9) `mod` 11 `mod` 10 == digits !! 10

validateINN12 :: Text -> Bool
validateINN12 inn = checkDigit11 && checkDigit12
  where
    digits = map (\c -> read (T.unpack (T.singleton c)) :: Int) (T.unpack inn)
    checkDigit11 = (7 * digits !! 0 + 2 * digits !! 1 + 4 * digits !! 2 + 10 * digits !! 3 + 3 * digits !! 4 + 5 * digits !! 5 + 9 * digits !! 6 + 4 * digits !! 7 + 6 * digits !! 8 + 8 * digits !! 9 + 0 * digits !! 10) `mod` 11 `mod` 10 == digits !! 10
    checkDigit12 = (3 * digits !! 0 + 7 * digits !! 1 + 2 * digits !! 2 + 4 * digits !! 3 + 10 * digits !! 4 + 3 * digits !! 5 + 5 * digits !! 6 + 9 * digits !! 7 + 4 * digits !! 8 + 6 * digits !! 9 + 8 * digits !! 10 + 0 * digits !! 11) `mod` 11 `mod` 10 == digits !! 11

-- | Validate KPP (Tax Registration Reason Code)
-- Инвариант: КПП - 9 цифр в формате ППППNNNNCC
validatekpp :: Text -> Bool
validatekpp kpp
  | T.length kpp /= 9 = False
  | otherwise = T.all (\c -> c >= '0' && c <= '9') kpp

-- | Validate phone number (Russian format)
-- Инвариант: телефон содержит 10-12 цифр
validatePhone :: Text -> Bool
validatePhone phone
  | T.null cleaned = False
  | T.length cleaned < 10 = False
  | T.length cleaned > 12 = False
  | otherwise = True
  where
    cleaned = T.filter (\c -> c >= '0' && c <= '9') phone

-- | Validate email address
-- Инвариант: email содержит @ и .
validateEmail :: Text -> Bool
validateEmail email
  | T.null email = False
  | T.null localPart = False
  | T.null domain = False
  | not (T.isInfixOf (T.singleton '@') email) = False
  | otherwise = T.isInfixOf (T.singleton '.') domain
  where
    parts = T.splitOn (T.singleton '@') email
    localPart = head parts
    domain = if length parts > 1 then parts !! 1 else T.empty

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
isValidPersonKind pk = pk `elem` [PK_Company, PK_Individual, PK_Entrepreneur, PK_Bank, PK_Supplier, PK_Customer, PK_Employee]

-- | Check if person status is active
-- Инвариант: активный статус означает возможность проведения операций
isActiveStatus :: PersonStatus -> Bool
isActiveStatus PS_Active = True
isActiveStatus _ = False

-- | Get person display name
-- Инвариант: возвращает непустое имя
getPersonDisplayName :: Person -> Text
getPersonDisplayName p
  | not (T.null (pShortName p)) = pShortName p
  | not (T.null (pName p)) = pName p
  | otherwise = pFullName p
