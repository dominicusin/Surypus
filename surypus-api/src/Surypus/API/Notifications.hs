{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Notifications
  ( NotificationPref(..)
  , Notification(..)
  , getPreferences
  , updatePreferences
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)
import Control.Exception (try, SomeException)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Statement
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import DAL.Database (Pool, usePool)
import Surypus.CoreTypes (QueryResult(..))

data NotificationPref = NotificationPref
  { npEmail :: !Bool, npPush :: !Bool, npDigest :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON NotificationPref
instance FromJSON NotificationPref

data Notification = Notification
  { notifId :: !Text, notifTitle :: !Text, notifBody :: !(Maybe Text), notifStatus :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON Notification

getPreferences :: Pool -> IO (QueryResult NotificationPref)
getPreferences pool = do
  let stmt = Statement.Statement
        "SELECT TRUE, TRUE, 'daily'"
        () (D.singleRow $ NotificationPref <$> D.column (D.nonNullable D.bool) <*> D.column (D.nonNullable D.bool) <*> D.column (D.nonNullable D.text)) True
  result <- try $ usePool pool $ Session.statement () stmt
  case result of
    Right prefs -> return $ QuerySuccess prefs
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)

updatePreferences :: Pool -> NotificationPref -> IO (QueryResult ())
updatePreferences _ _ = return $ QueryError "Not implemented"
