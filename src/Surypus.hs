{-# LANGUAGE DuplicateRecordFields #-}

-- ==========================================================================
-- Surypus - ERP system (Header and annotations)
-- ==========================================================================
module Surypus
  ( -- * Core Domain - explicit exports to avoid conflicts
    Surypus.Core.Person (..),
    Surypus.Core.Goods (..),
    Surypus.Core.Location (..),
    Surypus.Core.Bill (..),
    Surypus.Core.BillLine (..),
    Surypus.Core.Stock (..),
    Surypus.Core.Account (..),
    Surypus.Core.AccTurn (..),
    Surypus.Core.Payment (..),
    Surypus.Core.Currency (..),
    Surypus.Core.Tax (..),
    Surypus.Core.Unit (..),
    Surypus.Core.User (..),
    Surypus.Core.Order (..),
    Surypus.Core.Entity (..),
    Surypus.Core.Timestamped (..),
    Surypus.Core.Statusable (..),
    Surypus.Core.Activatable (..),
    Surypus.Core.EntityStatus (..),
    Surypus.Core.PersonKind (..),
    Surypus.Core.GoodsType (..),
    Surypus.Core.LocationType (..),
    Surypus.Core.BillType (..),
    Surypus.Core.BillStatus (..),
    Surypus.Core.AccountType (..),
    Surypus.Core.PaymentMethod (..),
    Surypus.Core.PaymentStatus (..),
    Surypus.Core.TaxType (..),
    Surypus.Core.OrderStatus (..),
    Surypus.Core.MovementType (..),
    Surypus.Core.calcBillLineAmount,
    Surypus.Core.calcBillTotal,
    Surypus.Core.calcStockAvailable,
    Surypus.Core.needsReorder,
    Surypus.Core.calcTax,
    Surypus.Core.calcDiscount,
    Surypus.Core.calcFinalPrice,
    Surypus.Core.validateINN,
    Surypus.Core.validateKPP,
    Surypus.Core.validateBarcode,
    Surypus.Core.validateEmail,
    Surypus.Core.validatePhone,

    -- * Access Control
    Surypus.RBAC.Permission (..),
    Surypus.RBAC.PermissionScope (..),
    Surypus.RBAC.ScopedPermission (..),
    Surypus.RBAC.DynamicRole (..),
    Surypus.RBAC.PermissionGrant (..),
    Surypus.RBAC.AuditEntry (..),
    Surypus.RBAC.hasPermission,
    Surypus.RBAC.checkPermission,
    Surypus.RBAC.defaultPermissions,
    Surypus.RBAC.adminRole,
    Surypus.RBAC.managerRole,
    Surypus.RBAC.Store.RBACStore (..),
    Surypus.RBAC.Store.newRBACStore,
    Surypus.RBAC.Store.listRoles,
    Surypus.RBAC.Store.upsertRole,
    Surypus.RBAC.Store.listGrants,
    Surypus.RBAC.Store.addGrant,
    Surypus.RBAC.Store.removeGrant,

    -- * Authentication
    module Surypus.JWT,

    -- * Types
    module Surypus.Types,
    Surypus.Error.AppError (..),
    Surypus.Validation.ValidationError,

    -- * API
    module Surypus.API.Server,
    module Surypus.API.Authorization,
    module Surypus.API.Health,

    -- * Reporting
    Surypus.Reports.ReportDef (..),
    Surypus.Reports.ReportCategory (..),
    Surypus.Reports.ParamDef (..),
    Surypus.Reports.ParamType (..),
    Surypus.Reports.FieldDef (..),
    Surypus.Reports.FieldType (..),
    Surypus.Reports.GroupDef (..),
    Surypus.Reports.allReports,
    Surypus.Reports.getReport,
    Surypus.Reports.getReportsByCategory,
    Surypus.Reports.generateJRXML,
    Surypus.Reports.exportReportToPDF,
    Surypus.Reports.exportReportToHTML,

    -- * Infrastructure
    module Surypus.Config,
    module Surypus.Event,
    module Surypus.I18n,
    module Surypus.Logging,
  )
where

import Surypus.API.Authorization
import Surypus.API.Health
import Surypus.API.Server
import Surypus.Config
import Surypus.Core
import Surypus.Error
import Surypus.Event
import Surypus.I18n
import Surypus.JWT
import Surypus.Logging
import Surypus.RBAC
import Surypus.RBAC.Store
import Surypus.Reports
import Surypus.Types
import Surypus.Validation
