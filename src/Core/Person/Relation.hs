-- | Person relations - Relationships between persons
module Core.Person.Relation where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Person relation - Relationship between two persons
data PersonRelation = PersonRelation
  { prId :: Int64,
    prPersonId :: Int64, -- Source person
    prRelType :: RelationType,
    prRelatedPersonId :: Int64, -- Target person
    prFlags :: Int
  }
  deriving (Show, Eq)

-- | Relation type
data RelationType
  = RTOwner -- Owner (владелец)
  | RTParent -- Parent company (родитель)
  | RTSubsidiary -- Subsidiary (дочерняя)
  | RTBranch -- Branch (филиал)
  | RTHead -- Head office (головной офис)
  | RTAgent -- Agent (агент)
  | RTContractor -- Contractor (контрагент)
  deriving (Show, Eq, Enum)

-- | Person event - Historical events for person
data PersonEvent = PersonEvent
  { peId :: Int64,
    pePersonId :: Int64,
    peType :: EventType,
    peDate :: Day,
    peDescription :: Text,
    peFlags :: Int
  }
  deriving (Show, Eq)

-- | Event type
data EventType
  = ETRegistered -- Registered
  | ETUpdated -- Info updated
  | ETStatusChanged -- Status changed
  | ETContact -- Contact added
  | ETContract -- Contract signed
  deriving (Show, Eq, Enum)
