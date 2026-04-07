{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

module DAL.Repository.Person
  ( PersonRepo,
    Id,
  )
where

import DAL.Repository (AppError (..), Id)
import DAL.Types (Person (..))
import Data.Int (Int64)
import qualified Data.Text as T
import Hasql.Pool (Pool)

data PersonRepo = PersonRepo

type instance Id PersonRepo = Int64

personFindById :: Pool -> Int64 -> IO (Either AppError (Maybe Person))
personFindById _pool _id = return (Left (AppError (T.pack "Not implemented")))
