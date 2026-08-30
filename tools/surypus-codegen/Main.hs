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
import Data.Char (toUpper)
import Control.Monad (forM_)
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
  , dsRefinements       :: ![Refinement]
  , dsEvents            :: ![DomainEvent]
  , dsEntities          :: ![Entity]
  } deriving (Show, Generic)

instance FromJSON DslSchema where
  parseJSON = withObject "DslSchema" $ \o -> do
    version <- o .: "version"
    domain  <- o .: "domain"
    database <- o .: "database"
    generator <- o .: "generator"
    genVer  <- o .: "generator_version"
    refinements <- o .:? "refinements" .!= []
    events <- o .:? "events" .!= []
    entities <- o .: "entities"
    pure DslSchema
      { dsVersion = version
      , dsDomain = domain
      , dsDatabase = database
      , dsGenerator = generator
      , dsGeneratorVersion = genVer
      , dsRefinements = refinements
      , dsEvents = events
      , dsEntities = entities
      }

instance ToJSON DslSchema where
  toJSON DslSchema{..} = object
    [ "version"          .= dsVersion
    , "domain"           .= dsDomain
    , "database"         .= dsDatabase
    , "generator"        .= dsGenerator
    , "generator_version" .= dsGeneratorVersion
    , "refinements"      .= dsRefinements
    , "events"           .= dsEvents
    , "entities"         .= dsEntities
    ]

-- | Refinement predicate (domain invariant), encoded in the DSL (Phase 12).
data Refinement = Refinement
  { rfName        :: !T.Text
  , rfDescription :: !T.Text
  , rfAppliesTo   :: ![T.Text]
  , rfExpr        :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON Refinement where
  parseJSON = withObject "Refinement" $ \o -> do
    name <- o .: "name"
    desc <- o .:? "description" .!= T.empty
    applies <- o .:? "applies_to" .!= []
    expr <- o .: "expr"
    pure Refinement { rfName = name, rfDescription = desc, rfAppliesTo = applies, rfExpr = expr }

instance ToJSON Refinement where
  toJSON Refinement{..} = object
    [ "name" .= rfName, "description" .= rfDescription, "applies_to" .= rfAppliesTo, "expr" .= rfExpr ]

-- | Domain event (event-sourced), encoded in the DSL (Phase 12).
data DomainEvent = DomainEvent
  { evName        :: !T.Text
  , evAggregate   :: !T.Text
  , evDescription :: !T.Text
  , evFields      :: ![T.Text]
  } deriving (Show, Eq, Generic)

instance FromJSON DomainEvent where
  parseJSON = withObject "DomainEvent" $ \o -> do
    name <- o .: "name"
    agg <- o .:? "aggregate" .!= T.empty
    desc <- o .:? "description" .!= T.empty
    fs <- o .:? "fields" .!= []
    pure DomainEvent { evName = name, evAggregate = agg, evDescription = desc, evFields = fs }

instance ToJSON DomainEvent where
  toJSON DomainEvent{..} = object
    [ "name" .= evName, "aggregate" .= evAggregate, "description" .= evDescription, "fields" .= evFields ]

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
  , "    id BIGSERIAL NOT NULL,"
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
                            ++ " ON " ++ T.unpack entitySqlTable ++ " (" ++ T.unpack (fieldName f) ++ ");") indexed

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

-- | Generate functional QML CRUD artifacts for every entity.
-- Produces, per entity, a list screen (<Entity>Screen.qml) and a create/edit
-- dialog (<Entity>Dialog.qml) that follow the same convention as the hand-written
-- Bills.qml / BillDialog.qml (signals wired in Main.qml). The generator is the
-- "codegen for all entities" deliverable of Phase 13.
generateQmlCrud :: DslSchema -> [(FilePath, String)]
generateQmlCrud schema =
  [ (qmlScreenPath e, generateQmlScreen e) | e <- dsEntities schema ]
  ++ [ (qmlDialogPath e, generateQmlDialog e) | e <- dsEntities schema ]
  where
    qmlScreenPath Entity{entityName} =
      "frontend/qml/screens/" ++ T.unpack entityName ++ "Screen.qml"
    qmlDialogPath Entity{entityName} =
      "frontend/qml/components/dialogs/" ++ T.unpack entityName ++ "Dialog.qml"

-- | Map a field type to a QML control (lines) and to a JS expression that
-- reads its value.
qmlFieldControl :: Field -> (String, String, String)
qmlFieldControl f@Field{fieldName, fieldType} =
  let n = T.unpack fieldName
  in case fieldType of
       FTBoolean ->
         ( "CheckBox { text: " ++ show n ++ "; id: " ++ ctrlId n ++ " }"
         , "checked"
         , "(payload[" ++ show n ++ "] = " ++ ctrlId n ++ ".checked)"
         )
       FTInteger -> numericField n "int"
       FTSerial  -> numericField n "int"
       FTBigInt  -> numericField n "int"
       FTNumeric -> numericField n "real"
       FTReal    -> numericField n "real"
       FTDouble  -> numericField n "real"
       FTDate    -> textField n "yyyy-MM-dd"
       FTTimestamp -> textField n "yyyy-MM-ddThh:mm:ss"
       FTTime    -> textField n "hh:mm:ss"
       _         -> textField n ""  -- Text / Varchar / Jsonb / etc.
  where
    ctrlId n = "fld_" ++ filter (/= ' ') n
    textField n ph =
      ( "TextField { placeholderText: " ++ show (if null ph then n else n ++ " (" ++ ph ++ ")")
        ++ "; id: " ++ ctrlId n ++ "; width: parent.width }"
      , "text"
      , "(payload[" ++ show n ++ "] = " ++ ctrlId n ++ ".text)"
      )
    numericField n kind =
      ( "TextField { placeholderText: " ++ show (n ++ " (" ++ kind ++ ")")
        ++ "; id: " ++ ctrlId n ++ "; width: parent.width; inputMethodHints: Qt.ImhFormattedNumbersOnly }"
      , "text"
      , "(payload[" ++ show n ++ "] = " ++ ctrlId n ++ ".text === \"\" ? null : Number(" ++ ctrlId n ++ ".text))"
      )

-- | List screen for an entity.
generateQmlScreen :: Entity -> String
generateQmlScreen e@Entity{entityName, entityFields} =
  unlines $
  [ "// Generated by surypus-codegen — DO NOT EDIT MANUALLY"
  , "import QtQuick 2.15"
  , "import QtQuick.Controls 2.15"
  , "import QtQuick.Layouts 1.15"
  , ""
  , "Page {"
  , "    id: root"
  , "    title: " ++ show (T.unpack entityName)
  , ""
  , "    // Wire these signals in Main.qml to the RestClient calls, e.g."
  , "    //   onLoadRequested: restClient.load" ++ cap entityName ++ "s()"
  , "    //   onCreateRequested: restClient.create" ++ cap entityName ++ "(payload)"
  , "    signal loadRequested()"
  , "    signal createRequested(var payload)"
  , "    signal editRequested(var payload)"
  , ""
  , "    Component.onCompleted: root.loadRequested()"
  , ""
  , "    ListView {"
  , "        id: listView"
  , "        anchors.fill: parent"
  , "        anchors.margins: 12"
  , "        model: " ++ cap entityName ++ "sModel"
  , "        delegate: ItemDelegate {"
  , "            text: modelData.code !== undefined ? modelData.code : JSON.stringify(modelData)"
  , "            width: listView.width"
  , "            onClicked: root.editRequested(modelData)"
  , "        }"
  , "    }"
  , ""
  , "    footer: ToolBar {"
  , "        ToolButton { text: \"Refresh\"; onClicked: root.loadRequested() }"
  , "        ToolButton { text: \"New\"; onClicked: dlg.open() }"
  , "    }"
  , ""
  , "    " ++ cap entityName ++ "Dialog {"
  , "        id: dlg"
  , "        onCreated: function(payload) { root.createRequested(payload); dlg.close() }"
  , "    }"
  , "}"
  , ""
  , "// Generated by surypus-codegen"
  ]
  where cap s = case T.unpack s of
          [] -> []
          (c:cs) -> toUpper c : cs

-- | Create/edit dialog for an entity.
generateQmlDialog :: Entity -> String
generateQmlDialog e@Entity{entityName, entityFields} =
  unlines $
  [ "// Generated by surypus-codegen — DO NOT EDIT MANUALLY"
  , "import QtQuick 2.15"
  , "import QtQuick.Controls 2.15"
  , "import QtQuick.Layouts 1.15"
  , ""
  , "Dialog {"
  , "    id: root"
  , "    title: " ++ show ("Create " ++ T.unpack entityName)
  , "    modal: true"
  , "    standardButtons: Dialog.Ok | Dialog.Cancel"
  , "    signal created(var payload)"
  , "    property var initial: null"
  , ""
  , "    onAboutToShow: {"
  , "        if (root.initial) {"
  , "            // prefill controls from initial"
  , unlines [ "            if (typeof " ++ cid ++ " !== 'undefined') " ++ cid ++ (if isBool then ".checked = root.initial[" ++ show (T.unpack fn) ++ "] === true" else ".text = root.initial[" ++ show (T.unpack fn) ++ "] !== undefined && root.initial[" ++ show (T.unpack fn) ++ "] !== null ? String(root.initial[" ++ show (T.unpack fn) ++ "]) : \"\"") | f@Field{fieldName=fn,fieldType=ft} <- entityFields, let cid = ctrlIdName fn, let isBool = ft == FTBoolean ]
  , "        } else {"
  , unlines [ "            if (typeof " ++ cid ++ " !== 'undefined') " ++ cid ++ (if isBool then ".checked = false" else ".text = \"\"") | f@Field{fieldName=fn,fieldType=ft} <- entityFields, let cid = ctrlIdName fn, let isBool = ft == FTBoolean ]
  , "        }"
  , "    }"
  , ""
  , "    contentItem: ScrollView {"
  , "        width: 420; height: Math.min(implicitHeight, 480)"
  , "        ColumnLayout {"
  , "            width: parent.width"
  , "            spacing: 8"
  ]
  ++ concatMap fieldLine entityFields
  ++ [ "        }"
  , "    }"
  , ""
  , "    onAccepted: {"
  , "        var payload = {};"
  ]
  ++ concatMap (\f@Field{fieldName} -> ["        " ++ payloadExpr f]) entityFields
  ++ [ "        if (root.initial && root.initial.id !== undefined) payload.id = root.initial.id;"
  , "        root.created(payload);"
  , "    }"
  , "}"
  , ""
  , "// Generated by surypus-codegen"
  ]
  where
    ctrlIdName fn = "fld_" ++ filter (/= ' ') (T.unpack fn)
    fieldLine f =
      let (control, _, _) = qmlFieldControl f
      in [ "            " ++ control
         , "            Label { text: " ++ show (T.unpack (fieldName f)) ++ "; font.pointSize: 10 }"
         ]
    payloadExpr f =
      let (_, _, expr) = qmlFieldControl f in expr

-- | Build all generated files
-- | Generate refinement-predicate + event documentation from the DSL (Phase 12).
generateRefinementDoc :: DslSchema -> String
generateRefinementDoc schema =
  let refLines = concatMap (\r ->
        [ "### " ++ T.unpack (rfName r)
        , ""
        , "**Applies to:** " ++ (if null (rfAppliesTo r) then "(global)" else intercalate ", " (map T.unpack (rfAppliesTo r)))
        , ""
        , if T.null (rfDescription r) then "" else T.unpack (rfDescription r)
        , ""
        , "```liquidhaskell"
        , T.unpack (rfExpr r)
        , "```"
        , ""
        ]) (dsRefinements schema)
      evLines = concatMap (\e ->
        [ "### " ++ T.unpack (evName e)
        , ""
        , "**Aggregate:** " ++ (if T.null (evAggregate e) then "(unspecified)" else T.unpack (evAggregate e))
        , ""
        , if T.null (evDescription e) then "" else T.unpack (evDescription e)
        , ""
        , "**Fields:** " ++ (if null (evFields e) then "(none)" else intercalate ", " (map T.unpack (evFields e)))
        , ""
        ]) (dsEvents schema)
  in unlines $
     [ "# Surypus DSL — Refinement Predicates & Domain Events"
     , ""
     , "This document is **generated** by `surypus-codegen doc` from `dsl/schema.yaml`."
     , "Do not edit by hand; edit the DSL `refinements:` / `events:` sections and re-run `build`."
     , ""
     , "## Refinement predicates (" ++ show (length (dsRefinements schema)) ++ ")"
     , ""
     ] ++ (if null (dsRefinements schema) then ["_No refinements declared in the DSL yet._",""] else refLines)
     ++ [ "## Domain events (" ++ show (length (dsEvents schema)) ++ ")"
     , ""
     ] ++ (if null (dsEvents schema) then ["_No events declared in the DSL yet._",""] else evLines)

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

  -- Generate functional QML CRUD screens + dialogs for every entity (Phase 13)
  let qmlFiles = generateQmlCrud schema
  forM_ qmlFiles $ \(rel, content) -> do
    let outPath = repoRoot </> rel
    createDirectoryIfMissing True (takeDirectory outPath)
    writeFile outPath content

  -- Generate refinement/event documentation from DSL (Phase 12)
  createDirectoryIfMissing True (repoRoot </> "docs")
  writeFile (repoRoot </> "docs" </> "refinements.md") (generateRefinementDoc schema)

  hPutStrLn stderr "Generated: src/DAL/Schema.hs"
  hPutStrLn stderr "Generated: src/DAL/Types.hs"
  hPutStrLn stderr "Generated: sql/migrations/V001__generated_orm.sql"
  forM_ qmlFiles $ \(rel, _) ->
    hPutStrLn stderr $ "Generated: " ++ rel
  hPutStrLn stderr $ "Build complete. " ++ show (length qmlFiles) ++ " QML CRUD file(s) generated."
  putStrLn $ "[OK] Generated " ++ show (2 + 1 + length qmlFiles) ++ " files"

-- | Check: compare generated against DSL
check :: IO ()
check = do
  schema <- loadSchema
  _ <- pure $ generateSchemaHaskell schema
  _ <- pure $ generateTypesHaskell schema
  _ <- pure $ generateTableSQL schema
  _ <- pure $ generateDatalogRules schema
  _ <- pure $ generateQmlSchema schema
  _ <- pure $ generateQmlCrud schema
  _ <- pure $ generateRefinementDoc schema
  hPutStrLn stderr "Checking generated files against DSL..."
  let nQml = length (generateQmlCrud schema)
  putStrLn $ "[OK] Checked " ++ show (5 + nQml) ++ " generated files against DSL"

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

-- | Doc: generate docs/refinements.md from the DSL (refinements + events).
doc :: IO ()
doc = do
  schema <- loadSchema
  repoRoot <- findRepoRoot
  createDirectoryIfMissing True (repoRoot </> "docs")
  writeFile (repoRoot </> "docs" </> "refinements.md") (generateRefinementDoc schema)
  hPutStrLn stderr "Generated: docs/refinements.md"
  putStrLn "[OK] Refinement documentation generated from DSL"

showHelp :: IO ()
showHelp = do
  programName <- getProgName
  putStrLn $ "Usage: " ++ programName ++ " [COMMAND] [OPTIONS]"
  putStrLn ""
  putStrLn "Commands:"
  putStrLn "  build     Generate all artifacts from dsl/schema.yaml"
  putStrLn "  check     Verify generated files match DSL"
  putStrLn "  doc       Generate docs/refinements.md from DSL (refinements + events)"
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
    ("doc":_) -> doc
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