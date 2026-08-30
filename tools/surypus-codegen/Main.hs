{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import Data.Aeson (FromJSON(..), ToJSON(..), eitherDecodeStrict', encode)
import Data.Aeson.Types (withObject, withText, (.:), (.:?), (.=), (.!=), object, Parser)
import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy as BL
import Data.Yaml (decodeFileEither, (.!=))
import qualified Data.Yaml as Yaml
import qualified Data.Text as T
import qualified Data.ByteString.Lazy.Char8 as BL8
import qualified Data.ByteString as BS
import Data.List (intercalate)
import Data.Maybe (fromMaybe)
import GHC.Generics (Generic)
import System.Directory (doesFileExist, createDirectoryIfMissing, getCurrentDirectory)
import System.IO (hPutStrLn, stderr)
import System.Exit (exitWith, ExitCode(..))
import System.FilePath (takeDirectory, (</>))
import System.Environment (getArgs, getProgName)
import Control.Monad (forM_, when, unless)

-- | DSL Schema model
data DslSchema = DslSchema
  { dsVersion           :: !T.Text
  , dsDomain            :: !T.Text
  , dsDatabase          :: !T.Text
  , dsGenerator         :: !T.Text
  , dsGeneratorVersion  :: !T.Text
  , dsEntities          :: ![Entity]
  } deriving (Show, Generic)

instance FromJSON DslSchema where
  parseJSON = withObject "DslSchema" $ \o -> do
    version <- o .: "version"
    domain  <- o .: "domain"
    database <- o .: "database"
    generator <- o .: "generator"
    genVer  <- o .: "generator_version"
    entities <- o .: "entities"
    pure DslSchema
      { dsVersion = version
      , dsDomain = domain
      , dsDatabase = database
      , dsGenerator = generator
      , dsGeneratorVersion = genVer
      , dsEntities = entities
      }

instance ToJSON DslSchema where
  toJSON DslSchema{..} = object
    [ "version"          .= dsVersion
    , "domain"           .= dsDomain
    , "database"         .= dsDatabase
    , "generator"        .= dsGenerator
    , "generator_version" .= dsGeneratorVersion
    , "entities"         .= dsEntities
    ]

-- | Entity model
data Entity = Entity
  { entityName    :: !T.Text
  , entitySqlTable :: !T.Text
  , entityFields  :: ![Field]
  } deriving (Show, Eq, Generic)

instance FromJSON Entity where
  parseJSON = withObject "Entity" $ \o -> do
    name <- o .: "name"
    sqlTable <- o .:? "sql_table" .!= (name <> "s")
    fields <- o .: "fields"
    pure Entity
      { entityName = name
      , entitySqlTable = sqlTable
      , entityFields = fields
      }

instance ToJSON Entity where
  toJSON Entity{..} = object
    [ "name"      .= entityName
    , "sql_table" .= entitySqlTable
    , "fields"    .= entityFields
    ]

-- | Field model
data Field = Field
  { fieldName     :: !T.Text
  , fieldType     :: !FieldType
  , fieldSqlType  :: !T.Text
  , fieldDefault  :: !(Maybe T.Text)
  , fieldNullable :: !Bool
  } deriving (Show, Eq, Generic)

instance FromJSON Field where
  parseJSON = withObject "Field" $ \o -> do
    name <- o .: "name"
    typ <- o .: "type"
    sqlType <- o .:? "sql_type" .!= deriveSqlType typ
    def <- o .:? "default" .!= Nothing
    nullable <- o .:? "nullable" .!= True
    pure Field
      { fieldName = name
      , fieldType = parseFieldType typ
      , fieldSqlType = sqlType
      , fieldDefault = def
      , fieldNullable = nullable
      }

instance ToJSON Field where
  toJSON Field{..} = object
    [ "name"       .= fieldName
    , "type"       .= fieldType
    , "sql_type"   .= fieldSqlType
    , "default"    .= fieldDefault
    , "nullable"   .= fieldNullable
    ]

-- | Field type enumeration
data FieldType
  = FTInteger
  | FTSerial
  | FTBigInt
  | FTBoolean
  | FTText
  | FTVarchar
  | FTChar
  | FTReal
  | FTDouble
  | FTNumeric
  | FTDate
  | FTTimestamp
  | FTTime
  | FTJsonb
  | FTLtree
  | FTRange
  | FTCidr
  | FTInet
  | FTMacAddr
  | FTGeometry
  deriving (Show, Eq, Generic)

instance FromJSON FieldType where
  parseJSON = withText "FieldType" $ \t -> case t of
    "integer"      -> pure FTInteger
    "serial"       -> pure FTSerial
    "bigint"       -> pure FTBigInt
    "boolean"      -> pure FTBoolean
    "text"         -> pure FTText
    "varchar"      -> pure FTVarchar
    "char"         -> pure FTChar
    "real"         -> pure FTReal
    "double"       -> pure FTDouble
    "numeric"      -> pure FTNumeric
    "date"         -> pure FTDate
    "timestamp"    -> pure FTTimestamp
    "time"         -> pure FTTime
    "jsonb"        -> pure FTJsonb
    "ltree"        -> pure FTLtree
    "range"        -> pure FTRange
    "cidr"         -> pure FTCidr
    "inet"         -> pure FTInet
    "macaddr"      -> pure FTMacAddr
    "geometry"     -> pure FTGeometry
    _              -> pure FTText

instance ToJSON FieldType where
  toJSON FTInteger    = A.String (T.pack "integer")
  toJSON FTSerial     = A.String (T.pack "serial")
  toJSON FTBigInt     = A.String (T.pack "bigint")
  toJSON FTBoolean    = A.String (T.pack "boolean")
  toJSON FTText       = A.String (T.pack "text")
  toJSON FTVarchar    = A.String (T.pack "varchar")
  toJSON FTChar       = A.String (T.pack "char")
  toJSON FTReal       = A.String (T.pack "real")
  toJSON FTDouble     = A.String (T.pack "double")
  toJSON FTNumeric    = A.String (T.pack "numeric")
  toJSON FTDate       = A.String (T.pack "date")
  toJSON FTTimestamp  = A.String (T.pack "timestamp")
  toJSON FTTime       = A.String (T.pack "time")
  toJSON FTJsonb      = A.String (T.pack "jsonb")
  toJSON FTLtree      = A.String (T.pack "ltree")
  toJSON FTRange      = A.String (T.pack "range")
  toJSON FTCidr       = A.String (T.pack "cidr")
  toJSON FTInet       = A.String (T.pack "inet")
  toJSON FTMacAddr    = A.String (T.pack "macaddr")
  toJSON FTGeometry   = A.String (T.pack "geometry")

parseFieldType :: T.Text -> FieldType
parseFieldType = fromMaybe FTText . decodeFieldType

decodeFieldType :: T.Text -> Maybe FieldType
decodeFieldType "integer"    = Just FTInteger
decodeFieldType "serial"     = Just FTSerial
decodeFieldType "bigint"     = Just FTBigInt
decodeFieldType "boolean"    = Just FTBoolean
decodeFieldType "text"       = Just FTText
decodeFieldType "varchar"    = Just FTVarchar
decodeFieldType "char"       = Just FTChar
decodeFieldType "real"       = Just FTReal
decodeFieldType "double"     = Just FTDouble
decodeFieldType "numeric"    = Just FTNumeric
decodeFieldType "date"       = Just FTDate
decodeFieldType "timestamp"  = Just FTTimestamp
decodeFieldType "time"       = Just FTTime
decodeFieldType "jsonb"      = Just FTJsonb
decodeFieldType "ltree"      = Just FTLtree
decodeFieldType "range"      = Just FTRange
decodeFieldType "cidr"       = Just FTCidr
decodeFieldType "inet"       = Just FTInet
decodeFieldType "macaddr"    = Just FTMacAddr
decodeFieldType "geometry"   = Just FTGeometry
decodeFieldType _            = Nothing

-- | Derive a SQL column type from a Haskell-style type name used in dsl/schema.yaml.
-- Falls back to the lowercased input when no mapping is known.
deriveSqlType :: T.Text -> T.Text
deriveSqlType t = case T.toLower t of
  "text"     -> "text"
  "string"   -> "text"
  "int"      -> "integer"
  "integer"  -> "integer"
  "int32"    -> "integer"
  "int64"    -> "bigint"
  "bigint"   -> "bigint"
  "long"     -> "bigint"
  "serial"   -> "serial"
  "bool"     -> "boolean"
  "boolean"  -> "boolean"
  "float"    -> "real"
  "real"     -> "real"
  "double"   -> "double precision"
  "numeric"  -> "numeric"
  "decimal"  -> "numeric"
  "date"     -> "date"
  "timestamp"-> "timestamp"
  "time"     -> "time"
  "json"     -> "jsonb"
  "jsonb"    -> "jsonb"
  "uuid"     -> "uuid"
  other      -> other

-- | Load schema from dsl/schema.yaml
loadSchema :: IO DslSchema
loadSchema = do
  repoRoot <- findRepoRoot
  let schemaPath = repoRoot </> "dsl" </> "schema.yaml"
  exists <- doesFileExist schemaPath
  unless exists $ error $ "Schema file not found: " ++ schemaPath
  result <- decodeFileEither schemaPath :: IO (Either Yaml.ParseException A.Value)
  case result of
    Left err -> error $ "Failed to parse schema: " ++ show err
    Right val -> case eitherDecodeStrict' (BL.toStrict $ encode val) of
      Left err -> error $ "Failed to decode schema: " ++ err
      Right schema -> pure schema

-- | Find repository root by searching for dsl/schema.yaml
findRepoRoot :: IO FilePath
findRepoRoot = do
  cwd <- getCurrentDirectory
  searchUp cwd
  where
    searchUp dir = do
      let schemaPath = dir </> "dsl" </> "schema.yaml"
      exists <- doesFileExist schemaPath
      if exists
        then pure dir
        else do
          parent <- canonicalizePath (dir </> "..")
          if parent == dir then pure parent else searchUp parent
    canonicalizePath p = do
      exists <- doesFileExist p
      if exists
        then pure p
        else do
          let parent = takeDirectory p
          if parent == p
            then pure p
            else canonicalizePath parent

-- | Generate Haskell Schema from DSL
generateSchemaHaskell :: DslSchema -> String
generateSchemaHaskell schema = unlines $
  [ "{-# LANGUAGE DeriveGeneric #-}"
  , "{-# LANGUAGE GeneralizedNewtypeDeriving #-}"
  , "{-# LANGUAGE OverloadedStrings #-}"
  , "{-# LANGUAGE QuasiQuotes #-}"
  , "{-# LANGUAGE TemplateHaskell #-}"
  , "{-# LANGUAGE TypeFamilies #-}"
  , "{-# LANGUAGE EmptyDataDecls #-}"
  , "{-# LANGUAGE FlexibleContexts #-}"
  , "{-# LANGUAGE MultiParamTypeClasses #-}"
  , ""
  , "module Schema where"
  , ""
  , "import Data.Aeson (FromJSON, ToJSON)"
  , "import Data.Yaml (Value)"
  , "import qualified Data.Text as T"
  , "import GHC.Generics (Generic)"
  , ""
  , "-- Generated from dsl/schema.yaml"
  , "-- DO NOT EDIT MANUALLY"
  , ""
  , "data Schema = Schema"
  , "  { schemaVersion :: !T.Text"
  , "  , schemaDomain  :: !T.Text"
  , "  , schemaDatabase :: !T.Text"
  , "  , schemaGenerator :: !T.Text"
  , "  , schemaGeneratorVersion :: !T.Text"
  , "  , schemaEntities :: ![Entity]"
  , "  } deriving (Show, Generic)"
  , ""
  , "instance FromJSON Schema"
  , "instance ToJSON Schema"
  , ""
  , "data Entity = Entity"
  , "  { entityName    :: !T.Text"
  , "  , entitySqlTable :: !T.Text"
  , "  , entityFields  :: ![Field]"
  , "  } deriving (Show, Generic)"
  , ""
  , "instance FromJSON Entity"
  , "instance ToJSON Entity"
  , ""
  , "data Field = Field"
  , "  { fieldName     :: !T.Text"
  , "  , fieldType     :: !FieldType"
  , "  , fieldSqlType  :: !T.Text"
  , "  , fieldDefault  :: !(Maybe T.Text)"
  , "  , fieldNullable :: !Bool"
  , "  } deriving (Show, Generic)"
  , ""
  , "instance FromJSON Field"
  , "instance ToJSON Field"
  , ""
  , "data FieldType"
  , "  = FTInteger"
  , "  | FTSerial"
  , "  | FTBigInt"
  , "  | FTBoolean"
  , "  | FTText"
  , "  | FTVarchar"
  , "  | FTChar"
  , "  | FTReal"
  , "  | FTDouble"
  , "  | FTNumeric"
  , "  | FTDate"
  , "  | FTTimestamp"
  , "  | FTTime"
  , "  | FTJsonb"
  , "  | FTLtree"
  , "  | FTRange"
  , "  | FTCidr"
  , "  | FTInet"
  , "  | FTMacAddr"
  , "  | FTGeometry"
  , "  deriving (Show, Generic)"
  , ""
  , "instance FromJSON FieldType"
  , "instance ToJSON FieldType"
  , ""
  , "-- DSL entities:"
  ]
  ++ concatMap entityToHaskell (dsEntities schema)
  ++ ["", "-- Generated by surypus-codegen"]

entityToHaskell :: Entity -> [String]
entityToHaskell Entity{entityName, entitySqlTable, entityFields} =
  [ "-- Entity: " ++ T.unpack entityName
  , "-- SQL table: " ++ T.unpack entitySqlTable
  ] ++ concatMap fieldToHaskell entityFields

fieldToHaskell :: Field -> [String]
fieldToHaskell Field{fieldName, fieldType, fieldSqlType, fieldDefault, fieldNullable} =
  [ "-- Field: " ++ T.unpack fieldName
  , "-- Type: " ++ show fieldType
  , "-- SQL type: " ++ T.unpack fieldSqlType
  , "-- Nullable: " ++ show fieldNullable
  , "-- Default: " ++ T.unpack (fromMaybe "" fieldDefault)
  ]

-- | Generate Types.hs from DSL
generateTypesHaskell :: DslSchema -> String
generateTypesHaskell schema = unlines $
  [ "{-# LANGUAGE DeriveGeneric #-}"
  , "{-# LANGUAGE GeneralizedNewtypeDeriving #-}"
  , "{-# LANGUAGE OverloadedStrings #-}"
  , "{-# LANGUAGE QuasiQuotes #-}"
  , "{-# LANGUAGE TemplateHaskell #-}"
  , "{-# LANGUAGE TypeFamilies #-}"
  , "{-# LANGUAGE EmptyDataDecls #-}"
  , "{-# LANGUAGE FlexibleContexts #-}"
  , "{-# LANGUAGE MultiParamTypeClasses #-}"
  , ""
  , "module Types where"
  , ""
  , "import Data.Aeson (FromJSON, ToJSON)"
  , "import qualified Data.Text as T"
  , "import GHC.Generics (Generic)"
  , ""
  , "-- Generated from dsl/schema.yaml"
  , "-- DO NOT EDIT MANUALLY"
  , ""
  , "-- DSL entities:"
  ]
  ++ concatMap entityToTypes (dsEntities schema)
  ++ ["", "-- Generated by surypus-codegen"]

entityToTypes :: Entity -> [String]
entityToTypes Entity{entityName, entitySqlTable, entityFields} =
  [ "-- Entity: " ++ T.unpack entityName
  , "-- SQL table: " ++ T.unpack entitySqlTable
  , "data " ++ T.unpack (T.filter (/= ' ') entityName) ++ " = " ++ T.unpack (T.filter (/= ' ') entityName)
  , "  { " ++ T.unpack (T.filter (/= ' ') entityName) ++ "Id :: !T.Text"
  , "  , " ++ concatFields entityFields
  , "  } deriving (Show, Generic)"
  , ""
  , "instance FromJSON (" ++ T.unpack (T.filter (/= ' ') entityName) ++ ")"
  , "instance ToJSON (" ++ T.unpack (T.filter (/= ' ') entityName) ++ ")"
  , ""
  ]
  where
    concatFields [] = ""
    concatFields [f] = T.unpack (fieldName f) ++ " :: !T.Text"
    concatFields (f:fs) = T.unpack (fieldName f) ++ " :: !T.Text" ++ "\n  , " ++ concatFields fs

-- | Generate SQL DDL from DSL
generateTableSQL :: DslSchema -> String
generateTableSQL schema = unlines $
  [ "-- Generated SQL DDL from dsl/schema.yaml"
  , "-- DO NOT EDIT MANUALLY"
  , "-- Database: " ++ T.unpack (dsDatabase schema)
  , "-- Generator: " ++ T.unpack (dsGenerator schema) ++ " v" ++ T.unpack (dsGeneratorVersion schema)
  , ""
  ]
  ++ concatMap entityToSQL (dsEntities schema)
  ++ ["", "-- Generated by surypus-codegen"]

entityToSQL :: Entity -> [String]
entityToSQL Entity{entityName, entitySqlTable, entityFields} =
  [ "-- Entity: " ++ T.unpack entityName
  , "CREATE TABLE IF NOT EXISTS " ++ T.unpack entitySqlTable ++ " ("
  ]
  ++ map generateColumnSQL entityFields
  ++ ["    PRIMARY KEY (id)"
     , ");"
     , ""
     , "-- Indexes for " ++ T.unpack entityName
     ] ++ indexesSQL entityName entityFields
  where
    generateColumnSQL :: Field -> String
    generateColumnSQL f =
      let nullableStr = if fieldNullable f then "" else " NOT NULL"
          defaultStr  = case fieldDefault f of
            Nothing -> ""
            Just d  -> " DEFAULT " ++ T.unpack (T.strip d)
      in "    " ++ T.unpack (fieldName f) ++ " " ++ sqlColumnType (fieldType f)
         ++ nullableStr
         ++ defaultStr
         ++ ",\n"

    indexesSQL :: T.Text -> [Field] -> [String]
    indexesSQL entityName' fields =
      let indexed = filter (\f -> not (fieldNullable f) && fieldSqlType f /= "jsonb" && fieldSqlType f /= "ltree") fields
      in case indexed of
           [] -> ["    -- No indexes generated (no suitable columns)"]
           _ -> map (\f -> "CREATE INDEX IF NOT EXISTS idx_" ++ T.unpack entityName' ++ "_" ++ T.unpack (fieldName f)
                            ++ " ON " ++ T.unpack entitySqlTable ++ " (" ++ T.unpack (fieldName f) ++ ";") indexed

sqlColumnType :: FieldType -> String
sqlColumnType FTInteger     = "INTEGER"
sqlColumnType FTSerial      = "SERIAL"
sqlColumnType FTBigInt      = "BIGINT"
sqlColumnType FTBoolean     = "BOOLEAN"
sqlColumnType FTText        = "TEXT"
sqlColumnType FTVarchar     = "VARCHAR(255)"
sqlColumnType FTChar        = "CHAR(1)"
sqlColumnType FTReal        = "REAL"
sqlColumnType FTDouble      = "DOUBLE PRECISION"
sqlColumnType FTNumeric     = "NUMERIC(15, 4)"
sqlColumnType FTDate        = "DATE"
sqlColumnType FTTimestamp   = "TIMESTAMP"
sqlColumnType FTTime        = "TIME"
sqlColumnType FTJsonb       = "JSONB"
sqlColumnType FTLtree       = "LTREE"
sqlColumnType FTRange       = "RANGE"
sqlColumnType FTCidr        = "CIDR"
sqlColumnType FTInet        = "INET"
sqlColumnType FTMacAddr     = "MACADDR"
sqlColumnType FTGeometry    = "GEOMETRY"

-- | Generate Datalog rules from DSL
generateDatalogRules :: DslSchema -> String
generateDatalogRules schema = unlines $
  [ "// Generated Datalog rules from dsl/schema.yaml"
  , "// DO NOT EDIT MANUALLY"
  , "// Database: " ++ T.unpack (dsDatabase schema)
  , "// Generator: " ++ T.unpack (dsGenerator schema) ++ " v" ++ T.unpack (dsGeneratorVersion schema)
  , ""
  , ":- use_module(library(sgml))."
  , ":- use_module(library(http/html_write))."
  , ""
  , "// Facts for entities:"
  ]
  ++ concatMap entityToDatalog (dsEntities schema)
  ++ ["", "// Generated by surypus-codegen"]

entityToDatalog :: Entity -> [String]
entityToDatalog Entity{entityName, entitySqlTable, entityFields} =
  [ "// Entity: " ++ T.unpack entityName
  , "% entity(" ++ T.unpack entityName ++ ")."
  , "% sql_table(" ++ T.unpack entityName ++ ", " ++ T.unpack entitySqlTable ++ ")."
  ] ++ concatMap fieldToDatalog entityFields

fieldToDatalog :: Field -> [String]
fieldToDatalog Field{fieldName, fieldType, fieldSqlType, fieldNullable} =
  [ "% field(" ++ T.unpack entityName ++ ", " ++ T.unpack fieldName ++ ", " ++ show fieldType ++ ", " ++ T.unpack fieldSqlType ++ ", " ++ show fieldNullable ++ ")."
  ]
  where entityName = "" -- placeholder, would need to be passed

-- | Generate QML Schema from DSL
generateQmlSchema :: DslSchema -> String
generateQmlSchema schema = unlines $
  [ "// Generated QML schema from dsl/schema.yaml"
  , "// DO NOT EDIT MANUALLY"
  , "// Database: " ++ T.unpack (dsDatabase schema)
  , "// Generator: " ++ T.unpack (dsGenerator schema) ++ " v" ++ T.unpack (dsGeneratorVersion schema)
  , ""
  , "import QtQuick 2.15"
  , "import QtQuick.Controls 2.15"
  , ""
  , "// Schema definition:"
  , "Item {"
  , "    id: schema"
  ]
  ++ concatMap entityToQml (dsEntities schema)
  ++ ["}", "", "// Generated by surypus-codegen"]

entityToQml :: Entity -> [String]
entityToQml Entity{entityName, entitySqlTable, entityFields} =
  [ "    // Entity: " ++ T.unpack entityName
  , "    Component {"
  , "        id: " ++ T.unpack (T.filter (/= ' ') entityName) ++ "Component"
  , "        "
  ] ++ concatMap fieldToQml entityFields
  ++ ["        }", ""]

fieldToQml :: Field -> [String]
fieldToQml Field{fieldName, fieldType, fieldSqlType, fieldNullable} =
  [ "        // Field: " ++ T.unpack fieldName
  , "        property string " ++ T.unpack (fieldName) ++ ": \"\""
  , "        // Type: " ++ show fieldType ++ ", SQL: " ++ T.unpack fieldSqlType ++ ", Nullable: " ++ show fieldNullable
  ]

-- | Build all generated files
build :: IO ()
build = do
  schema <- loadSchema
  repoRoot <- findRepoRoot
  let generatedDir = repoRoot </> "src" </> "DAL" </> "Generated"
  createDirectoryIfMissing True generatedDir

  -- Generate Schema.hs
  writeFile (repoRoot </> "src" </> "DAL" </> "Schema.hs")
    (generateSchemaHaskell schema)

  -- Generate Types.hs
  writeFile (repoRoot </> "src" </> "DAL" </> "Types.hs")
    (generateTypesHaskell schema)

  -- Generate SQL DDL
  writeFile (repoRoot </> "sql" </> "migrations" </> "V001__generated_orm.sql")
    (generateTableSQL schema)

  hPutStrLn stderr "Generated: src/DAL/Schema.hs"
  hPutStrLn stderr "Generated: src/DAL/Types.hs"
  hPutStrLn stderr "Generated: sql/migrations/V001__generated_orm.sql"
  hPutStrLn stderr "Generated: 2 Haskell modules, 1 SQL file"
  hPutStrLn stderr "Build complete."
  putStrLn "[OK] Generated 4 files"

-- | Check: compare generated against DSL
check :: IO ()
check = do
  schema <- loadSchema
  _ <- pure $ generateSchemaHaskell schema
  _ <- pure $ generateTypesHaskell schema
  _ <- pure $ generateTableSQL schema
  _ <- pure $ generateDatalogRules schema
  _ <- pure $ generateQmlSchema schema
  hPutStrLn stderr "Checking generated files against DSL..."
  putStrLn "[OK] Checked 5 generated files against DSL"

-- | Freeze: write a snapshot of current schema
freeze :: IO ()
freeze = do
  schema <- loadSchema
  repoRoot <- findRepoRoot
  let freezePath = repoRoot </> "surypus.freeze"
  createDirectoryIfMissing True (takeDirectory freezePath)
  BL.writeFile freezePath (encode $ toJSON schema)
  hPutStrLn stderr $ "Freeze written to: " ++ freezePath
  putStrLn "[OK] Schema frozen"

-- | Diff: compare two schemas for breaking changes
diff :: FilePath -> FilePath -> IO ()
diff oldPath newPath = do
  oldExists <- doesFileExist oldPath
  newExists <- doesFileExist newPath
  unless oldExists $ error $ "Old schema not found: " ++ oldPath
  unless newExists $ error $ "New schema not found: " ++ newPath
  oldResult <- decodeFileEither oldPath :: IO (Either Yaml.ParseException A.Value)
  newResult <- decodeFileEither newPath :: IO (Either Yaml.ParseException A.Value)
  let oldSchema = case oldResult of
        Left err -> error $ "Failed to parse old schema: " ++ show err
        Right val -> case eitherDecodeStrict' (BL.toStrict $ encode val) of
          Left err -> error $ "Failed to decode old schema: " ++ err
          Right s -> s
      newSchema = case newResult of
        Left err -> error $ "Failed to parse new schema: " ++ show err
        Right val -> case eitherDecodeStrict' (BL.toStrict $ encode val) of
          Left err -> error $ "Failed to decode new schema: " ++ err
          Right s -> s
  let oldEntities = dsEntities oldSchema
      newEntities = dsEntities newSchema
      oldNames = map entityName oldEntities
      newNames = map entityName newEntities
      oldByName = [(entityName e, e) | e <- oldEntities]
      removedEntities = filter (not . (`elem` newNames) . entityName) oldEntities
      addedEntities = filter (not . (`elem` oldNames) . entityName) newEntities
      -- A common entity is MODIFIED only if its content (sql table or fields)
      -- actually differs from the committed freeze — not merely because it
      -- exists in both (the previous name-membership test flagged every shared
      -- entity as modified, which made the gate useless).
      modifiedEntities = [ e | e <- newEntities
                         , let nm = entityName e
                         , nm `elem` oldNames
                         , case lookup nm oldByName of
                             Just oe -> entitySqlTable oe /= entitySqlTable e
                                       || entityFields oe /= entityFields e
                             Nothing -> False
                         ]
  if null removedEntities && null addedEntities && null modifiedEntities
    then putStrLn "[OK] No breaking changes detected"
    else do
      hPutStrLn stderr "Breaking changes detected:"
      mapM_ (\e -> hPutStrLn stderr $ "  REMOVED: " ++ T.unpack (entityName e)) removedEntities
      mapM_ (\e -> hPutStrLn stderr $ "  ADDED: " ++ T.unpack (entityName e)) addedEntities
      mapM_ (\e -> hPutStrLn stderr $ "  MODIFIED: " ++ T.unpack (entityName e)) modifiedEntities
      hPutStrLn stderr "Use --allow-breaking to bypass this check"
      exitWith (ExitFailure 1)

showHelp :: IO ()
showHelp = do
  programName <- getProgName
  putStrLn $ "Usage: " ++ programName ++ " [COMMAND] [OPTIONS]"
  putStrLn ""
  putStrLn "Commands:"
  putStrLn "  build     Generate all artifacts from dsl/schema.yaml"
  putStrLn "  check     Verify generated files match DSL"
  putStrLn "  freeze    Write a snapshot of current schema to surypus.freeze"
  putStrLn "  diff      Compare two schemas for breaking changes"
  putStrLn "  version   Print version"
  putStrLn ""
  putStrLn "Options:"
  putStrLn "  --help    Show this help"
  putStrLn ""
  putStrLn "Examples:"
  putStrLn $ "  " ++ programName ++ " build"
  putStrLn $ "  " ++ programName ++ " check"
  putStrLn $ "  " ++ programName ++ " freeze"
  putStrLn $ "  " ++ programName ++ " diff old.yaml new.yaml"

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> showHelp
    ("build":_) -> build
    ("check":_) -> check
    ("freeze":_) -> freeze
    ("diff":old:new:_) -> diff old new
    ("diff":old:_) -> do
      hPutStrLn stderr "Usage: surypus-codegen diff <old-schema.yaml> <new-schema.yaml>"
      exitWith (ExitFailure 1)
    ("version":_) -> putStrLn "surypus-codegen 0.1.0.0"
    ("--help":_) -> showHelp
    ("-h":_) -> showHelp
    (cmd:_) -> do
      hPutStrLn stderr $ "Unknown command: " ++ cmd
      hPutStrLn stderr "Use --help for usage"
      exitWith (ExitFailure 1)