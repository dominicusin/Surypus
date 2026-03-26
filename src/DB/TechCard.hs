{-# LANGUAGE OverloadedStrings #-}

module DB.TechCard
  ( listTechCards,
    getTechCard,
    createTechCard,
    addTechLine,
    listTechLines,
  )
where

import Core.Production.Types (TechCard (..), TechLine (..))
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

techCardRow :: D.Row TechCard
techCardRow =
  TechCard
    <$> (Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nullable D.text)

techLineRow :: D.Row TechLine
techLineRow =
  TechLine
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)

listTechCards :: Pool -> IO [TechCard]
listTechCards pool =
  use pool $
    Session.statement () stmt
  where
    stmt =
      Statement
        "SELECT id, processor_id, goods_group_id, kind, code, flags, formula FROM tech_card ORDER BY id"
        E.noParams
        (D.rowList techCardRow)
        False

getTechCard :: Pool -> Int64 -> IO (Maybe TechCard)
getTechCard pool tid =
  use pool $
    Session.statement tid stmt
  where
    stmt =
      Statement
        "SELECT id, processor_id, goods_group_id, kind, code, flags, formula FROM tech_card WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe techCardRow)
        False

createTechCard :: Pool -> Int64 -> Int64 -> Int -> Maybe Text -> IO Int64
createTechCard pool pid gid kind formula =
  use pool $
    Session.statement (pid, gid, kind, formula) stmt
  where
    stmt =
      Statement
        "SELECT create_tech_card($1,$2,$3,$4)"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.text)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))
        False

addTechLine :: Pool -> Int64 -> Maybe Int -> Int64 -> Double -> Int -> Maybe Text -> Maybe Double -> Maybe Double -> IO ()
addTechLine pool techId lineNo goodsId qty sign formula lineTime lineCost =
  use pool $
    Session.statement (techId, lineNo, goodsId, qty, sign, formula, lineTime', lineCost') stmt Data.Functor.$> ()
  where
    lineTime' = fromMaybe 0 lineTime -- hlint: ignore
    lineCost' = fromMaybe 0 lineCost -- hlint: ignore
    stmt =
      Statement
        "SELECT add_tech_line($1,$2,$3,$4,$5,$6,$7,$8)"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nullable E.int4)
            <> E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nonNullable E.float8)
        )
        D.noResult
        False

listTechLines :: Pool -> Int64 -> IO [TechLine]
listTechLines pool techId =
  use pool $
    Session.statement techId stmt
  where
    stmt =
      Statement
        "SELECT tech_card_id, line_no, goods_id, qty, sign, formula, line_time, line_cost \
        \FROM tech_line WHERE tech_card_id = $1 ORDER BY line_no"
        (E.param (E.nonNullable E.int8))
        (D.rowList techLineRow)
        False
