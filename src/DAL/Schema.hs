{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DataKinds #-}

module DAL.Schema where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime)
import Data.ByteString (ByteString)
import Database.Persist.TH

share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
PersonEntity sql=person
  code Text Maybe
  name Text
  inn Text Maybe
  kpp Text Maybe
  personType Int
  status Int Maybe
  deriving Show Eq

GoodsEntity sql=goods
  code Text Maybe
  name Text
  fullName Text Maybe
  barcode Text Maybe
  unitId Int64 Maybe
  categoryId Int64 Maybe
  goodsType Int Maybe
  goodsStatus Int Maybe
  minStock Double Maybe
  maxStock Double Maybe
  weight Double Maybe
  volume Double Maybe
  createdAt UTCTime Maybe
  updatedAt UTCTime Maybe
  deriving Show Eq

LocationEntity sql=location
  code Text Maybe
  name Text
  locationType Int
  deriving Show Eq

BillEntity sql=bill
  code Text Maybe
  billType Int
  docStatus Int
  docDate Day
  personId Int64 Maybe
  locationId Int64 Maybe
  total Double
  discountAmount Double
  taxAmount Double
  deriving Show Eq

BillLineEntity sql=bill_line
  billId Int64
  goodsId Int64
  qtty Double
  price Double
  discountAmount Double
  amount Double
  deriving Show Eq

StockEntity sql=stock
  goodsId Int64
  locationId Int64
  qtty Double
  resrvQtty Double
  deriving Show Eq

LotEntity sql=lot
  goodsId Int64
  locationId Int64
  billId Int64 Maybe
  dt Day
  expDt Day Maybe
  rest Double
  cost Double
  price Double
  serial Text Maybe
  flags Int
  deriving Show Eq

EmployeeEntity sql=employee
  code Text
  name Text
  tabNum Text Maybe
  hireDate Day Maybe
  status Int
  deriving Show Eq

SalaryEntity sql=salary
  employeeId Int64
  date Day
  gross Double
  net Double
  taxAmount Double
  pension Double
  other Double
  deriving Show Eq

ReportTemplateEntity sql=report_template
  code Text
  name Text
  reportType Int
  content Text
  format Text
  deriving Show Eq

OrderHeadEntity sql=order_head
  code Text Maybe
  name Text Maybe
  docDate Day
  personId Int64 Maybe
  locationId Int64 Maybe
  docType Int
  total Double
  discountAmount Double
  taxAmount Double
  deriving Show Eq

OrderLineEntity sql=order_line
  orderId Int64
  goodsId Int64
  qtty Double
  price Double
  amount Double
  deriving Show Eq

PaymentEntity sql=payment
  billId Int64
  date Day
  amount Double
  payMethod Int
  payStatus Int
  deriving Show Eq

UnitEntity sql=unit
  code Text
  name Text
  symbol Text Maybe
  deriving Show Eq

TaxEntity sql=tax
  code Text Maybe
  name Text
  rate Double
  deriving Show Eq

AccPlanEntity sql=acc_plan
  code Text
  name Text
  accType Int
  parentCode Text Maybe
  kind Int
  isAnalytical Bool
  deriving Show Eq

AccTurnEntity sql=acc_turn
  docId Int64 Maybe
  dbtAccId Int64
  crdAccId Int64
  amount Double
  date Day
  deriving Show Eq

CurrencyEntity sql=currency
  code Text Maybe
  symbol Text Maybe
  name Text Maybe
  rate Double
  isDefault Bool
  deriving Show Eq

GoodsPriceEntity sql=goods_price
  goodsId Int64
  priceType Int
  price Double
  minPrice Double
  startDate Day Maybe
  endDate Day Maybe
  deriving Show Eq

UserEntity sql=users
  username Text
  passwordHash Text
  email Text Maybe
  personId Int64 Maybe
  status Int
  tenantId Int64
  deriving Show Eq

TenantEntity sql=tenants
  name Text
  slug Text
  schemaName Text
  isActive Bool
  deriving Show Eq

DocumentTypeEntity sql=document_type
  code Text
  name Text
  description Text Maybe
  flag Int
  deriving Show Eq

RoleEntity sql=role
  name Text
  deriving Show Eq

PermissionEntity sql=permission
  name Text
  deriving Show Eq

UserRoleEntity sql=user_role
  userId Int64
  roleId Int64
  deriving Show Eq

RolePermissionEntity sql=role_permission
  roleId Int64
  permissionId Int64
  deriving Show Eq

OksmEntity sql=oksm
  code Text
  name Text
  fullName Text Maybe
  alpha2 Text Maybe
  alpha3 Text Maybe
  deriving Show Eq

OkvEntity sql=okv
  code Text
  letterCode Text Maybe
  name Text
  countries Text Maybe
  deriving Show Eq

OkeiEntity sql=okei
  code Text
  name Text
  nationalSymbol Text Maybe
  internationalSymbol Text Maybe
  nationalLetterCode Text Maybe
  internationalLetterCode Text Maybe
  section Text Maybe
  deriving Show Eq

Okpd2Entity sql=okpd2
  code Text
  name Text
  parentCode Text Maybe
  deriving Show Eq

Okved2Entity sql=okved2
  code Text
  name Text
  parentCode Text Maybe
  deriving Show Eq

TnvedEntity sql=tnved
  code Text
  name Text
  parentCode Text Maybe
  sectionNum Text Maybe
  groupNum Text Maybe
  deriving Show Eq

OkatoEntity sql=okato
  code Text
  name Text
  parentCode Text Maybe
  level Int
  deriving Show Eq

OktmoEntity sql=oktmo
  code Text
  name Text
  parentCode Text Maybe
  deriving Show Eq

OkofEntity sql=okof
  code Text
  name Text
  parentCode Text Maybe
  deriving Show Eq

OkpEntity sql=okp
  code Text
  name Text
  parentCode Text Maybe
  deriving Show Eq

OkdpEntity sql=okdp
  code Text
  name Text
  parentCode Text Maybe
  deriving Show Eq

OksoEntity sql=okso
  code Text
  name Text
  deriving Show Eq

OkunEntity sql=okun
  code Text
  name Text
  parentCode Text Maybe
  deriving Show Eq

OkudEntity sql=okud
  code Text
  name Text
  deriving Show Eq

OkfsEntity sql=okfs
  code Text
  name Text
  deriving Show Eq

OknpoEntity sql=oknpo
  code Text
  name Text
  deriving Show Eq

IntegrationEntity sql=integrations
  name Text
  configText Text
  status Text
  deriving Show Eq

WorkflowDefinitionEntity sql=workflow
  code Text
  name Text Maybe
  description Text
  enabled Bool
  definition Text
  deriving Show Eq

WorkflowInstanceEntity sql=workflow_instance
  workflowId Int64
  status Text
  currentStep Text Maybe
  inputData Text Maybe
  userId Int64 Maybe
  context Text Maybe
  startedAt UTCTime Maybe
  completedAt UTCTime Maybe
  deriving Show Eq

TechCardEntity sql=tech_card
  goodsId Int64
  name Text
  version Text
  status Int
  createdAt UTCTime
  updatedAt UTCTime
  note Text Maybe
  deriving Show Eq

WorkOrderEntity sql=work_order
  code Text
  goodsId Int64
  parentId Int64 Maybe
  plannedQtty Double
  factQtty Double
  status Int
  startDate Day Maybe
  endDate Day Maybe
  assignedTo Int64 Maybe
  note Text Maybe
  createdAt UTCTime
  updatedAt UTCTime
  closedAt Text Maybe
  deriving Show Eq

EventStoreEntity sql=event_store
  aggregateId Int64
  aggregateType Text
  eventType Text
  eventVersion Int
  eventSchemaVersion Int
  eventData Text
  eventMetadata Text Maybe
  sequenceNumber Int64
  occurredAt UTCTime
  createdAt UTCTime
  deriving Show Eq

EventSnapshotEntity sql=event_snapshot
  snapshotAggregateId Int64
  snapshotAggregateType Text
  snapshotVersion Int
  snapshotLastSeq Int64
  snapshotData Text
  snapshotCreatedAt UTCTime
  UniqueSnapshot snapshotAggregateId snapshotAggregateType snapshotVersion
  deriving Show Eq

AuditLogEntity sql=audit_log
  userId Int64
  action Text
  resourceType Text
  resourceId Int64
  oldValues Text Maybe
  newValues Text Maybe
  ipAddress Text
  createdAt UTCTime
  deriving Show Eq

PayrollResultEntity sql=payroll_results
  tenantId Int64
  period Day
  employeeId Int64
  gross Double
  deductions Double
  net Double
  incomeTax Double
  socialTax Double
  advance Double
  bonus Double
  vacationPay Double
  sickPay Double
  totalToPay Double
  currency Text
  version Int
  createdBy Int64 Maybe
  createdAt UTCTime
  updatedAt UTCTime
  deriving Show Eq

StockMovementEntity sql=stock_movement
  goodsId Int64
  locationFromId Int64 Maybe
  locationToId Int64 Maybe
  qtty Double
  movementType Int
  billId Int64 Maybe
  movementDate Day
  userId Int64 Maybe
  notes Text Maybe
  createdAt UTCTime Maybe
  deriving Show Eq
|]
