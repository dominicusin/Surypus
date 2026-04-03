{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

module Surypus.API.Types where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import GHC.Generics (Generic)

data ApiRole = ApiRole
  { roleId :: Int64,
    roleName :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data ApiPerson = ApiPerson
  { personId :: Int64,
    personName :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data ApiGood = ApiGood
  { goodId :: Int64,
    goodName :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data ApiBill = ApiBill
  { billId :: Int64,
    billName :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data LoginRequest = LoginRequest
  { username :: Text,
    password :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data LoginResponse = LoginResponse
  { accessToken :: Text,
    refreshToken :: Text,
    userId :: Int64,
    userName :: Text,
    role :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data UserRequest = UserRequest
  { urUsername :: Text,
    urEmail :: Maybe Text,
    urRole :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data UserResponse = UserResponse
  { urUserId :: Int64,
    urUserName :: Text,
    urUserEmail :: Text,
    urRoleId :: Int64
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)
