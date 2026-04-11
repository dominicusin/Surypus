{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.BillLine
  ( listBillLines,
    createBillLine,
  )
where

import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Domain.Bill (BillLine (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

billLineRow :: D.Row BillLine
billLineRow =
  (BillLine . Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)

listBillLines :: Pool -> Int64 -> IO [BillLine]
listBillLines pool bid = do
  result <- use pool $ Session.statement bid stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      Statement
        "SELECT id, goods_id, price, quantity, discount, vat_rate, vat_amount, line_total FROM bill_line WHERE bill_id = $1 ORDER BY line_num"
        (E.param (E.nonNullable E.int8))
        (D.rowList billLineRow)

createBillLine :: Pool -> Int64 -> BillLine -> IO Int64
createBillLine pool bid BillLine {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    params =
      ( bid,
        billLineGoodsId,
        billLinePrice,
        billLineQuantity,
        billLineDiscount,
        billLineVatRate,
        billLineTax,
        billLineAmount
      )
    stmt =
      Statement
        "SELECT create_bill_line($1,$2,$3,$4,$5,$6,$7,$8)"
        ( ((\(a, _, _, _, _, _, _, _) -> a) >$< E.param (E.nonNullable E.int8))
            <> ((\(_, b, _, _, _, _, _, _) -> b) >$< E.param (E.nonNullable E.int8))
            <> ((\(_, _, c, _, _, _, _, _) -> c) >$< E.param (E.nonNullable E.float8))
            <> ((\(_, _, _, d, _, _, _, _) -> d) >$< E.param (E.nonNullable E.float8))
            <> ((\(_, _, _, _, e, _, _, _) -> e) >$< E.param (E.nonNullable E.float8))
            <> ((\(_, _, _, _, _, f, _, _) -> f) >$< E.param (E.nonNullable E.float8))
            <> ((\(_, _, _, _, _, _, g, _) -> g) >$< E.param (E.nonNullable E.float8))
            <> ((\(_, _, _, _, _, _, _, h) -> h) >$< E.param (E.nonNullable E.float8))
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))
