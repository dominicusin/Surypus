{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | GraphQL API module for Surypus (placeholder implementation)
module Surypus.API.GraphQL
  ( graphQLAPI,
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)

data GraphQLBill = GraphQLBill
  { billId :: Int,
    billNumber :: Text,
    billTotal :: Double
  }
  deriving (Generic, ToJSON, FromJSON)

data GraphQLGoods = GraphQLGoods
  { goodsId :: Int,
    goodsName :: Text,
    goodsPrice :: Double
  }
  deriving (Generic, ToJSON, FromJSON)

data GraphQLPerson = GraphQLPerson
  { personId :: Int,
    personName :: Text
  }
  deriving (Generic, ToJSON, FromJSON)

data GraphQLDashboard = GraphQLDashboard
  { revenue :: Double,
    expenses :: Double,
    profit :: Double
  }
  deriving (Generic, ToJSON, FromJSON)

data GraphQLQuery = GraphQLQuery
  { queryBills :: [GraphQLBill],
    queryGoods :: [GraphQLGoods],
    queryPersons :: [GraphQLPerson],
    queryDashboard :: GraphQLDashboard
  }
  deriving (Generic, ToJSON, FromJSON)

graphQLAPI :: GraphQLQuery
graphQLAPI =
  GraphQLQuery
    { queryBills = [GraphQLBill 1 "BILL-001" 100.0],
      queryGoods = [GraphQLGoods 1 "Goods 1" 10.0],
      queryPersons = [GraphQLPerson 1 "John Doe"],
      queryDashboard = GraphQLDashboard 1000.0 800.0 200.0
    }
