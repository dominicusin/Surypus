-- | Person Module - Counterparties (corresponds to PersonCore in OpenPapyrus)
module Core.Person where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import Test.QuickCheck

-- ============================================================================
-- PERSON TYPES (correspond to PersonTbl::Rec)
-- ============================================================================

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

-- | Person kinds
data PersonKind = PK_Company | PK_Individual | PK_Entrepreneur | PK_Bank | PK_Supplier | PK_Customer | PK_Employee
  deriving (Show, Eq)

-- | Person status
data PersonStatus = PS_Active | PS_Inactive | PS_Blocked | PS_Deleted
  deriving (Show, Eq)

-- | Person category
data PersonCategory = PC_Buyer | PC_Supplier | PC_Agent | PC_Transporter | PC_Bank
  deriving (Show, Eq)

-- ============================================================================
-- PERSON RELATIONS
-- ============================================================================

data PersonRel = PersonRel
  { prId :: Int64,
    prPersonId :: Int64,
    prRelPersonId :: Int64,
    prRelTypeId :: Int64
  }
  deriving (Show, Eq)

data PersonRelType = PRT_Owner | PRT_Subsidiary | PRT_Head | PRT_Branch
  deriving (Show, Eq)

-- ============================================================================
-- PERSON LOCATION (address)
-- ============================================================================

data PersonLocation = PersonLocation
  { plId :: Int64,
    plPersonId :: Int64,
    plLocationId :: Int64,
    plAddress :: Text,
    plIsPrimary :: Bool,
    plFlags :: Int
  }
  deriving (Show, Eq)

-- ============================================================================
-- PERSON CONTACT
-- ============================================================================

data PersonContact = PersonContact
  { pcId :: Int64,
    pcPersonId :: Int64,
    pcType :: ContactType,
    pcValue :: Text,
    pcIsPrimary :: Bool
  }
  deriving (Show, Eq)

data ContactType = CT_Phone | CT_Email | CT_ICQ | CT_Skype | CT_Telegram | CT_Other
  deriving (Show, Eq)

-- ============================================================================
-- ARTICLE (internal account)
-- ============================================================================

data Article = Article
  { arId :: Int64,
    arPersonId :: Int64,
    arAccountId :: Int64,
    arArticleType :: ArticleType,
    arCode :: Text,
    arName :: Text
  }
  deriving (Show, Eq)

data ArticleType = AT_Agent | AT_Employee | AT_Mol | AT_Owner
  deriving (Show, Eq)

-- ============================================================================
-- VALIDATION FUNCTIONS
-- ============================================================================

validateINN :: Text -> Bool
validateINN inn =
  let digits = T.filter (`elem` ['0' .. '9']) inn
      len = T.length digits
   in (len == 10 || len == 12) && T.all (`elem` ['0' .. '9']) inn

validateKPP :: Text -> Bool
validateKPP kpp =
  let digits = T.filter (`elem` ['0' .. '9']) kpp
   in T.length digits == 9 && T.all (`elem` ['0' .. '9']) kpp

validatePerson :: Person -> Bool
validatePerson p = validateINN (pINN p)

validateAddress :: Text -> Bool
validateAddress addr = T.length addr > 0

-- ============================================================================
-- CALCULATION FUNCTIONS
-- ============================================================================

formatAddress :: PersonLocation -> Text
formatAddress loc = plAddress loc

getPrimaryContact :: [PersonContact] -> Maybe PersonContact
getPrimaryContact contacts =
  case filter pcIsPrimary contacts of
    (c : _) -> Just c
    _ -> Nothing
