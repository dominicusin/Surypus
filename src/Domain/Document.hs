{-# LANGUAGE DeriveGeneric #-}

module Domain.Document
  ( DocumentRegisterFilter(..)
  , documentRegisterStatusAsOf
  , documentRegisterStatus
  ) where

import Core.Document.Types
  ( DocumentRegister(..)
  , DocumentRegisterStatus(..)
  )
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, getCurrentTime, utctDay)

-- | Filters for listing document registers
data DocumentRegisterFilter = DocumentRegisterFilter
  { drfPersonId :: Maybe Int64
  , drfTypeId   :: Maybe Int64
  , drfNumber   :: Maybe Text
  }
  deriving (Eq, Show)

documentRegisterStatusAsOf :: Day -> DocumentRegister -> DocumentRegisterStatus
documentRegisterStatusAsOf today doc =
  case drExpiryDate doc of
    Nothing -> DocumentStatusUnlimited
    Just expiry
      | expiry >= today -> DocumentStatusActive
      | otherwise -> DocumentStatusExpired

documentRegisterStatus :: DocumentRegister -> IO DocumentRegisterStatus
documentRegisterStatus doc = do
  today <- utctDay <$> getCurrentTime
  pure $ documentRegisterStatusAsOf today doc
