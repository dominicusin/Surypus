
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Main where

import Surypus.Types.Common (Money(..))
import Surypus.Types.Bill (BillStatus(..))
import Surypus.Types.Person (PersonType(..))

main :: IO ()
main = do
  let m = Money 100
  print m
  print BillPaid
  print PersonTypeCustomer

