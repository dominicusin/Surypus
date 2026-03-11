{-# LANGUAGE OverloadedStrings #-}

module DB.BillLine
  ( listBillLines
  , createBillLine
  ) where

import Data.Int (Int64)
import Data.Scientific (Scientific, toRealFloat)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement (..))
import qualified Hasql.Encoders as E
import qualified Hasql.Decoders as D
import qualified Hasql.Session as Session
import Domain.Bill (BillLine(..))

billLineRow :: D.Row BillLine
billLineRow =
  BillLine
    <$> (Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.int8)
    <*> (toRealFloat <$> D.column (D.nonNullable D.numeric))
    <*> (toRealFloat <$> D.column (D.nonNullable D.numeric))
    <*> (toRealFloat <$> D.column (D.nonNullable D.numeric))
    <*> (toRealFloat <$> D.column (D.nonNullable D.numeric))
    <*> (toRealFloat <$> D.column (D.nonNullable D.numeric))
    <*> (toRealFloat <$> D.column (D.nonNullable D.numeric))

listBillLines :: Pool -> Int64 -> IO [BillLine]
listBillLines pool bid = use pool $
  Session.statement bid stmt
  where
    stmt = Statement
      "SELECT id, goods_id, price, quantity, discount, vat_rate, vat_amount, line_total FROM bill_line WHERE bill_id = $1 ORDER BY line_num"
      (E.param (E.nonNullable E.int8))
      (D.rowList billLineRow)
      False

createBillLine :: Pool -> Int64 -> BillLine -> IO Int64
createBillLine pool bid BillLine{..} = use pool $
  Session.statement
    ( bid
    , billLineGoodsId
    , billLineQuantity
    , billLinePrice
    , billLineDiscount
    , billLineVatRate
    , billLineTax
    , billLineAmount
    ) stmt
  where
    stmt = Statement
      "SELECT create_bill_line($1,$2,$3,$4,$5,$6,$7,$8)"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.numeric)
      <> E.param (E.nonNullable E.numeric)
      <> E.param (E.nonNullable E.numeric)
      <> E.param (E.nonNullable E.numeric)
      <> E.param (E.nonNullable E.numeric)
      <> E.param (E.nonNullable E.numeric)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False
