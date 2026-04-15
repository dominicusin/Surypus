{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

module DAL.Repository
  ( AppError (..),
    RepositoryError (..),
    HasRepository (..),
    RepositoryT,
    Id,
    isNotFoundMessage,
    module DAL.Types,
  )
where

import Control.Monad.Trans.Except (ExceptT)
import DAL.Types (Pagination (..))
import Data.Text (Text)
import qualified Data.Text as T

data AppError = AppError Text deriving (Show, Eq)

data RepositoryError
  = NotFound Text
  | DatabaseError Text
  | ValidationError Text
  | ConstraintError Text
  deriving (Show, Eq)

class HasRepository repo pool | repo -> pool where
  getPool :: repo -> pool

type RepositoryT m a = ExceptT RepositoryError m a

type family Id entity

isNotFoundMessage :: Text -> Bool
isNotFoundMessage msg = T.isInfixOf (T.pack "not found") (T.toLower msg)
