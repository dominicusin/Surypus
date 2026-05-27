{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.API.GraphQL where

import Data.Aeson (Value)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Servant

-- | GraphQL query
data GraphQLQuery = GraphQLQuery
    { gqQuery :: Text
    , gqVariables :: Maybe Value
    }
    deriving (Eq, Show)

-- | GraphQL response
data GraphQLResponse = GraphQLResponse
    { grData :: Maybe Value
    , grErrors :: Maybe [Text]
    }
    deriving (Eq, Show)

-- | GraphQL API type
type GraphQLAPI = ReqBody '[JSON] GraphQLQuery :> Post '[JSON] GraphQLResponse

-- | GraphQL handler
graphqlHandler :: GraphQLQuery -> Handler GraphQLResponse
graphqlHandler _ = return $ GraphQLResponse Nothing Nothing

-- | Schema definition (simplified)
type Schema = Map.Map Text Text
