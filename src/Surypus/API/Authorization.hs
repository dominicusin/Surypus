{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Authorization
  ( requiredPermissionForPathMethod,
    normalizeResourcePath,
  )
where

import Data.ByteString (ByteString)
import Data.Text (Text)
import qualified Data.Text as T
import Network.HTTP.Types.Method (methodDelete, methodGet, methodPost, methodPut)
import Surypus.RBAC (Permission (..))

requiredPermissionForPathMethod :: ByteString -> Text -> Maybe Permission
requiredPermissionForPathMethod method path
  | T.isPrefixOf "/api/v1/rbac" path = Just AdminAccess
  | T.isPrefixOf "/api/v1/users" path = Just UsersRead
  | T.isPrefixOf "/api/v1/persons" path = methodPermission PersonRead PersonWrite PersonDelete
  | T.isPrefixOf "/api/v1/goods" path = methodPermission GoodsRead GoodsWrite GoodsDelete
  | T.isPrefixOf "/api/v1/locations" path = methodPermission LocationRead LocationWrite LocationDelete
  | T.isPrefixOf "/api/v1/bills" path = billPermission
  | T.isPrefixOf "/api/v1/payments" path = methodPermission PaymentRead PaymentWrite PaymentDelete
  | T.isPrefixOf "/api/v1/orders" path = Just OrdersWrite
  | T.isPrefixOf "/api/v1/taxes" path = Just TaxesWrite
  | T.isPrefixOf "/api/v1/currencies" path = Just CurrenciesWrite
  | T.isPrefixOf "/api/v1/stock" path = Just StockRead
  | T.isPrefixOf "/api/v1/accounting" path = accountingPermission
  | T.isPrefixOf "/api/v1/payroll" path = Just PayrollRead
  | T.isPrefixOf "/api/v1/reports" path = Just ReportsRead
  | T.isPrefixOf "/api/v1/audit-log" path = Just AdminAccess
  | otherwise = Nothing
  where
    methodPermission readPerm writePerm deletePerm
      | method == methodGet = Just readPerm
      | method == methodPost = Just writePerm
      | method == methodPut = Just writePerm
      | method == methodDelete = Just deletePerm
      | otherwise = Nothing

    billPermission
      | method == methodGet = Just BillRead
      | method == methodPost = Just BillWrite
      | method == methodPut && T.isInfixOf "/status" path = Just BillPost
      | method == methodPut = Just BillWrite
      | method == methodDelete = Just BillDelete
      | otherwise = Nothing

    accountingPermission
      | method == methodGet = Just AccountingRead
      | method == methodPost = Just AccountingWrite
      | method == methodPut = Just AccountingWrite
      | method == methodDelete = Just AccountingWrite
      | otherwise = Nothing

normalizeResourcePath :: Text -> Text
normalizeResourcePath path =
  case resourceKeyFromSegments (pathSegments path) of
    Just resourceKey -> resourceKey
    Nothing -> dropTrailingSlash path
  where
    pathSegments = filter (not . T.null) . T.splitOn "/" . dropTrailingSlash

    resourceKeyFromSegments ["api", "v1", "persons"] = Just "person"
    resourceKeyFromSegments ["api", "v1", "persons", personId] = Just ("person:" <> personId)
    resourceKeyFromSegments ["api", "v1", "persons", "search", _query] = Just "person"
    resourceKeyFromSegments ["api", "v1", "goods"] = Just "goods"
    resourceKeyFromSegments ["api", "v1", "goods", goodsId] = Just ("goods:" <> goodsId)
    resourceKeyFromSegments ["api", "v1", "locations"] = Just "location"
    resourceKeyFromSegments ["api", "v1", "locations", locationId] = Just ("location:" <> locationId)
    resourceKeyFromSegments ["api", "v1", "bills"] = Just "bill"
    resourceKeyFromSegments ["api", "v1", "bills", billId] = Just ("bill:" <> billId)
    resourceKeyFromSegments ["api", "v1", "bills", billId, "status"] = Just ("bill:" <> billId)
    resourceKeyFromSegments ["api", "v1", "payments"] = Just "payment"
    resourceKeyFromSegments ["api", "v1", "payments", paymentId] = Just ("payment:" <> paymentId)
    resourceKeyFromSegments ["api", "v1", "orders"] = Just "order"
    resourceKeyFromSegments ["api", "v1", "orders", orderId] = Just ("order:" <> orderId)
    resourceKeyFromSegments ["api", "v1", "orders", orderId, "status"] = Just ("order:" <> orderId)
    resourceKeyFromSegments ["api", "v1", "taxes"] = Just "tax"
    resourceKeyFromSegments ["api", "v1", "taxes", taxId] = Just ("tax:" <> taxId)
    resourceKeyFromSegments ["api", "v1", "currencies"] = Just "currency"
    resourceKeyFromSegments ["api", "v1", "currencies", currencyId] = Just ("currency:" <> currencyId)
    resourceKeyFromSegments ["api", "v1", "stock"] = Just "stock"
    resourceKeyFromSegments ["api", "v1", "stock", "summary"] = Just "stock"
    resourceKeyFromSegments ["api", "v1", "stock", goodsId, locationId] = Just ("stock:" <> goodsId <> ":" <> locationId)
    resourceKeyFromSegments ["api", "v1", "stock", "goods", goodsId] = Just ("stock-goods:" <> goodsId)
    resourceKeyFromSegments ["api", "v1", "accounting", "accounts"] = Just "accounting-account"
    resourceKeyFromSegments ["api", "v1", "accounting", "accounts", accountId] = Just ("accounting-account:" <> accountId)
    resourceKeyFromSegments ["api", "v1", "accounting", "entries"] = Just "accounting-entry"
    resourceKeyFromSegments ["api", "v1", "accounting", "entries", entryId] = Just ("accounting-entry:" <> entryId)
    resourceKeyFromSegments ["api", "v1", "payroll"] = Just "payroll"
    resourceKeyFromSegments ["api", "v1", "payroll", "employees"] = Just "employee"
    resourceKeyFromSegments ["api", "v1", "payroll", "employees", employeeId] = Just ("employee:" <> employeeId)
    resourceKeyFromSegments ["api", "v1", "payroll", "salaries"] = Just "salary"
    resourceKeyFromSegments ["api", "v1", "payroll", "salaries", salaryId] = Just ("salary:" <> salaryId)
    resourceKeyFromSegments ["api", "v1", "reports"] = Just "report"
    resourceKeyFromSegments ["api", "v1", "reports", "metadata"] = Just "report"
    resourceKeyFromSegments ["api", "v1", "reports", "templates"] = Just "report"
    resourceKeyFromSegments ["api", "v1", "reports", reportId] = Just ("report:" <> reportId)
    resourceKeyFromSegments ["api", "v1", "reports", "jrxml", reportName] = Just ("report:" <> reportName)
    resourceKeyFromSegments ["api", "v1", "users"] = Just "user"
    resourceKeyFromSegments ["api", "v1", "audit-log"] = Just "audit-log"
    resourceKeyFromSegments ["api", "v1", "jobs"] = Just "job"
    resourceKeyFromSegments ["api", "v1", "jobs", "pending"] = Just "job"
    resourceKeyFromSegments ["api", "v1", "rbac", "roles"] = Just "rbac-role"
    resourceKeyFromSegments ["api", "v1", "rbac", "roles", roleName] = Just ("rbac-role:" <> roleName)
    resourceKeyFromSegments ["api", "v1", "rbac", "grants"] = Just "rbac-grant"
    resourceKeyFromSegments ["api", "v1", "rbac", "grants", "active"] = Just "rbac-grant"
    resourceKeyFromSegments ["api", "v1", "rbac", "grants", "cleanup"] = Just "rbac-grant"
    resourceKeyFromSegments ["api", "v1", "rbac", "audit"] = Just "rbac-audit"
    resourceKeyFromSegments ["api", "v1", "rbac", "audit", "cleanup"] = Just "rbac-audit"
    resourceKeyFromSegments _ = Nothing

    dropTrailingSlash p
      | p /= "/" && T.isSuffixOf "/" p = T.dropEnd 1 p
      | otherwise = p
