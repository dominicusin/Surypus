-- | Person Module - Counterparties (corresponds to PersonCore in OpenPapyrus)
-- Re-exports all person-related types
module Core.Person
  ( module Core.Person.Person,
    module Core.Person.Contact,
    module Core.Person.Relation,
    module Core.Person.Operations,
  )
where

import Core.Person.Contact
import Core.Person.Operations
import Core.Person.Person
import Core.Person.Relation
