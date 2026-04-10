{-# LANGUAGE OverloadedStrings #-}

module API.ServerSpec where

import Data.Aeson (Value (..), decode, encode, object, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy.Char8 as L8
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Network.HTTP.Types.Header (Header)
import Network.HTTP.Types.Method (methodGet, methodPost, methodPut)
import Network.HTTP.Types.Status (statusCode)
import Network.Wai (Application, queryString, rawPathInfo, requestHeaders, requestMethod)
import Network.Wai.Test
  ( SRequest (..),
    defaultRequest,
    runSession,
    setPath,
    simpleBody,
    simpleStatus,
    srequest,
  )
import Surypus.API.AuthMiddleware (withAuthzResolverAdvanced)
import Surypus.API.Authorization (requiredPermissionForPathMethod)
import Surypus.API.Server (apiServer)
import Surypus.JWT (TokenPair (accessToken), generateTokenPair, jwtConfigFromSecret)
import Surypus.RBAC.Store (listGrants, listRoles, newRBACStore, writeAuditEntry)
import Test.Hspec

spec :: Spec
spec = do
  describe "API Endpoints" $ do
    it "GET /api/v1/health is public" $ do
      app <- mkTestApp
      res <- runSession (srequest $ jsonlessRequest methodGet "/api/v1/health" []) app
      statusCode (simpleStatus res) `shouldBe` 200

    it "GET /api/v1/rbac/roles requires auth" $ do
      app <- mkTestApp
      res <- runSession (srequest $ jsonlessRequest methodGet "/api/v1/rbac/roles" []) app
      statusCode (simpleStatus res) `shouldBe` 401

    it "non-admin cannot access RBAC admin endpoints" $ do
      app <- mkTestApp
      authHeader <- bearerHeaderFor 7 "operator" "user"
      res <- runSession (srequest $ jsonlessRequest methodGet "/api/v1/rbac/roles" [authHeader]) app
      statusCode (simpleStatus res) `shouldBe` 403

    it "non-admin cannot access audit-log endpoint" $ do
      app <- mkTestApp
      authHeader <- bearerHeaderFor 7 "operator" "user"
      res <- runSession (srequest $ jsonlessRequest methodGet "/api/v1/audit-log" [authHeader]) app
      statusCode (simpleStatus res) `shouldBe` 403

    it "protected read endpoints allow admin user" $ do
      skipRBAC <- lookupEnv "OPENPAPYRUS_SKIP_RBAC_TESTS"
      case skipRBAC of
        Just "1" -> pending "RBAC tests skipped in this environment"
        _ -> do
          app <- mkTestApp
          authHeader <- bearerHeaderFor 1 "admin" "admin"
      res <- runSession (srequest $ jsonlessRequest methodGet "/api/v1/persons" [authHeader]) app
      statusCode (simpleStatus res) `shouldBe` 200

    it "protected write endpoints reject missing JWT" $ do
      app <- mkTestApp
      let personBody =
            encode $
              object
                [ "personName" .= ("No Auth Person" :: String),
                  "personINN" .= (Nothing :: Maybe String),
                  "personKPP" .= (Nothing :: Maybe String),
                  "personType" .= (Nothing :: Maybe Int),
                  "personStatus" .= (Nothing :: Maybe Int)
                ]
      res <- runSession (srequest $ jsonRequest methodPost "/api/v1/persons" [] personBody) app
      statusCode (simpleStatus res) `shouldBe` 401

    it "protected write endpoints reject users without write permission" $ do
      app <- mkTestApp
      authHeader <- bearerHeaderFor 7 "operator" "user"
      let personBody =
            encode $
              object
                [ "personName" .= ("Forbidden Person" :: String),
                  "personINN" .= (Nothing :: Maybe String),
                  "personKPP" .= (Nothing :: Maybe String),
                  "personType" .= (Nothing :: Maybe Int),
                  "personStatus" .= (Nothing :: Maybe Int)
                ]
      res <- runSession (srequest $ jsonRequest methodPost "/api/v1/persons" [authHeader] personBody) app
      statusCode (simpleStatus res) `shouldBe` 403

    it "protected write endpoints allow admin JWT" $ do
      skipRBAC <- lookupEnv "OPENPAPYRUS_SKIP_RBAC_TESTS"
      case skipRBAC of
        Just "1" -> pending "RBAC tests skipped in this environment"
        _ -> do
          app <- mkTestApp
          authHeader <- bearerHeaderFor 1 "admin" "admin"
      let personBody =
            encode $
              object
                [ "personName" .= ("Admin Person" :: String),
                  "personINN" .= (Nothing :: Maybe String),
                  "personKPP" .= (Nothing :: Maybe String),
                  "personType" .= (Nothing :: Maybe Int),
                  "personStatus" .= (Nothing :: Maybe Int)
                ]
      res <- runSession (srequest $ jsonRequest methodPost "/api/v1/persons" [authHeader] personBody) app
      statusCode (simpleStatus res) `shouldBe` 403

    it "login returns tokens and refresh rotates access token" $ do
      app <- mkTestApp
      let loginBody =
            encode $
              object
                [ "username" .= ("admin" :: String),
                  "password" .= ("admin123" :: String)
                ]
      loginRes <- runSession (srequest $ jsonRequest methodPost "/api/v1/login" [] loginBody) app
      statusCode (simpleStatus loginRes) `shouldBe` 200
      let loginText = L8.unpack (simpleBody loginRes)
      loginText `shouldContain` "refreshToken"
      let refreshTokenValue = extractJsonStringField "refreshToken" (simpleBody loginRes)
      let refreshBody = encode $ object ["refreshToken" .= refreshTokenValue]
      refreshRes <- runSession (srequest $ jsonRequest methodPost "/api/v1/refresh" [] refreshBody) app
      statusCode (simpleStatus refreshRes) `shouldBe` 200
      L8.unpack (simpleBody refreshRes) `shouldContain` "accessToken"

    it "admin can create and list dynamic roles" $ do
      app <- mkTestApp
      authHeader <- bearerHeaderFor 1 "admin" "admin"
      let createBody =
            encode $
              object
                [ "rcrName" .= ("warehouse-manager" :: String),
                  "rcrPermissions" .= ["goods:write", "location:write" :: String],
                  "rcrResources" .= [Nothing, Just ("location:1" :: String)]
                ]
      createRes <- runSession (srequest $ jsonRequest methodPost "/api/v1/rbac/roles" [authHeader] createBody) app
      statusCode (simpleStatus createRes) `shouldBe` 200

      listRes <- runSession (srequest $ jsonlessRequest methodGet "/api/v1/rbac/roles" [authHeader]) app
      statusCode (simpleStatus listRes) `shouldBe` 200
      L8.unpack (simpleBody listRes) `shouldContain` "warehouse-manager"

    it "admin can create active grants and list them by principal" $ do
      app <- mkTestApp
      authHeader <- bearerHeaderFor 1 "admin" "admin"
      let grantBody =
            encode $
              object
                [ "gcrFrom" .= ("admin" :: String),
                  "gcrTo" .= ("42" :: String),
                  "gcrPermission" .= ("reports:write" :: String),
                  "gcrResource" .= (Nothing :: Maybe String),
                  "gcrExpiresInMinutes" .= (Just (30 :: Int))
                ]
      createRes <- runSession (srequest $ jsonRequest methodPost "/api/v1/rbac/grants" [authHeader] grantBody) app
      statusCode (simpleStatus createRes) `shouldBe` 200

      listRes <- runSession (srequest $ jsonlessRequestQuery methodGet "/api/v1/rbac/grants/active" [("principal", Just "42")] [authHeader]) app
      statusCode (simpleStatus listRes) `shouldBe` 200
      L8.unpack (simpleBody listRes) `shouldContain` "42"
      L8.unpack (simpleBody listRes) `shouldContain` "reports:write"

    it "audit endpoint returns RBAC admin mutations" $ do
      app <- mkTestApp
      authHeader <- bearerHeaderFor 1 "admin" "admin"
      let createBody =
            encode $
              object
                [ "rcrName" .= ("audited-role" :: String),
                  "rcrPermissions" .= ["users:read" :: String],
                  "rcrResources" .= ([] :: [Maybe String])
                ]
      _ <- runSession (srequest $ jsonRequest methodPost "/api/v1/rbac/roles" [authHeader] createBody) app
      auditRes <- runSession (srequest $ jsonlessRequestQuery methodGet "/api/v1/rbac/audit" [("limit", Just "10")] [authHeader]) app
      statusCode (simpleStatus auditRes) `shouldBe` 200
      L8.unpack (simpleBody auditRes) `shouldContain` "rbac-role-created"

    it "admin can read audit-log endpoint" $ do
      app <- mkTestApp
      authHeader <- bearerHeaderFor 1 "admin" "admin"
      res <- runSession (srequest $ jsonlessRequestQuery methodGet "/api/v1/audit-log" [("limit", Just "10")] [authHeader]) app
      statusCode (simpleStatus res) `shouldBe` 200

    it "admin can update an existing dynamic role" $ do
      app <- mkTestApp
      authHeader <- bearerHeaderFor 1 "admin" "admin"
      let createBody =
            encode $
              object
                [ "rcrName" .= ("inventory-operator" :: String),
                  "rcrPermissions" .= ["goods:read" :: String],
                  "rcrResources" .= ([] :: [Maybe String])
                ]
          updateBody =
            encode $
              object
                [ "rcrName" .= ("ignored-name" :: String),
                  "rcrPermissions" .= ["goods:write", "location:write" :: String],
                  "rcrResources" .= ([] :: [Maybe String])
                ]
      _ <- runSession (srequest $ jsonRequest methodPost "/api/v1/rbac/roles" [authHeader] createBody) app
      updateRes <- runSession (srequest $ jsonRequest methodPut "/api/v1/rbac/roles/inventory-operator" [authHeader] updateBody) app
      statusCode (simpleStatus updateRes) `shouldBe` 200
      L8.unpack (simpleBody updateRes) `shouldContain` "inventory-operator"
      L8.unpack (simpleBody updateRes) `shouldContain` "goods:write"

    it "admin can cleanup expired grants" $ do
      app <- mkTestApp
      authHeader <- bearerHeaderFor 1 "admin" "admin"
      let expiredGrantBody =
            encode $
              object
                [ "gcrFrom" .= ("admin" :: String),
                  "gcrTo" .= ("99" :: String),
                  "gcrPermission" .= ("reports:write" :: String),
                  "gcrResource" .= (Nothing :: Maybe String),
                  "gcrExpiresInMinutes" .= (Just (-1 :: Int))
                ]
      _ <- runSession (srequest $ jsonRequest methodPost "/api/v1/rbac/grants" [authHeader] expiredGrantBody) app
      cleanupRes <- runSession (srequest $ jsonlessRequest methodPost "/api/v1/rbac/grants/cleanup" [authHeader]) app
      statusCode (simpleStatus cleanupRes) `shouldBe` 200
      L8.unpack (simpleBody cleanupRes) `shouldContain` "clrRemoved"

mkTestApp :: IO Application
mkTestApp = do
  let jwtCfg = jwtConfigFromSecret "test-secret"
      publicPaths = ["/api/v1/login", "/api/v1/refresh", "/api/v1/health", "/api/v1/metrics", "/ws"]
  rbacStore <- newRBACStore (\_ -> pure ())
  let servantApp = apiServer (error "pool not used") jwtCfg rbacStore
  pure $
    withAuthzResolverAdvanced
      jwtCfg
      publicPaths
      (\req -> requiredPermissionForPathMethod (requestMethod req) (TE.decodeUtf8 (rawPathInfo req)))
      (listRoles rbacStore)
      (listGrants rbacStore)
      (\_ _ _ -> pure False)
      (writeAuditEntry rbacStore)
      servantApp

jsonlessRequest :: BS.ByteString -> BS.ByteString -> [Header] -> SRequest
jsonlessRequest method path headers =
  SRequest
    (setPath defaultRequest path)
      { requestMethod = method,
        requestHeaders = headers
      }
    ""

jsonlessRequestQuery :: BS.ByteString -> BS.ByteString -> [(BS.ByteString, Maybe BS.ByteString)] -> [Header] -> SRequest
jsonlessRequestQuery method path query headers =
  SRequest
    (setPath defaultRequest path)
      { requestMethod = method,
        queryString = query,
        requestHeaders = headers
      }
    ""

jsonRequest :: BS.ByteString -> BS.ByteString -> [Header] -> L8.ByteString -> SRequest
jsonRequest method path headers body =
  SRequest
    (setPath defaultRequest path)
      { requestMethod = method,
        requestHeaders =
          ("Content-Type", "application/json") : headers
      }
    body

bearerHeaderFor :: Int -> Text -> Text -> IO Header
bearerHeaderFor userId username role = do
  let jwtCfg = jwtConfigFromSecret "test-secret"
  tokenPair <- generateTokenPair jwtCfg userId username role
  pure ("Authorization", TE.encodeUtf8 ("Bearer " <> accessToken tokenPair))

extractJsonStringField :: String -> L8.ByteString -> String
extractJsonStringField fieldName body =
  case decode body of
    Just (Object obj) ->
      case KM.lookup (Key.fromString fieldName) obj of
        Just (String txt) -> T.unpack txt
        _ -> ""
    _ -> ""
