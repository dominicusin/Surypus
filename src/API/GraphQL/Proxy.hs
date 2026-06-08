-- ============================================================================
-- SURYPUS GRAPHQL PROXY
-- US-3-4: GraphQL Proxy that forwards to REST endpoints
-- No direct database access - all data comes from existing REST API
-- ============================================================================

{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}

module API.GraphQL.Proxy
  ( -- * GraphQL Proxy Types
    GraphQLConfig  (..)
  , ProxyContext  (..)
  , GraphQLResponse  (..)

    -- * Proxy Operations
  , initializeGraphQLProxy
  , handleGraphQLRequest
  , proxyToREST

    -- * Schema and Resolvers
  , graphqlSchema
  , rootResolver
  ) where

import Data.Aeson (ToJSON, FromJSON, encode, decode, Value, object, (.=))
import Data.Text (Text)
import qualified Data.Text as T
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import Network.HTTP.Client (Manager, parseRequest, responseBody, responseStatus, httpLbs, newManager, defaultManagerSettings)
import Network.HTTP.Types.Status (statusCode)
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Char8 as BS
import Control.Exception (try, SomeException)

-- ============================================================================
-- GRAPHQL PROXY TYPES
-- ============================================================================

-- | GraphQL proxy configuration
data GraphQLConfig = GraphQLConfig
  { gcRestAPIBaseURL :: Text
  , gcTimeout :: Int
  , gcMaxRetries :: Int
  , gcEnableCaching :: Bool
  , gcCacheTTL :: Int
  } deriving (Show, Eq, Generic)

-- | GraphQL request context
data ProxyContext = ProxyContext
  { pcManager :: Manager
  , pcConfig :: GraphQLConfig
  , pcRequestHeaders :: [(Text, Text)]
  }

-- | GraphQL response wrapper
data GraphQLResponse a = GraphQLResponse
  { grData :: Maybe a
  , grErrors :: Maybe [GraphQLError]
  , grExtensions :: Maybe Value
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | GraphQL error
data GraphQLError = GraphQLError
  { gqeMessage :: Text
  , gqeLocations :: Maybe [GraphQLLocation]
  , gqePath :: Maybe [Text]
  , gqeExtensions :: Maybe Value
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | GraphQL error location
data GraphQLLocation = GraphQLLocation
  { gqlLine :: Int
  , gqlColumn :: Int
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- ============================================================================
-- PROXY OPERATIONS
-- ============================================================================

-- | Initialize GraphQL proxy with HTTP manager
initializeGraphQLProxy :: GraphQLConfig -> IO ProxyContext
initializeGraphQLProxy config = do
  manager <- newManager defaultManagerSettings
  pure $ ProxyContext
    { pcManager = manager
    , pcConfig = config
    , pcRequestHeaders = [("Content-Type", "application/json")]
    }

-- | Handle GraphQL request by proxying to REST
handleGraphQLRequest :: ProxyContext -> Text -> Value -> IO (GraphQLResponse Value)
handleGraphQLRequest context query variables = do
  case parseGraphQLQuery query of
    Just restCalls -> do
      results <- mapM (proxyToREST context) restCalls
      pure $ GraphQLResponse
        { grData = Just $ combineResults results
        , grErrors = Nothing
        , grExtensions = Nothing
        }
    Nothing -> do
      pure $ GraphQLResponse
        { grData = Nothing
        , grErrors = Just [GraphQLError "Invalid query" Nothing Nothing Nothing]
        , grExtensions = Nothing
        }

-- | Proxy single REST call
proxyToREST :: ProxyContext -> RESTCall -> IO Value
proxyToREST context restCall = do
  let url = gcRestAPIBaseURL (pcConfig context) <> buildRESTPath restCall
  result <- try $ do
    request <- parseRequest (T.unpack url)
    response <- httpLbs request (pcManager context)
    pure response
  case result of
    Left (_ :: SomeException) ->
      pure $ object ["error" .= ("Network error for: " <> buildRESTPath restCall)]
    Right response ->
      if statusCode (responseStatus response) == 200
        then case decode (responseBody response) of
          Just json -> pure json
          Nothing -> pure $ object ["error" .= ("Invalid JSON response from: " <> buildRESTPath restCall)]
        else pure $ object ["error" .= ("HTTP error for: " <> buildRESTPath restCall)]

-- ============================================================================
-- REST CALL REPRESENTATION
-- ============================================================================

-- | REST call representation derived from GraphQL query
data RESTCall = RESTCall
  { rcMethod :: Text
  , rcPath :: Text
  , rcParams :: [(Text, Text)]
  , rcBody :: Maybe Value
  } deriving (Show, Eq, Generic)

-- | Build REST API path from call
buildRESTPath :: RESTCall -> Text
buildRESTPath call = rcPath call <> buildQueryString (rcParams call)

-- | Build query string from parameters
buildQueryString :: [(Text, Text)] -> Text
buildQueryString [] = ""
buildQueryString params = "?" <> T.intercalate "&" (map buildParam params)
  where
    buildParam (k, v) = k <> "=" <> v

-- ============================================================================
-- GRAPHQL QUERY PARSING
-- ============================================================================

-- | Parse GraphQL query to determine REST calls needed
parseGraphQLQuery :: Text -> Maybe [RESTCall]
parseGraphQLQuery query
  | "accounts" `T.isInfixOf` query = Just
    [ RESTCall "GET" "/api/v1/accounts" [] Nothing ]
  | "account" `T.isInfixOf` query = Just
    [ RESTCall "GET" "/api/v1/accounts/{id}" [] Nothing ]
  | "balance" `T.isInfixOf` query = Just
    [ RESTCall "GET" "/api/v1/account-balances" [] Nothing ]
  | "journal" `T.isInfixOf` query = Just
    [ RESTCall "GET" "/api/v1/journal-entries" [] Nothing ]
  | "dashboard" `T.isInfixOf` query = Just
    [ RESTCall "GET" "/api/v1/dashboard" [] Nothing ]
  | otherwise = Nothing

-- | Combine multiple REST call results
combineResults :: [Value] -> Value
combineResults [] = object []
combineResults [result] = result
combineResults results = object ["combined" .= results]

-- ============================================================================
-- GRAPHQL SCHEMA (SIMPLIFIED)
-- ============================================================================

-- | Basic GraphQL schema for the proxy
graphqlSchema :: Text
graphqlSchema = T.unlines
  [ "type Query {"
  , "  accounts: [Account]"
  , "  account(id: ID!): Account"
  , "  balance(accountId: ID!): Balance"
  , "  journalEntries: [JournalEntry]"
  , "  dashboard: Dashboard"
  , "}"
  , ""
  , "type Account {"
  , "  id: ID!"
  , "  code: String"
  , "  name: String"
  , "  type: String"
  , "  balance: Float!"
  , "  createdAt: String"
  , "  updatedAt: String"
  , "}"
  , ""
  , "type Balance {"
  , "  accountId: ID!"
  , "  currentBalance: Float!"
  , "  debitTotal: Float!"
  , "  creditTotal: Float!"
  , "  lastUpdated: String"
  , "}"
  , ""
  , "type JournalEntry {"
  , "  id: ID!"
  , "  date: String!"
  , "  description: String"
  , "  debitAccount: Account!"
  , "  creditAccount: Account!"
  , "  amount: Float!"
  , "  currency: String!"
  , "}"
  , ""
  , "type Dashboard {"
  , "  revenue: Float!"
  , "  stockValue: Float!"
  , "  pendingPayments: Float!"
  , "}"
  ]

-- | Root resolver for GraphQL queries
rootResolver :: ProxyContext -> Text -> Value -> IO (GraphQLResponse Value)
rootResolver = handleGraphQLRequest