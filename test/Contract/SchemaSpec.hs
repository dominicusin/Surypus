{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
module Contract.SchemaSpec where

import Test.Hspec
import Data.Yaml
import qualified Data.ByteString.Char8 as BS
import qualified Data.HashMap.Strict as HM

-- | Load and validate the domain schema
main :: IO ()
main = hspec spec

spec :: Spec
spec = describe "dsl/schema.yaml contract validation" $ do
  it "loads schema.yaml without errors" $ do
    result <- eitherDecodeFileStrict "dsl/schema.yaml" :: IO (Either String Value)
    result `shouldBe` Right (Object HM.empty)

  it "has a version field" $ do
    val <- eitherDecodeFileStrict "dsl/schema.yaml" :: IO (Either String Value)
    case val of
      Right (Object o) -> HM.lookup "version" o `shouldBe` Just (String "1.0.0")
      _ -> expectationFailure "Expected object"
      Left err -> expectationFailure err

  it "has entities defined" $ do
    val <- eitherDecodeFileStrict "dsl/schema.yaml" :: IO (Either String Value)
    case val of
      Right (Object o) -> HM.lookup "entities" o `shouldSatisfy` isJust . fmap isArray
      _ -> expectationFailure "Expected object"
      Left err -> expectationFailure err

  it "all entity names are unique" $ do
    val <- eitherDecodeFileStrict "dsl/schema.yaml" :: IO (Either String Value)
    case val of
      Right (Object o) -> case HM.lookup "entities" o of
        Just (Array entities) -> do
          let names = [e | Object e <- toList entities
                         , Just (String n) <- [HM.lookup "name" e]]
          length names `shouldBe` length (nub names)
        _ -> expectationFailure "Expected array"
      _ -> expectationFailure "Expected object"
      Left err -> expectationFailure err

  it "all fields have a name and type" $ do
    val <- eitherDecodeFileStrict "dsl/schema.yaml" :: IO (Either String Value)
    case val of
      Right (Object o) -> case HM.lookup "entities" o of
        Just (Array entities) -> mapM_ checkEntity (toList entities)
        _ -> expectationFailure "Expected array"
      _ -> expectationFailure "Expected object"
      Left err -> expectationFailure err
    where
      checkEntity entity = case HM.lookup "fields" entity of
        Just (Array fields) -> mapM_ checkField (toList fields)
        _ -> return ()
      checkField field = do
        let name = HM.lookup "name" field
        let ftype = HM.lookup "type" field
        name `shouldSatisfy` isJust
        ftype `shouldSatisfy` isJust

isArray :: Value -> Bool
isArray (Array _) = True
isArray _ = False

isJust :: Maybe a -> Bool
isJust (Just _) = True
isJust Nothing = False

nub :: Eq a => [a] -> [a]
nub = foldr (\x acc -> if x `elem` acc then acc else x:acc) []
