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
  = RT_Owner -- Owner (владелец)
  | RT_Parent -- Parent company (родитель)
  | RT_Subsidiary -- Subsidiary (дочерняя)
  | RT_Branch -- Branch (филиал)
  | RT_Head -- Head office (головной офис)
  | RT_Agent -- Agent (агент)
  | RT_Contractor -- Contractor (контрагент)
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
  = ET_Registered -- Registered
  | ET_Updated -- Info updated
  | ET_StatusChanged -- Status changed
  | ET_Contact -- Contact added
  | ET_Contract -- Contract signed
  deriving (Show, Eq, Enum)
