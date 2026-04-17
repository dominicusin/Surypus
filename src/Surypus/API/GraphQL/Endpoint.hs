{-# LANGUAGE OverloadedStrings #-}

-- | GraphQL endpoint integration for Surypus (placeholder implementation)
module Surypus.API.GraphQL.Endpoint
  ( graphQLEndpoint,
  )
where

import Data.Aeson (ToJSON, Value)
import Data.Text (Text)
import Servant (Server)
import Surypus.API.GraphQL

-- | GraphQL API endpoint type
type GraphQLEndpoint = "graphql" :> Post '[JSON] Value

-- | GraphQL server handler - placeholder implementation
graphQLHandler :: Value
graphQLHandler =
  let query =
        object
          [ "data"
              .= object
                [ "bills" .= [object ["id" .= (1 :: Int), "number" .= ("BILL-001" :: Text), "total" .= (100.0 :: Double)]],
                  "goods" .= [object ["id" .= (1 :: Int), "name" .= ("Goods 1" :: Text), "price" .= (10.0 :: Double)]],
                  "persons" .= [object ["id" .= (1 :: Int), "name" .= ("John Doe" :: Text)]],
                  "dashboard" .= object ["revenue" .= (1000.0 :: Double), "expenses" .= (800.0 :: Double), "profit" .= (200.0 :: Double)]
                ]
          ]
   in query

-- | GraphQL endpoint for the main server
graphQLEndpoint :: Server GraphQLEndpoint
graphQLEndpoint = pure graphQLHandler
