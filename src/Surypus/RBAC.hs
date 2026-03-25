{-# LANGUAGE OverloadedStrings #-}

module Surypus.RBAC
  ( Permission (..),
    EntityType (..),
    Role (..),
    UserWithRole (..),
    defaultRoles,
    hasPermission,
    requirePermission,
    checkPermissions,
  )
where

import Control.Monad (unless)
import Control.Monad.Trans.Class (lift)
import DAL.Types
import Data.Aeson (object, (.=))
import Data.Text (Text)
import qualified Network.HTTP.Types as HTTP
import Web.Scotty

data RoleDefinition = RoleDefinition
  { rdName :: Text,
    rdPermissions :: [Permission]
  }

adminRole :: RoleDefinition
adminRole =
  RoleDefinition
    { rdName = "admin",
      rdPermissions = [PermAdmin]
    }

managerRole :: RoleDefinition
managerRole =
  RoleDefinition
    { rdName = "manager",
      rdPermissions =
        [ PermRead EntityPersons,
          PermWrite EntityPersons,
          PermRead EntityGoods,
          PermWrite EntityGoods,
          PermRead EntityBills,
          PermWrite EntityBills,
          PermRead EntityOrders,
          PermWrite EntityOrders,
          PermRead EntityPrices,
          PermWrite EntityPrices,
          PermRead EntityReports,
          PermExecute EntityReports,
          PermRead EntityAccounting
        ]
    }

cashierRole :: RoleDefinition
cashierRole =
  RoleDefinition
    { rdName = "cashier",
      rdPermissions =
        [ PermRead EntityGoods,
          PermRead EntityBills,
          PermWrite EntityBills,
          PermRead EntityOrders,
          PermWrite EntityOrders,
          PermRead EntityPrices
        ]
    }

accountantRole :: RoleDefinition
accountantRole =
  RoleDefinition
    { rdName = "accountant",
      rdPermissions =
        [ PermRead EntityPersons,
          PermRead EntityGoods,
          PermRead EntityBills,
          PermWrite EntityBills,
          PermRead EntityOrders,
          PermRead EntityAccounting,
          PermWrite EntityAccounting,
          PermRead EntityPayroll
        ]
    }

defaultRoles :: [RoleDefinition]
defaultRoles = [adminRole, managerRole, cashierRole, accountantRole]

hasPermission :: [Permission] -> Permission -> Bool
hasPermission perms perm = PermAdmin `elem` perms || perm `elem` perms

requirePermission :: [Permission] -> Permission -> Either Text ()
requirePermission perms perm
  | hasPermission perms perm = Right ()
  | otherwise = Left "Insufficient permissions"

checkPermissions :: [Permission] -> ActionM ()
checkPermissions required = do
  let userPerms = [PermAdmin]
      hasAnyPermission = any (\p -> hasPermission userPerms p) required
  unless hasAnyPermission $
    status HTTP.status403 >> json (object ["error" .= ("Forbidden" :: Text)]) >> finish
