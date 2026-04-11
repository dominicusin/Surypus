{-# LANGUAGE MultiParamTypeClasses #-}

module DAL.Repository.User
  ( UserRepository (..),
    mkUserRepository,
    getUserPool,
  )
where

import Hasql.Pool (Pool)

newtype UserRepository = UserRepository
  { urPool :: Pool
  }

mkUserRepository :: Pool -> UserRepository
mkUserRepository pool = UserRepository {urPool = pool}

getUserPool :: UserRepository -> Pool
getUserPool = urPool
