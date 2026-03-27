-- | Contact info types - Addresses, phones, etc.
module Core.Person.Contact where

import Data.Int (Int64)
import Data.Text (Text)

-- | Contact - Contact information for person
data Contact = Contact
  { cId :: Int64,
    cPersonId :: Int64,
    cType :: ContactType,
    cValue :: Text,
    cIsPrimary :: Bool,
    cFlags :: Int
  }
  deriving (Show, Eq)

-- | Contact type
data ContactType
  = CTPhone -- Phone
  | CTEmail -- Email
  | CTURL -- Website
  | CTICQ -- ICQ
  | CTSkype -- Skype
  | CTTelegram -- Telegram
  | CTWhatsApp -- WhatsApp
  deriving (Show, Eq, Enum)

-- | Address - Postal address
data Address = Address
  { aId :: Int64,
    aPersonId :: Int64,
    aType :: AddressType,
    aCountryId :: Int64,
    aRegionId :: Int64,
    aCityId :: Int64,
    aStreet :: Text,
    aHouse :: Text,
    aFlat :: Text,
    aPostalCode :: Text,
    aIsPrimary :: Bool
  }
  deriving (Show, Eq)

-- | Address type
data AddressType
  = ATLegal -- Юридический
  | ATPhysical -- Фактический
  | ATMailing -- Почтовый
  | ATWarehouse -- Склад
  deriving (Show, Eq, Enum)

-- | Bank account
data BankAccount = BankAccount
  { baId :: Int64,
    baPersonId :: Int64,
    baBankName :: Text,
    baAccount :: Text, -- Account number
    baCorrAccount :: Text, -- Correspondent account
    baBIC :: Text, -- Bank ID
    baIsPrimary :: Bool
  }
  deriving (Show, Eq)
