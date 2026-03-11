-- | ImportExport module - Data import/export
module Core.ImportExport where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | ImportTemplate - Import template
data ImportTemplate = ImportTemplate
  { itId         :: Int64
  , itName       :: Text
  , itObjectType :: Int64
  , itMapping    :: Text  -- JSON column mapping
  , itFlags      :: Int
  } deriving (Show, Eq)

-- | ImportSession - Import session
data ImportSession = ImportSession
  { isId            :: Int64
  , isTemplateId    :: Int64
  , isFileName      :: Text
  , isDate          :: Day
  , isStatus        :: ImportStatus
  , isTotalRows     :: Int
  , isProcessedRows:: Int
  , isErrorRows     :: Int
  } deriving (Show, Eq)

data ImportStatus = IS_Pending | IS_InProgress | IS_Completed | IS_Failed
  deriving (Show, Eq)

-- | ExportTemplate - Export template
data ExportTemplate = ExportTemplate
  { etId         :: Int64
  , etName       :: Text
  , etObjectType :: Int64
  , etQuery      :: Text
  , etFormat     :: ExportFormat
  } deriving (Show, Eq)

data ExportFormat = EF_CSV | EF_XLSX | EF_XML | EF_JSON
  deriving (Show, Eq)
