{-# LANGUAGE MultiParamTypeClasses #-}

module DAL.Repository.User
  ( UserRepository,
    mkUserRepository,
  )
where

import Hasql.Pool (Pool)

newtype UserRepository = UserRepository
  { urPool :: Pool
  }

mkUserRepository :: Pool -> UserRepository
mkUserRepository = UserRepository
