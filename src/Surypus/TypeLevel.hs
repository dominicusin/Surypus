{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}

{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeFamilies #-}

-- | Type-level programming utilities for entities
module Surypus.TypeLevel
  ( -- * Type Families for Entity Operations
    type EntityId,
    type EntityFilter,
    type EntitySort,

    -- * Repository typeclass with type families
    RepositoryTF (..),

    -- * Document hierarchy with GADTs
    DocumentType (..),
    Document (..),
  )
where

import Core.Document.Types
import DAL.Types
import Data.Int (Int64)
import Data.Kind (Type)
import Data.Text (Text)
import Data.Time (Day)
import Data.Typeable (Typeable)
import Hasql.Pool (Pool)

-- | Type family for entity IDs
type family EntityId (entity :: *) :: Type

-- | Type family for entity filters
type family EntityFilter (entity :: *) :: Type

-- | Type family for entity sorting options
type family EntitySort (entity :: *) :: Type

-- Example instances for concrete entities
type instance EntityId Person = Int64

type instance EntityFilter Person = PersonFilter

type instance EntitySort Person = PersonSortBy

type instance EntityId Goods = Int64

type instance EntityFilter Goods = GoodsFilter

type instance EntitySort Goods = GoodsSortBy

type instance EntityId Bill = Int64

type instance EntityFilter Bill = BillFilter

type instance EntitySort Bill = BillSortBy

-- | Repository typeclass using type families for greater flexibility
class RepositoryTF m entity where
  -- | Find entity by ID
  findById :: Pool -> EntityId entity -> m (Maybe entity)

  -- | Find all entities with filtering and pagination
  findAll :: Pool -> Pagination -> EntityFilter entity -> m [entity]

  -- | Create a new entity
  create :: Pool -> entity -> m (EntityId entity)

  -- | Update an existing entity
  update :: Pool -> EntityId entity -> entity -> m (Maybe entity)

  -- | Delete an entity by ID
  delete :: Pool -> EntityId entity -> m (Maybe entity)

  -- | Find entities with sorting
  findAllSorted :: Pool -> Pagination -> EntityFilter entity -> EntitySort entity -> SortDir -> m [entity]

-- | GADT for document hierarchy
data DocumentType where
  DT_Bill :: DocumentType
  DT_Order :: DocumentType
  DT_Invoice :: DocumentType
  DT_Receipt :: DocumentType
  deriving (Show, Eq)

-- | GADT for documents with type-level documentation
data Document (docType :: DocumentType) where
  -- Bill document
  DocBill ::
    { docBillId :: Int64,
      docBillNumber :: Text,
      docBillDate :: Day,
      docBillTotal :: Surypus.Types.Decimal
    } ->
    Document 'DT_Bill
  -- Order document
  DocOrder ::
    { docOrderId :: Int64,
      docOrderNumber :: Text,
      docOrderDate :: Day,
      docOrderTotal :: Surypus.Types.Decimal
    } ->
    Document 'DT_Order
  -- Invoice document
  DocInvoice ::
    { docInvoiceId :: Int64,
      docInvoiceNumber :: Text,
      docInvoiceDate :: Day,
      docInvoiceTotal :: Surypus.Types.Decimal
    } ->
    Document 'DT_Invoice
  -- Receipt document
  DocReceipt ::
    { docReceiptId :: Int64,
      docReceiptNumber :: Text,
      docReceiptDate :: Day,
      docReceiptTotal :: Surypus.Types.Decimal
    } ->
    Document 'DT_Receipt

-- | Type-safe document operations
class DocumentOps (dt :: DocumentType) where
  getDocNumber :: Document dt -> Text
  getDocDate :: Document dt -> Day
  getDocTotal :: Document dt -> Surypus.Types.Decimal

instance DocumentOps 'DT_Bill where
  getDocNumber Document {..} = docBillNumber
  getDocDate Document {..} = docBillDate
  getDocTotal Document {..} = docBillTotal

instance DocumentOps 'DT_Order where
  getDocNumber Document {..} = docOrderNumber
  getDocDate Document {..} = docOrderDate
  getDocTotal Document {..} = docOrderTotal

instance DocumentOps 'DT_Invoice where
  getDocNumber Document {..} = docInvoiceNumber
  getDocDate Document {..} = docInvoiceDate
  getDocTotal Document {..} = docInvoiceTotal

instance DocumentOps 'DT_Receipt where
  getDocNumber Document {..} = docReceiptNumber
  getDocDate Document {..} = docReceiptDate
  getDocTotal Document {..} = docReceiptTotal
