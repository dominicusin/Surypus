-- |
-- Module      : Domain.Person
-- Description : Domain model for Persons (Counterparties)
-- Copyright   : (c) 2024
-- License     : MIT
--
-- This module defines the domain model for persons/counterparties
-- including validation and normalization functions.
module Domain.Person
  ( -- * Person Entity
    Person(..)
  , PersonFilter(..)
  
    -- * Person Address
  , PersonAddress(..)
  , PersonAddressInput(..)
  , mkPersonAddress
  , validatePersonAddress
  
    -- * Person Contact  
  , PersonContact(..)
  , PersonContactInput(..)
  , mkPersonContact
  , validatePersonContact
  
    -- * Bank Account
  , PersonBankAccount(..)
  , PersonBankAccountInput(..)
  , mkPersonBankAccount
  , validatePersonBankAccount
  
    -- * Aggregations
  , PersonSummary(..)
  , PersonSnapshot(..)
  
    -- * Validation & Normalization
  , normalizePerson
  , validatePerson
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Person type enumeration
data PersonType = PersonTypeLegal     -- ^ Юридическое лицо
                | PersonTypeIndividual -- ^ Физическое лицо  
                | PersonTypeIP        -- ^ Индивидуальный предприниматель
  deriving (Show, Eq)

-- | Person status enumeration
data PersonStatus = PersonStatusActive    -- ^ Активен
                  | PersonStatusBlocked  -- ^ Заблокирован
                  | PersonStatusInactive -- ^ Неактивен
  deriving (Show, Eq)

-- | Main Person entity representing a counterparty
-- 
-- A person can be:
-- * A legal entity (Organization)
-- * An individual
-- * An individual entrepreneur (IP)
--
-- = Example
-- @
-- let person = Person
--     { personId = Nothing
--     , personCode = "P001"
--     , personName = "ООО ТехноСтрой"
--     , personINN = Just "7701234567"
--     , personType = PersonTypeLegal
--     }
-- @
data Person = Person
  { personId          :: Maybe Int64     -- ^ Database ID
  , personCode        :: Text            -- ^ Internal code (unique)
  , personName        :: Text            -- ^ Short name
  , personFullName    :: Maybe Text     -- ^ Full legal name
  , personINN         :: Maybe Text     -- ^ Tax ID (ИНН)
  , personKPP         :: Maybe Text     -- ^ Tax registration reason code (КПП)
  , personOGRN        :: Maybe Text     -- ^ Main state reg number (ОГРН)
  , personType        :: PersonType
  , personStatus     :: PersonStatus
  , personCategory    :: Maybe Int      -- ^ Category ID
  , personPhone       :: Maybe Text
  , personEmail       :: Maybe Text
  , personAddress     :: Maybe Text
  , personContact     :: Maybe Text     -- ^ Contact person name
  , personCreditLimit :: Double         -- ^ Credit limit
  , personDiscount    :: Double         -- ^ Discount percent
  , personMemo        :: Maybe Text
  , personCreatedAt   :: Maybe Day
  , personUpdatedAt   :: Maybe Day
  } deriving (Show, Eq)

-- | Filter for querying persons
data PersonFilter = PersonFilter
  { pfCode      :: Maybe Text     -- ^ Filter by code (partial match)
  , pfName      :: Maybe Text     -- ^ Filter by name (partial match)
  , pfINN       :: Maybe Text     -- ^ Filter by INN
  , pfType      :: Maybe PersonType
  , pfStatus    :: Maybe PersonStatus
  , pfLimit     :: Int            -- ^ Results limit
  , pfOffset    :: Int            -- ^ Results offset
  } deriving (Show, Eq)

-- | Validate person data
-- 
-- Returns 'Left' with error message if validation fails
-- Returns 'Right' with normalized person if valid
validatePerson :: Person -> Either Text Person
validatePerson p = do
  when (T.null (personCode p)) $ Left "Person code is required"
  when (T.null (personName p)) $ Left "Person name is required"
  case personINN p of
    Just inn -> validateINN inn
    Nothing -> pure ()
  pure p

-- | Normalize person data (trim whitespace, etc)
normalizePerson :: Person -> Person
normalizePerson p = p { personCode = T.strip (personCode p)
                    , personName = T.strip (personName p)
                    }

-- Internal validation helpers
validateINN :: Text -> Either Text ()
validateINN inn
  | T.length inn < 10 = Left "INN too short"
  | T.length inn > 12 = Left "INN too long"
  | not (T.all isDigit inn) = Left "INN must contain only digits"
  | otherwise = pure ()

-- Placeholder for KPP validation  
validateKPP :: Text -> Either Text ()
validateKPP kpp
  | T.length kpp /= 9 = Left "KPP must be 9 digits"
  | not (T.all isDigit kpp) = Left "KPP must contain only digits"
  | otherwise = pure ()
