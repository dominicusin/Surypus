{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Domain.Person
  ( Person(..)
  , PersonFilter(..)
  , PersonAddress(..)
  , PersonAddressInput(..)
  , mkPersonAddress
  , validatePersonAddress
  , PersonContact(..)
  , PersonContactInput(..)
  , mkPersonContact
  , validatePersonContact
  , PersonBankAccount(..)
  , PersonBankAccountInput(..)
  , mkPersonBankAccount
  , validatePersonBankAccount
  , PersonSummary(..)
  , PersonSnapshot(..)
  , normalizePerson
  , validatePerson
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Scientific (Scientific)
import Data.Time.Clock (UTCTime)
import Data.UUID (UUID)
import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)

import Core.Person (validateINN, validateKPP)
import Core.Refined (clampNonNeg, clampPercentage)

{-@ type NonNegDouble = {v:Double | v >= 0} @-}
{-@ type DiscountRate = {v:Double | 0 <= v && v <= 100} @-}
{-@ type NonEmptyText = {v:Text | T.length v > 0} @-}
{-@ type PositivePersonKind = {v:Int | 0 <= v} @-}
{-@ type AddressType = {v:Int | 0 <= v && v <= 3} @-}
{-@ type ContactDigit = {v:Text | T.length v >= 3} @-}
{-@ type BankBIK = {v:Text | T.length v == 9} @-}
{-@ type BankAccountNum = {v:Text | T.length v >= 20} @-}

{-@ data Person = Person
  { personId      :: Maybe Int64
  , personCode    :: Maybe Text
  , personName    :: Text
  , personINN     :: Maybe Text
  , personKPP     :: Maybe Text
  , personKind    :: Int
  , personStatus  :: Int
  , personPhone   :: Maybe Text
  , personEmail   :: Maybe Text
  , personAddress :: Maybe Text
  , personCredit  :: NonNegDouble
  , personDiscount :: DiscountRate
  } @-}
data Person = Person
  { personId      :: Maybe Int64
  , personCode    :: Maybe Text
  , personName    :: Text
  , personINN     :: Maybe Text
  , personKPP     :: Maybe Text
  , personKind    :: Int
  , personStatus  :: Int
  , personPhone   :: Maybe Text
  , personEmail   :: Maybe Text
  , personAddress :: Maybe Text
  , personCredit  :: Double
  , personDiscount :: Double
  } deriving (Eq, Show, Generic)

instance FromJSON Person
instance ToJSON Person

{-@ data PersonFilter = PersonFilter
  { pfName   :: Maybe Text
  , pfINN    :: Maybe Text
  , pfKind   :: Maybe Int
  , pfStatus :: Maybe Int
  } @-}
data PersonFilter = PersonFilter
  { pfName   :: Maybe Text
  , pfINN    :: Maybe Text
  , pfKind   :: Maybe Int
  , pfStatus :: Maybe Int
  } deriving (Eq, Show, Generic)

instance FromJSON PersonFilter
instance ToJSON PersonFilter

data PersonAddress = PersonAddress
  { paId        :: Maybe Int64
  , paPersonId  :: Int64
  , paType      :: Int
  , paCountryId :: Maybe Int64
  , paRegionId  :: Maybe Int64
  , paDistrict  :: Maybe Text
  , paCity      :: Maybe Text
  , paTown      :: Maybe Text
  , paStreet    :: Maybe Text
  , paHouse     :: Maybe Text
  , paFlat      :: Maybe Text
  , paZip       :: Maybe Text
  , paIsDefault :: Bool
  } deriving (Eq, Show, Generic)

data PersonAddressInput = PersonAddressInput
  { paiType      :: Int
  , paiCountryId :: Maybe Int64
  , paiRegionId  :: Maybe Int64
  , paiDistrict  :: Maybe Text
  , paiCity      :: Maybe Text
  , paiTown      :: Maybe Text
  , paiStreet    :: Maybe Text
  , paiHouse     :: Maybe Text
  , paiFlat      :: Maybe Text
  , paiZip       :: Maybe Text
  , paiIsDefault :: Bool
  } deriving (Eq, Show, Generic)

data PersonContact = PersonContact
  { pcId        :: Maybe Int64
  , pcPersonId  :: Int64
  , pcPhone     :: Maybe Text
  , pcPhoneAdd  :: Maybe Text
  , pcEmail     :: Maybe Text
  , pcEmailAdd  :: Maybe Text
  , pcWebsite   :: Maybe Text
  , pcFax       :: Maybe Text
  , pcTelegram  :: Maybe Text
  , pcWhatsapp  :: Maybe Text
  , pcIsDefault :: Bool
  } deriving (Eq, Show, Generic)

data PersonContactInput = PersonContactInput
  { picPhone     :: Maybe Text
  , picPhoneAdd  :: Maybe Text
  , picEmail     :: Maybe Text
  , picEmailAdd  :: Maybe Text
  , picWebsite   :: Maybe Text
  , picFax       :: Maybe Text
  , picTelegram  :: Maybe Text
  , picWhatsapp  :: Maybe Text
  , picIsDefault :: Bool
  } deriving (Eq, Show, Generic)

data PersonBankAccount = PersonBankAccount
  { pbaId          :: Maybe Int64
  , pbaPersonId    :: Int64
  , pbaBankName    :: Text
  , pbaBankBIK     :: Text
  , pbaAccount     :: Text
  , pbaCorrAccount :: Maybe Text
  , pbaIsDefault   :: Bool
  } deriving (Eq, Show, Generic)

data PersonBankAccountInput = PersonBankAccountInput
  { pbiBankName    :: Text
  , pbiBankBIK     :: Text
  , pbiAccount     :: Text
  , pbiCorrAccount :: Maybe Text
  , pbiIsDefault   :: Bool
  } deriving (Eq, Show, Generic)

data PersonSummary = PersonSummary
  { psStatus       :: Int
  , psCategory     :: Int
  , psTotal        :: Int64
  , psCreditLimit  :: Scientific
  , psAvgDiscount  :: Scientific
  } deriving (Eq, Show, Generic)

data PersonSnapshot = PersonSnapshot
  { pssId          :: Int64
  , pssRunId       :: UUID
  , pssRunAt       :: UTCTime
  , pssStatus      :: Int
  , pssCategory    :: Int
  , pssTotal       :: Int64
  , pssCreditLimit :: Scientific
  , pssAvgDiscount :: Scientific
  } deriving (Eq, Show, Generic)

instance FromJSON PersonAddress
instance ToJSON PersonAddress

instance FromJSON PersonAddressInput
instance ToJSON PersonAddressInput

instance FromJSON PersonContact
instance ToJSON PersonContact

instance FromJSON PersonContactInput
instance ToJSON PersonContactInput

instance FromJSON PersonBankAccount
instance ToJSON PersonBankAccount

instance FromJSON PersonBankAccountInput
instance ToJSON PersonBankAccountInput

instance FromJSON PersonSummary
instance ToJSON PersonSummary
 
instance FromJSON PersonSnapshot
instance ToJSON PersonSnapshot

mkPersonAddress :: Int64 -> Maybe Int64 -> PersonAddressInput -> PersonAddress
mkPersonAddress personId mId PersonAddressInput{..} =
  PersonAddress
    { paId = mId
    , paPersonId = personId
    , paType = paiType
    , paCountryId = paiCountryId
    , paRegionId = paiRegionId
    , paDistrict = paiDistrict
    , paCity = paiCity
    , paTown = paiTown
    , paStreet = paiStreet
    , paHouse = paiHouse
    , paFlat = paiFlat
    , paZip = paiZip
    , paIsDefault = paiIsDefault
    }

mkPersonContact :: Int64 -> Maybe Int64 -> PersonContactInput -> PersonContact
mkPersonContact personId mId PersonContactInput{..} =
  PersonContact
    { pcId = mId
    , pcPersonId = personId
    , pcPhone = picPhone
    , pcPhoneAdd = picPhoneAdd
    , pcEmail = picEmail
    , pcEmailAdd = picEmailAdd
    , pcWebsite = picWebsite
    , pcFax = picFax
    , pcTelegram = picTelegram
    , pcWhatsapp = picWhatsapp
    , pcIsDefault = picIsDefault
    }

mkPersonBankAccount :: Int64 -> Maybe Int64 -> PersonBankAccountInput -> PersonBankAccount
mkPersonBankAccount personId mId PersonBankAccountInput{..} =
  PersonBankAccount
    { pbaId = mId
    , pbaPersonId = personId
    , pbaBankName = pbiBankName
    , pbaBankBIK = pbiBankBIK
    , pbaAccount = pbiAccount
    , pbaCorrAccount = pbiCorrAccount
    , pbaIsDefault = pbiIsDefault
    }

validatePersonAddress :: PersonAddress -> Either Text PersonAddress
validatePersonAddress addr@PersonAddress{..}
  | paType < 0 || paType > 3 = Left "invalid address type"
  | not (nonEmpty paStreet) && not (nonEmpty paTown) = Left "address needs at least street or town"
  | otherwise = Right addr

validatePersonContact :: PersonContact -> Either Text PersonContact
validatePersonContact contact@PersonContact{..}
  | allEmpty [pcPhone, pcEmail, pcTelegram, pcWhatsapp] =
      Left "contact must specify at least one channel"
  | not (maybe True (validDigits 3) pcPhone) = Left "phone must be digits"
  | not (maybe True (validDigits 3) pcPhoneAdd) = Left "additional phone must be digits"
  | otherwise = Right contact

validatePersonBankAccount :: PersonBankAccount -> Either Text PersonBankAccount
validatePersonBankAccount ba@PersonBankAccount{..}
  | T.null pbaBankName = Left "bank name cannot be empty"
  | not (validDigits 9 pbaBankBIK) = Left "BIK must be 9 digits"
  | not (validDigits 20 pbaAccount) = Left "account must be at least 20 digits"
  | otherwise = Right ba

allEmpty :: [Maybe Text] -> Bool
allEmpty = all (maybe True T.null)

nonEmpty :: Maybe Text -> Bool
nonEmpty = maybe False (T.length > 0)

validDigits :: Int -> Text -> Bool
validDigits len txt =
  let digits = T.filter (`elem` ['0' .. '9']) txt
   in T.length digits >= len && T.all (`elem` ['0' .. '9']) txt

normalizePerson :: Person -> Person
normalizePerson p@Person{..} =
  p { personCredit = clampNonNeg personCredit
    , personDiscount = clampPercentage personDiscount
    }

validatePerson :: Person -> Either Text Person
validatePerson p@Person{..}
  | personCredit < 0 = Left "credit must be non-negative"
  | personDiscount < 0 = Left "discount must be at least 0%"
  | personDiscount > 100 = Left "discount cannot exceed 100%"
  | T.null personName = Left "name cannot be empty"
  | maybe False T.null personCode = Left "code must be present"
  | maybe False (not . validateINN) personINN = Left "invalid INN format"
  | maybe False (not . validateKPP) personKPP = Left "invalid KPP format"
  | otherwise = Right (normalizePerson p)
