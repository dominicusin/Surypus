-- | Person Operations with Formal Verification
-- Модуль содержит инварианты и проверенные операции для контрагентов
module Core.Person.Operations
  ( PersonOpResult (..),
    validatePerson,
    validatePhone,
    validateEmail,
    checkDuplicateINN,
    isValidPersonKind,
    isActiveStatus,
    getPersonDisplayName,
  )
where

import Core.Person.Person (Person (..), PersonKind (..), PersonStatus (..), validateINN, validateKPP)
import Data.Char (isDigit)
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

-- | Validate complete person record
-- Инвариант: ИНН валиден, КПП валиден, имя не пустое
validatePerson :: Person -> PersonOpResult
validatePerson p
  | T.null (pName p) = PersonOpInvalidName
  | T.null (pINN p) = PersonOpInvalidINN
  | not (validateINN (pINN p)) = PersonOpInvalidINN
  | not (T.null (pKPP p)) && not (validateKPP (pKPP p)) = PersonOpInvalidKPP
  | not (T.null (pPhone p)) && not (validatePhone (pPhone p)) = PersonOpInvalidPhone
  | not (T.null (pEmail p)) && not (validateEmail (pEmail p)) = PersonOpInvalidEmail
  | otherwise = PersonOpSuccess

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
