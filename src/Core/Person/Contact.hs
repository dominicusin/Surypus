-- | Contact info types - Addresses, phones, etc.
module Core.Person.Contact where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

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
  = CT_Phone -- Phone
  | CT_Email -- Email
  | CT_URL -- Website
  | CT_ICQ -- ICQ
  | CT_Skype -- Skype
  | CT_Telegram -- Telegram
  | CT_WhatsApp -- WhatsApp
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
  = AT_Legal -- Юридический
  | AT_Physical -- Фактический
  | AT_Mailing -- Почтовый
  | AT_Warehouse -- Склад
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
