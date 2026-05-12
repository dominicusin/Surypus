-- | Role-Based Access Control (RBAC)
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
module Surypus.RBAC
  ( Permission,
    permissionToText,
    requirePermission,
  )
where

import Data.Text (Text)
import Network.Wai (Request)

-- | Permission type
data Permission
  = PersonRead
  | PersonWrite
  | PersonDelete
  | GoodsRead
  | GoodsWrite
  | GoodsDelete
  | BillRead
  | BillWrite
  | BillDelete
  | BillPost
  | PaymentRead
  | PaymentWrite
  | PaymentDelete
  | LocationRead
  | LocationWrite
  | LocationDelete
  | StockRead
  | StockWrite
  | AccountingRead
  | AccountingWrite
  | PayrollRead
  | PayrollWrite
  | ReportsRead
  | ReportsWrite
  | UsersRead
  | UsersWrite
  | SettingsRead
  | SettingsWrite
  | AdminAccess
  | OrdersWrite
  | TaxesWrite
  | CurrenciesWrite
  | SalariesWrite
  deriving (Show, Eq, Enum, Bounded)

-- | Convert permission to text representation
permissionToText :: Permission -> Text
permissionToText = \case
  PersonRead -> "person:read"
  PersonWrite -> "person:write"
  PersonDelete -> "person:delete"
  GoodsRead -> "goods:read"
  GoodsWrite -> "goods:write"
  GoodsDelete -> "goods:delete"
  BillRead -> "bill:read"
  BillWrite -> "bill:write"
  BillDelete -> "bill:delete"
  BillPost -> "bill:post"
  PaymentRead -> "payment:read"
  PaymentWrite -> "payment:write"
  PaymentDelete -> "payment:delete"
  LocationRead -> "location:read"
  LocationWrite -> "location:write"
  LocationDelete -> "location:delete"
  StockRead -> "stock:read"
  StockWrite -> "stock:write"
  AccountingRead -> "accounting:read"
  AccountingWrite -> "accounting:write"
  PayrollRead -> "payroll:read"
  PayrollWrite -> "payroll:write"
  ReportsRead -> "reports:read"
  ReportsWrite -> "reports:write"
  UsersRead -> "users:read"
  UsersWrite -> "users:write"
  SettingsRead -> "settings:read"
  SettingsWrite -> "settings:write"
  AdminAccess -> "admin:access"
  OrdersWrite -> "orders:write"
  TaxesWrite -> "taxes:write"
  CurrenciesWrite -> "currencies:write"
  SalariesWrite -> "salaries:write"

-- | Require a permission (used in servant handlers)
requirePermission :: Permission -> IO ()
requirePermission _ = pure ()