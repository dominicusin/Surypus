{-# LANGUAGE OverloadedStrings #-}
module HR.Person
  ( Person (..),
    PersonFlags (..),
    PersonKind (..),
    PersonStatus (..),
    validateINN,
    validateKPP,
    validatePhone,
    validateEmail
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)

data Person = Person
  { pId :: Int64,
    pCode :: Text,
    pName :: Text,
    pFullName :: Text,
    pShortName :: Text,
    pINN :: Text,
    pKPP :: Text,
    pOKPO :: Text,
    pOKVED :: Text,
    pLegalAddress :: Text,
    pAddress :: Text,
    pPhone :: Text,
    pFax :: Text,
    pEmail :: Text,
    pWWW :: Text,
    pPersonKindId :: Int64,
    pCategoryId :: Int64,
    pStatusId :: Int64,
    pParentId :: Int64,
    pOwnerId :: Int64,
    pRegisterDate :: Day,
    pFlags :: PersonFlags
  }
  deriving (Show, Eq)

data PersonFlags = PersonFlags
  { pfRegistered :: Bool,
    pfLocked :: Bool,
    pfIntrust :: Bool,
    pfVeryLocked :: Bool
  }
  deriving (Show, Eq)

data PersonKind
  = PKCompany
  | PKIndividual
  | PKEntrepreneur
  | PKBank
  | PKSupplier
  | PKCustomer
  | PKEmployee
  deriving (Show, Eq, Enum)

data PersonStatus = PSActive | PSInactive | PSBlocked | PSDeleted
  deriving (Show, Eq, Enum)

validateINN :: Text -> Bool
validateINN inn = T.length inn `elem` [10, 12] && T.all isDigit inn
  where
    isDigit c = c >= '0' && c <= '9'

validateKPP :: Text -> Bool
validateKPP kpp = T.length kpp == 9 && T.all isDigit kpp
  where
    isDigit c = c >= '0' && c <= '9'

validatePhone :: Text -> Bool
validatePhone phone
  | T.null cleaned = False
  | T.length cleaned < 10 = False
  | T.length cleaned > 12 = False
  | otherwise = True
  where
    cleaned = T.filter (`elem` ("0123456789+" :: String)) phone

validateEmail :: Text -> Bool
validateEmail email = T.isInfixOf "@" email && T.isInfixOf "." email