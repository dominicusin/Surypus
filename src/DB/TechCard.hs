module DB.TechCard
  ( listTechCards,
    getTechCard,
    createTechCard,
    addTechLine,
    listTechLines,
  )
where

import Core.Production.Types (TechCard (..), TechLine (..))
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int32, Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

techCardRow :: D.Row TechCard
techCardRow =
  (TechCard . Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nonNullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nullable D.text)

techLineRow :: D.Row TechLine
techLineRow =
  TechLine
    <$> D.column (D.nonNullable D.int8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.float8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)

listTechCards :: Pool -> IO [TechCard]
listTechCards pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      Statement
        "SELECT id, processor_id, goods_group_id, kind, code, flags, formula FROM tech_card ORDER BY id"
        E.noParams
        (D.rowList techCardRow)

getTechCard :: Pool -> Int64 -> IO (Maybe TechCard)
getTechCard pool tid = do
  result <- use pool $ Session.statement tid stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    stmt =
      Statement
        "SELECT id, processor_id, goods_group_id, kind, code, flags, formula FROM tech_card WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe techCardRow)

createTechCard :: Pool -> Int64 -> Int64 -> Int32 -> Maybe Text -> IO Int64
createTechCard pool pid gid kind formula = do
  result <- use pool $ Session.statement (pid, gid, kind, formula) stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    stmt =
      Statement
        "SELECT create_tech_card($1,$2,$3,$4)"
        ( ((\(a, _, _, _) -> a) >$< E.param (E.nonNullable E.int8))
            <> ((\(_, b, _, _) -> b) >$< E.param (E.nonNullable E.int8))
            <> ((\(_, _, c, _) -> c) >$< E.param (E.nonNullable E.int4))
            <> ((\(_, _, _, d) -> d) >$< E.param (E.nullable E.text))
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))

addTechLine :: Pool -> Int64 -> Maybe Int32 -> Int64 -> Double -> Int32 -> Maybe Text -> Maybe Double -> Maybe Double -> IO ()
addTechLine pool techId lineNo goodsId qty sign formula lineTime lineCost = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right _ -> pure ()
    Left _ -> pure ()
  where
    lineTime' = fromMaybe 0 lineTime
    lineCost' = fromMaybe 0 lineCost
    params = (techId, lineNo, goodsId, qty, sign, formula, lineTime', lineCost')
    stmt =
      Statement
        "SELECT add_tech_line($1,$2,$3,$4,$5,$6,$7,$8)"
        ( ((\(a, _, _, _, _, _, _, _) -> a) >$< E.param (E.nonNullable E.int8))
            <> ((\(_, b, _, _, _, _, _, _) -> b) >$< E.param (E.nullable E.int4))
            <> ((\(_, _, c, _, _, _, _, _) -> c) >$< E.param (E.nonNullable E.int8))
            <> ((\(_, _, _, d, _, _, _, _) -> d) >$< E.param (E.nonNullable E.float8))
            <> ((\(_, _, _, _, e, _, _, _) -> e) >$< E.param (E.nonNullable E.int4))
            <> ((\(_, _, _, _, _, f, _, _) -> f) >$< E.param (E.nullable E.text))
            <> ((\(_, _, _, _, _, _, g, _) -> g) >$< E.param (E.nonNullable E.float8))
            <> ((\(_, _, _, _, _, _, _, h) -> h) >$< E.param (E.nonNullable E.float8))
        )
        D.noResult

listTechLines :: Pool -> Int64 -> IO [TechLine]
listTechLines pool techId = do
  result <- use pool $ Session.statement techId stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      Statement
        "SELECT tech_card_id, line_no, goods_id, qty, sign, formula, line_time, line_cost \
        \FROM tech_line WHERE tech_card_id = $1 ORDER BY line_no"
        (E.param (E.nonNullable E.int8))
        (D.rowList techLineRow)
