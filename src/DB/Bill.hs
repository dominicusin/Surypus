{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.Bill
  ( listBills,
    getBill,
    createBill,
    postBill,
    recalcBillTotals,
    setEdiStatus,
  )
where

import Control.Monad (forM_, void)
import qualified DB.BillLine as DBBillLine
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Domain.Bill
import Domain.Types
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)

billRowDecoder :: D.Row Bill
billRowDecoder =
  Bill
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> pure Nothing
    <*> pure []

listBills :: Pool -> Pagination -> BillFilter -> IO [Bill]
listBills pool (Pagination limit offset) BillFilter {..} =
  use pool $
    Session.statement (limit, offset, bfPersonId, bfLocationId, bfStatus) stmt
  where
    stmt =
      unpreparable
        "SELECT id, number, op_kind_id, date, person_id, object_id, amount, vat_sum, discount, status, currency_id, created_by FROM bill WHERE ($3 IS NULL OR person_id = $3) AND ($4 IS NULL OR object_id = $4) AND ($5 IS NULL OR status = $5) ORDER BY date DESC LIMIT $1 OFFSET $2"
        ( E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nullable E.int4)
        )
        (D.rowList billRowDecoder)


getBill :: Pool -> Int64 -> IO (Maybe Bill)
getBill pool bid = do
  mb <- use pool $ Session.statement bid stmt
  case mb of
    Nothing -> pure Nothing
    Just bill -> do
      lines <- DBBillLine.listBillLines pool bid
      pure $ Just bill {billLines = lines}
  where
    stmt =
      unpreparable
        "SELECT id, number, op_kind_id, date, person_id, object_id, amount, vat_sum, discount, status, currency_id, created_by FROM bill WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe billRowDecoder)


createBill :: Pool -> Bill -> IO Int64
createBill pool bill@Bill {..} = do
  newId <-
    use pool $
      Session.statement
        ( billCode,
          billOpId,
          billDate,
          billPersonId,
          billLocationId,
          billAmount,
          billVat,
          billDiscount,
          billStatus,
          billCurrency,
          billCreatedBy
        )
        stmt
  forM_ billLines $ \line ->
    void $ DBBillLine.createBillLine pool newId line
  recalcBillTotals pool newId
  pure newId
  where
    stmt =
      unpreparable
        "INSERT INTO bill (number, op_kind_id, date, person_id, object_id, amount, vat_sum, discount, status, currency_id, created_by) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING id"
        ( E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.date)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nullable E.int8)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))


postBill :: Pool -> Int64 -> IO Bool
postBill pool bid =
  use pool $
    Session.statement bid stmt
  where
    stmt =
      unpreparable
        "SELECT post_bill($1)"
        (E.param (E.nonNullable E.int8))
        (D.singleRow $ D.column (D.nonNullable D.bool))


recalcBillTotals :: Pool -> Int64 -> IO ()
recalcBillTotals pool bid =
  use pool $
    Session.statement bid stmt Data.Functor.$> ()
  where
    stmt =
      unpreparable
        "SELECT recalc_bill_totals($1)"
        (E.param (E.nonNullable E.int8))
        D.noResult


setEdiStatus :: Pool -> Int64 -> Int -> Int -> IO Bool
setEdiStatus pool bid status conf =
  use pool $
    Session.statement (bid, status, conf) stmt
  where
    stmt =
      unpreparable
        "SELECT set_bill_edi_status($1,$2,$3)"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int4)
        )
        (D.singleRow $ D.column (D.nonNullable D.bool))

