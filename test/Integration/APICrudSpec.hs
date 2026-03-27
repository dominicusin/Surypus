{-# LANGUAGE OverloadedStrings #-}

module Main where

import APIServer (ServerConfig (..), defaultRateLimit, runServer)
import Control.Concurrent (ThreadId, forkIO, killThread, threadDelay)
import Control.Exception (SomeException, bracket, try)
import DB.Connection (closePool, createPool, poolConfigFromEnv)
import Data.Aeson (Result (..), Value (..), eitherDecode, fromJSON, object, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString.Lazy as LBS
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import qualified Data.Text as T
import Data.Time.Clock.POSIX (getPOSIXTime)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Statement
import Network.HTTP.Simple
import qualified Network.HTTP.Types as HTTP
import System.Environment (lookupEnv)
import Test.Hspec

data TestEnv = TestEnv
  { tePool :: Pool,
    teBaseUrl :: String,
    teServerThreadId :: ThreadId
  }

main :: IO ()
main = hspec $ aroundAll withTestServer spec

spec :: SpecWith TestEnv
spec = do
  describe "DB schema smoke" $ do
    it "payment table has expected API columns" $ \env -> do
      columnExists (tePool env) "payment" "date" `shouldReturn` True
      columnExists (tePool env) "payment" "payment_method" `shouldReturn` True
      columnExists (tePool env) "payment" "payment_status" `shouldReturn` True

    it "goods_price table has expected API columns" $ \env -> do
      columnExists (tePool env) "goods_price" "valid_from" `shouldReturn` True
      columnExists (tePool env) "goods_price" "valid_to" `shouldReturn` True

    it "tax and currency tables require object type" $ \env -> do
      columnExists (tePool env) "tax" "obj_type" `shouldReturn` True
      columnExists (tePool env) "currency" "obj_type" `shouldReturn` True

  describe "API CRUD integration" $ do
    it "currency CRUD works end-to-end" $ \env -> do
      suffix <- uniqueSuffix
      let createPayload =
            object
              [ "ciCode" .= ("T" <> T.take 2 suffix),
                "ciName" .= ("Test Currency " <> suffix),
                "ciSymbol" .= ("TC" :: T.Text),
                "ciRate" .= (1.25 :: Double)
              ]
      createResp <- requestJSON env HTTP.methodPost "/api/v1/currencies" createPayload
      createJson <- expectJsonSuccess createResp
      currencyId <- requireDataInt64 "currId" createJson

      getResp <- requestNoBody env HTTP.methodGet ("/api/v1/currencies/" <> show currencyId)
      _ <- expectJsonSuccess getResp

      let updatePayload =
            object
              [ "ciCode" .= ("T" <> T.take 2 suffix),
                "ciName" .= ("Test Currency Updated " <> suffix),
                "ciSymbol" .= ("TU" :: T.Text),
                "ciRate" .= (2.0 :: Double)
              ]
      updateResp <- requestJSON env HTTP.methodPut ("/api/v1/currencies/" <> show currencyId) updatePayload
      _ <- expectJsonSuccess updateResp

      deleteResp <- requestNoBody env HTTP.methodDelete ("/api/v1/currencies/" <> show currencyId)
      _ <- expectJsonSuccess deleteResp

      notFoundResp <- requestNoBody env HTTP.methodGet ("/api/v1/currencies/" <> show currencyId)
      getResponseStatusCode notFoundResp `shouldBe` 404

    it "tax CRUD works end-to-end" $ \env -> do
      suffix <- uniqueSuffix
      let createPayload =
            object
              [ "tiName" .= ("Test Tax " <> suffix),
                "tiRate" .= (12.5 :: Double),
                "tiTaxType" .= (0 :: Int),
                "tiIncluded" .= False
              ]
      createResp <- requestJSON env HTTP.methodPost "/api/v1/taxes" createPayload
      createJson <- expectJsonSuccess createResp
      tid <- requireDataInt64 "taxId" createJson

      getResp <- requestNoBody env HTTP.methodGet ("/api/v1/taxes/" <> show tid)
      _ <- expectJsonSuccess getResp

      let updatePayload =
            object
              [ "tiName" .= ("Test Tax Updated " <> suffix),
                "tiRate" .= (15.0 :: Double),
                "tiTaxType" .= (1 :: Int),
                "tiIncluded" .= True
              ]
      updateResp <- requestJSON env HTTP.methodPut ("/api/v1/taxes/" <> show tid) updatePayload
      _ <- expectJsonSuccess updateResp

      deleteResp <- requestNoBody env HTTP.methodDelete ("/api/v1/taxes/" <> show tid)
      _ <- expectJsonSuccess deleteResp

      notFoundResp <- requestNoBody env HTTP.methodGet ("/api/v1/taxes/" <> show tid)
      getResponseStatusCode notFoundResp `shouldBe` 404

    it "payment CRUD works end-to-end" $ \env -> do
      suffix <- uniqueSuffix
      billId <- insertSeedBill (tePool env) ("Payment Bill " <> suffix)

      let createPayload =
            object
              [ "piBillId" .= billId,
                "piPayDate" .= ("2026-03-27" :: T.Text),
                "piAmount" .= (100.0 :: Double),
                "piPayMethod" .= (1 :: Int),
                "piPayStatus" .= (0 :: Int)
              ]

      createResp <- requestJSON env HTTP.methodPost "/api/v1/payments" createPayload
      createJson <- expectJsonSuccess createResp
      paymentId <- requireDataInt64 "payId" createJson

      getResp <- requestNoBody env HTTP.methodGet ("/api/v1/payments/" <> show paymentId)
      _ <- expectJsonSuccess getResp

      let updatePayload =
            object
              [ "piBillId" .= billId,
                "piPayDate" .= ("2026-03-28" :: T.Text),
                "piAmount" .= (125.5 :: Double),
                "piPayMethod" .= (2 :: Int),
                "piPayStatus" .= (1 :: Int)
              ]
      updateResp <- requestJSON env HTTP.methodPut ("/api/v1/payments/" <> show paymentId) updatePayload
      _ <- expectJsonSuccess updateResp

      deleteResp <- requestNoBody env HTTP.methodDelete ("/api/v1/payments/" <> show paymentId)
      _ <- expectJsonSuccess deleteResp

      deleteById (tePool env) "DELETE FROM public.bill WHERE id = $1" billId

    it "goods price create and read endpoints work" $ \env -> do
      suffix <- uniqueSuffix
      goodsId <- insertSeedGoods (tePool env) ("Price Goods " <> suffix)
      currencyId <- insertSeedCurrency (tePool env) ("P" <> T.take 2 suffix) ("Price Currency " <> suffix)

      let createPayload =
            object
              [ "priGoodsId" .= goodsId,
                "priPriceType" .= (0 :: Int),
                "priPrice" .= (99.99 :: Double),
                "priCurrencyId" .= currencyId,
                "priFromDate" .= ("2026-03-27" :: T.Text),
                "priToDate" .= (Nothing :: Maybe T.Text)
              ]

      createResp <- requestJSON env HTTP.methodPost "/api/v1/goods/prices" createPayload
      createJson <- expectJsonSuccess createResp
      priceId <- requireDataInt64 "gpId" createJson

      listAllResp <- requestNoBody env HTTP.methodGet "/api/v1/goods/prices"
      _ <- expectJsonSuccess listAllResp

      listByGoodsResp <- requestNoBody env HTTP.methodGet ("/api/v1/goods/" <> show goodsId <> "/prices")
      _ <- expectJsonSuccess listByGoodsResp

      deleteById (tePool env) "DELETE FROM public.goods_price WHERE id = $1" priceId
      deleteById (tePool env) "DELETE FROM public.currency WHERE id = $1" currencyId
      deleteById (tePool env) "DELETE FROM public.goods WHERE id = $1" goodsId

  describe "API validation and not-found handling" $ do
    it "returns 400 for invalid currency payload" $ \env -> do
      let invalidPayload =
            object
              [ "ciCode" .= ("TOO_LONG" :: T.Text),
                "ciName" .= ("Invalid Currency" :: T.Text),
                "ciSymbol" .= ("IC" :: T.Text),
                "ciRate" .= (0.0 :: Double)
              ]
      response <- requestJSON env HTTP.methodPost "/api/v1/currencies" invalidPayload
      _ <- expectJsonError 400 response
      pure ()

    it "returns 400 for invalid tax payload" $ \env -> do
      let invalidPayload =
            object
              [ "tiName" .= ("" :: T.Text),
                "tiRate" .= (150.0 :: Double),
                "tiTaxType" .= (-1 :: Int),
                "tiIncluded" .= False
              ]
      response <- requestJSON env HTTP.methodPost "/api/v1/taxes" invalidPayload
      _ <- expectJsonError 400 response
      pure ()

    it "returns 400 for invalid payment payload" $ \env -> do
      let invalidPayload =
            object
              [ "piBillId" .= (1 :: Int64),
                "piPayDate" .= ("2026-03-27" :: T.Text),
                "piAmount" .= (-10.0 :: Double),
                "piPayMethod" .= (0 :: Int),
                "piPayStatus" .= (0 :: Int)
              ]
      response <- requestJSON env HTTP.methodPost "/api/v1/payments" invalidPayload
      _ <- expectJsonError 400 response
      pure ()

    it "returns 400 for invalid goods price payload" $ \env -> do
      let invalidPayload =
            object
              [ "priGoodsId" .= (1 :: Int64),
                "priPriceType" .= (0 :: Int),
                "priPrice" .= (-1.0 :: Double),
                "priCurrencyId" .= (1 :: Int64),
                "priFromDate" .= ("2026-03-27" :: T.Text),
                "priToDate" .= (Nothing :: Maybe T.Text)
              ]
      response <- requestJSON env HTTP.methodPost "/api/v1/goods/prices" invalidPayload
      _ <- expectJsonError 400 response
      pure ()

    it "returns 404 for non-existing payment resource" $ \env -> do
      let missingId = (9876543210 :: Int64)
      getResp <- requestNoBody env HTTP.methodGet ("/api/v1/payments/" <> show missingId)
      _ <- expectJsonError 404 getResp
      deleteResp <- requestNoBody env HTTP.methodDelete ("/api/v1/payments/" <> show missingId)
      _ <- expectJsonError 404 deleteResp
      pure ()

  describe "Additional read endpoint smoke" $ do
    it "accounting endpoints respond with success JSON" $ \env -> do
      accountsResp <- requestNoBody env HTTP.methodGet "/api/v1/accounting/accounts"
      _ <- expectJsonSuccess accountsResp
      entriesResp <- requestNoBody env HTTP.methodGet "/api/v1/accounting/entries"
      _ <- expectJsonSuccess entriesResp
      pure ()

    it "payroll endpoints respond with success JSON" $ \env -> do
      employeesResp <- requestNoBody env HTTP.methodGet "/api/v1/payroll/employees"
      _ <- expectJsonSuccess employeesResp
      salariesResp <- requestNoBody env HTTP.methodGet "/api/v1/payroll/salaries"
      _ <- expectJsonSuccess salariesResp
      pure ()

    it "report and dashboard endpoints respond with success JSON" $ \env -> do
      reportsResp <- requestNoBody env HTTP.methodGet "/api/v1/reports/templates"
      _ <- expectJsonSuccess reportsResp
      dashboardResp <- requestNoBody env HTTP.methodGet "/api/v1/dashboard"
      _ <- expectJsonSuccess dashboardResp
      pure ()

withTestServer :: ActionWith TestEnv -> IO ()
withTestServer action = bracket setup teardown action
  where
    setup = do
      baseCfg <- poolConfigFromEnv
      let cfg = baseCfg
      pool <- createPool cfg
      syncSequences pool
      rateLimit <- defaultRateLimit
      port <- lookupEnv "TEST_API_PORT" >>= return . maybe 18080 read
      let serverCfg =
            ServerConfig
              { scHost = "127.0.0.1",
                scPort = port,
                scLogRequests = False,
                scJwtSecret = "integration-test-secret",
                scRateLimit = rateLimit,
                scPool = pool,
                scWebSocketHub = Nothing
              }
      tid <- forkIO $ runServer serverCfg
      waitForServer port
      pure $ TestEnv pool ("http://127.0.0.1:" <> show port) tid

    teardown env = do
      killThread (teServerThreadId env)
      closePool (tePool env)

waitForServer :: Int -> IO ()
waitForServer port = go (40 :: Int)
  where
    healthUrl = "http://127.0.0.1:" <> show port <> "/api/v1/health/live"
    go 0 = fail "API server did not start in time"
    go n = do
      req <- parseRequest healthUrl
      response <- try (httpLBS req) :: IO (Either SomeException (Response LBS.ByteString))
      case response of
        Right okResp
          | getResponseStatusCode okResp == 200 -> pure ()
        _ -> do
          threadDelay 250000
          go (n - 1)

requestNoBody :: TestEnv -> HTTP.Method -> String -> IO (Response LBS.ByteString)
requestNoBody env method path = do
  req0 <- parseRequest (teBaseUrl env <> path)
  let req = setRequestMethod method req0
  httpLBS req

requestJSON :: TestEnv -> HTTP.Method -> String -> Value -> IO (Response LBS.ByteString)
requestJSON env method path payload = do
  req0 <- parseRequest (teBaseUrl env <> path)
  let req = setRequestBodyJSON payload $ setRequestMethod method req0
  httpLBS req

expectJsonSuccess :: Response LBS.ByteString -> IO Value
expectJsonSuccess response = do
  getResponseStatusCode response `shouldBe` 200
  payload <- decodeResponseValue response
  lookupBool "success" payload `shouldBe` Just True
  pure payload

expectJsonError :: Int -> Response LBS.ByteString -> IO Value
expectJsonError expectedStatus response = do
  getResponseStatusCode response `shouldBe` expectedStatus
  payload <- decodeResponseValue response
  lookupBool "success" payload `shouldBe` Just False
  pure payload

decodeResponseValue :: Response LBS.ByteString -> IO Value
decodeResponseValue response =
  case eitherDecode (getResponseBody response) of
    Right value -> pure value
    Left err -> do
      expectationFailure ("Invalid JSON response: " <> err)
      pure Null

lookupBool :: T.Text -> Value -> Maybe Bool
lookupBool key (Object obj) = do
  value <- KM.lookup (Key.fromText key) obj
  case value of
    Bool b -> Just b
    _ -> Nothing
lookupBool _ _ = Nothing

lookupValue :: T.Text -> Value -> Maybe Value
lookupValue key (Object obj) = KM.lookup (Key.fromText key) obj
lookupValue _ _ = Nothing

lookupInt64 :: T.Text -> Value -> Maybe Int64
lookupInt64 key value = do
  field <- lookupValue key value
  case fromJSON field of
    Success i -> Just i
    Error _ -> Nothing

requireDataInt64 :: T.Text -> Value -> IO Int64
requireDataInt64 field payload =
  case lookupValue "data" payload >>= lookupInt64 field of
    Just value -> pure value
    Nothing -> do
      expectationFailure ("Response data does not contain int field: " <> T.unpack field)
      pure (-1)

runStatement :: Pool -> a -> Statement.Statement a b -> IO b
runStatement pool params stmt = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right value -> pure value
    Left err -> do
      expectationFailure ("DB statement failed: " <> show err)
      fail "DB statement failed"

columnExists :: Pool -> T.Text -> T.Text -> IO Bool
columnExists pool tableName columnName =
  runStatement pool (tableName, columnName) stmt
  where
    stmt =
      Statement.unpreparable
        "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2)"
        ((fst >$< E.param (E.nonNullable E.text)) <> (snd >$< E.param (E.nonNullable E.text)))
        (D.singleRow (D.column (D.nonNullable D.bool)))

insertSeedBill :: Pool -> T.Text -> IO Int64
insertSeedBill pool billName =
  runStatement pool billName stmt
  where
    stmt =
      Statement.unpreparable
        "INSERT INTO public.bill (name, obj_type, doc_date, bill_type, doc_status, total, discount_amount, tax_amount) VALUES ($1, 'bill', CURRENT_DATE, 0, 0, 0, 0, 0) RETURNING id"
        (E.param (E.nonNullable E.text))
        (D.singleRow (D.column (D.nonNullable D.int8)))

insertSeedGoods :: Pool -> T.Text -> IO Int64
insertSeedGoods pool goodsName =
  runStatement pool goodsName stmt
  where
    stmt =
      Statement.unpreparable
        "INSERT INTO public.goods (name, obj_type) VALUES ($1, 'goods') RETURNING id"
        (E.param (E.nonNullable E.text))
        (D.singleRow (D.column (D.nonNullable D.int8)))

insertSeedCurrency :: Pool -> T.Text -> T.Text -> IO Int64
insertSeedCurrency pool code name =
  runStatement pool (code, name) stmt
  where
    stmt =
      Statement.unpreparable
        "INSERT INTO public.currency (code, name, obj_type, symbol, rate_to_base, is_base) VALUES ($1, $2, 'currency', 'SC', 1.0, FALSE) RETURNING id"
        ((fst >$< E.param (E.nonNullable E.text)) <> (snd >$< E.param (E.nonNullable E.text)))
        (D.singleRow (D.column (D.nonNullable D.int8)))

deleteById :: Pool -> T.Text -> Int64 -> IO ()
deleteById pool sql rowId =
  runStatement pool rowId stmt
  where
    stmt = Statement.unpreparable sql (E.param (E.nonNullable E.int8)) D.noResult

uniqueSuffix :: IO T.Text
uniqueSuffix = do
  ts <- getPOSIXTime
  pure (T.pack (show (round (ts * 1000000) :: Integer)))

syncSequences :: Pool -> IO ()
syncSequences pool = do
  execSQL pool "SELECT setval('object_id_seq', COALESCE((SELECT MAX(id) FROM object), 1), TRUE)"
  execSQL pool "SELECT setval('payment_id_seq', COALESCE((SELECT MAX(id) FROM payment), 1), TRUE)"
  execSQL pool "SELECT setval('goods_price_id_seq', COALESCE((SELECT MAX(id) FROM goods_price), 1), TRUE)"

execSQL :: Pool -> T.Text -> IO ()
execSQL pool sql = runStatement pool () stmt
  where
    stmt = Statement.unpreparable sql E.noParams D.noResult
