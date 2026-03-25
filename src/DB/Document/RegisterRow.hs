module DB.Document.RegisterRow
  ( documentRegisterRow,
  )
where

import Core.Document.Types (DocumentRegister (..))
import Hasql.Decoders (Row, bool, column, date, int4, int8, nonNullable, nullable, text)

documentRegisterRow :: Row DocumentRegister
documentRegisterRow =
  DocumentRegister
    <$> (Just <$> column (nonNullable int8))
    <*> column (nonNullable int8)
    <*> column (nonNullable int8)
    <*> column (nullable text)
    <*> column (nonNullable text)
    <*> column (nonNullable date)
    <*> column (nullable date)
    <*> column (nullable text)
    <*> column (nonNullable int4)
    <*> column (nullable bool)
    <*> pure Nothing
