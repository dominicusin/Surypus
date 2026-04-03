{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.RBAC
  ( Role (..),
    Permission (..),
    RolePermission (..),
    hasPermission,
    checkPermission,
    defaultPermissions,
    adminRole,
    managerRole,
    userRole,
    viewerRole,
    roleFromText,
    textToRole,
    permissionToText,
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)

data Role
  = RoleAdmin
  | RoleManager
  | RoleUser
  | RoleViewer
  deriving (Show, Eq, Generic)

instance ToJSON Role

instance FromJSON Role

roleToText :: Role -> Text
roleToText RoleAdmin = "admin"
roleToText RoleManager = "manager"
roleToText RoleUser = "user"
roleToText RoleViewer = "viewer"

textToRole :: Text -> Maybe Role
textToRole "admin" = Just RoleAdmin
textToRole "manager" = Just RoleManager
textToRole "user" = Just RoleUser
textToRole "viewer" = Just RoleViewer
textToRole _ = Nothing

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
  | BillsWrite
  | OrdersWrite
  | TaxesWrite
  | CurrenciesWrite
  | SalariesWrite
  deriving (Show, Eq, Generic, Ord)

instance ToJSON Permission

instance FromJSON Permission

permissionToText :: Permission -> Text
permissionToText PersonRead = "person:read"
permissionToText PersonWrite = "person:write"
permissionToText PersonDelete = "person:delete"
permissionToText GoodsRead = "goods:read"
permissionToText GoodsWrite = "goods:write"
permissionToText GoodsDelete = "goods:delete"
permissionToText BillRead = "bill:read"
permissionToText BillWrite = "bill:write"
permissionToText BillDelete = "bill:delete"
permissionToText BillPost = "bill:post"
permissionToText PaymentRead = "payment:read"
permissionToText PaymentWrite = "payment:write"
permissionToText PaymentDelete = "payment:delete"
permissionToText LocationRead = "location:read"
permissionToText LocationWrite = "location:write"
permissionToText LocationDelete = "location:delete"
permissionToText StockRead = "stock:read"
permissionToText StockWrite = "stock:write"
permissionToText AccountingRead = "accounting:read"
permissionToText AccountingWrite = "accounting:write"
permissionToText PayrollRead = "payroll:read"
permissionToText PayrollWrite = "payroll:write"
permissionToText ReportsRead = "reports:read"
permissionToText ReportsWrite = "reports:write"
permissionToText UsersRead = "users:read"
permissionToText UsersWrite = "users:write"
permissionToText SettingsRead = "settings:read"
permissionToText SettingsWrite = "settings:write"
permissionToText AdminAccess = "admin:access"
permissionToText BillsWrite = "bills:write"
permissionToText OrdersWrite = "orders:write"
permissionToText TaxesWrite = "taxes:write"
permissionToText CurrenciesWrite = "currencies:write"
permissionToText SalariesWrite = "salaries:write"

data RolePermission = RolePermission
  { rpRole :: Role,
    rpPermissions :: [Permission]
  }
  deriving (Show, Eq)

adminRole =
  RolePermission
    RoleAdmin
    [ PersonRead,
      PersonWrite,
      PersonDelete,
      GoodsRead,
      GoodsWrite,
      GoodsDelete,
      BillRead,
      BillWrite,
      BillDelete,
      BillPost,
      PaymentRead,
      PaymentWrite,
      PaymentDelete,
      LocationRead,
      LocationWrite,
      LocationDelete,
      StockRead,
      StockWrite,
      AccountingRead,
      AccountingWrite,
      PayrollRead,
      PayrollWrite,
      ReportsRead,
      ReportsWrite,
      UsersRead,
      UsersWrite,
      SettingsRead,
      SettingsWrite,
      AdminAccess,
      BillsWrite,
      OrdersWrite,
      TaxesWrite,
      CurrenciesWrite,
      SalariesWrite
    ]

managerRole :: RolePermission
managerRole =
  RolePermission
    RoleManager
    [ PersonRead,
      PersonWrite,
      GoodsRead,
      GoodsWrite,
      BillRead,
      BillWrite,
      BillPost,
      PaymentRead,
      PaymentWrite,
      LocationRead,
      LocationWrite,
      StockRead,
      AccountingRead,
      PayrollRead,
      ReportsRead,
      BillsWrite,
      OrdersWrite,
      TaxesWrite,
      CurrenciesWrite
    ]

userRole :: RolePermission
userRole =
  RolePermission
    RoleUser
    [ PersonRead,
      GoodsRead,
      BillRead,
      PaymentRead,
      StockRead,
      AccountingRead,
      ReportsRead
    ]

viewerRole :: RolePermission
viewerRole =
  RolePermission
    RoleViewer
    [ PersonRead,
      GoodsRead,
      BillRead,
      ReportsRead
    ]

defaultPermissions :: [RolePermission]
defaultPermissions = [adminRole, managerRole, userRole, viewerRole]

getRolePermissions :: Role -> [Permission]
getRolePermissions role = case role of
  RoleAdmin -> rpPermissions adminRole
  RoleManager -> rpPermissions managerRole
  RoleUser -> rpPermissions userRole
  RoleViewer -> rpPermissions viewerRole

hasPermission :: Role -> Permission -> Bool
hasPermission role perm = perm `elem` getRolePermissions role

checkPermission :: Text -> Permission -> Either String ()
checkPermission roleText perm = case textToRole roleText of
  Nothing -> Left $ "Unknown role: " <> T.unpack roleText
  Just role ->
    if hasPermission role perm
      then Right ()
      else Left $ "Permission denied: " <> T.unpack (permissionToText perm)

roleFromText :: Text -> Role
roleFromText t = case textToRole t of
  Just r -> r
  Nothing -> RoleViewer
