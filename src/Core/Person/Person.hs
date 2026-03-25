-- | Person types - Counterparties
module Core.Person.Person where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)

-- | Person - Counterparty (корреспондент)
data Person = Person
  { pId :: Int64,
    pCode :: Text, -- Internal code
    pName :: Text, -- Short name
    pFullName :: Text, -- Full legal name
    pShortName :: Text, -- Abbreviated name
    pINN :: Text, -- Tax ID (ИНН)
    pKPP :: Text, -- Tax registration reason (КПП)
    pOKPO :: Text, -- OKPO code
    pOKVED :: Text, -- OKVED code (activities)
    pLegalAddress :: Text, -- Legal address
    pAddress :: Text, -- Physical address
    pPhone :: Text,
    pFax :: Text,
    pEmail :: Text,
    pWWW :: Text,
    pPersonKindId :: Int64, -- Person kind
    pCategoryId :: Int64, -- Category
    pStatusId :: Int64, -- Status
    pParentId :: Int64, -- Parent company
    pOwnerId :: Int64, -- Owner/creator
    pRegisterDate :: Day, -- Registration date
    pFlags :: PersonFlags
  }
  deriving (Show, Eq)

-- | Person flags
data PersonFlags = PersonFlags
  { pfRegistered :: Bool, -- Registered
    pfLocked :: Bool, -- Locked
    pfIntrust :: Bool, -- Intrust system
    pfVeryLocked :: Bool -- Very locked
  }
  deriving (Show, Eq)

-- | Person kind - type of counterparty
data PersonKind
  = PKCompany -- Юридическое лицо
  | PKIndividual -- Физическое лицо
  | PKEntrepreneur -- Индивидуальный предприниматель
  | PKBank -- Банк
  | PKSupplier -- Поставщик
  | PKCustomer -- Покупатель
  | PKEmployee -- Сотрудник
  deriving (Show, Eq, Enum)

-- | Person status
data PersonStatus = PSActive | PSInactive | PSBlocked | PSDeleted
  deriving (Show, Eq, Enum)

-- | Validate INN (Tax ID)
validateINN :: Text -> Bool
validateINN inn =
  let digits = filter (`elem` ['0' .. '9']) (T.unpack inn)
      len = length digits
   in case len of
        10 -> True -- Legal entity
        12 -> True -- Individual/entrepreneur
        _ -> False

-- | Validate KPP (Tax registration reason)
validateKPP :: Text -> Bool
validateKPP kpp =
  let digits = filter (`elem` ['0' .. '9']) (T.unpack kpp)
   in length digits == 9
