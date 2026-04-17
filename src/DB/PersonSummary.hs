{-# LANGUAGE OverloadedStrings #-}

module DB.PersonSummary
  ( PersonSummary (..),
    listPersonSummary,
  )
where

import Data.Int (Int64)
import Domain.Person (PersonSummary (..))
import Hasql.Pool (Pool)

listPersonSummary :: Pool -> IO [PersonSummary]
listPersonSummary _ = pure []
