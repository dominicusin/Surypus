-- | DB Person - simplified for build
module DB.Person
  ( listPersons,
    getPerson,
    createPerson,
    updatePerson,
    deletePerson,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Domain.Person (Person (..))
import Domain.Types
import Hasql.Pool (Pool)

listPersons :: Pool -> IO [Person]
listPersons _ = pure []

getPerson :: Pool -> Int64 -> IO (Maybe Person)
getPerson _ _ = pure Nothing

createPerson :: Pool -> Person -> IO Int64
createPerson _ _ = pure 0

updatePerson :: Pool -> Int64 -> Person -> IO Bool
updatePerson _ _ _ = pure False

deletePerson :: Pool -> Int64 -> IO Bool
deletePerson _ _ = pure False
