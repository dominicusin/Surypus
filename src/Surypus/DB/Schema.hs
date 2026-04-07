{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module Surypus.DB.Schema where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import Database.Persist.TH
import GHC.Generics (Generic)

share
  [ mkPersist sqlSettings,
    mkMigrate "migrateAll"
  ]
  [persistLowerCase|
    Person sql=persons
      name      Text        sqltype=varchar(255)
      phone     Text Maybe
      email     Text Maybe
      version   Int         default=1
      createdAt UTCTime     default=now()
      updatedAt UTCTime     default=now()
      UniquePersonEmail email !force
      deriving Show Eq Generic

    Good sql=goods
      barcode   Text        sqltype=varchar(64)
      name      Text        sqltype=varchar(512)
      unit      Text        sqltype=varchar(32)
      price     Rational
      stock     Rational    default=0
      version   Int         default=1
      updatedAt UTCTime     default=now()
      UniqueBarcode barcode
      deriving Show Eq Generic

    Bill sql=bills
      number    Text        sqltype=varchar(64)
      personId  PersonId
      total     Rational
      status    Text        sqltype=varchar(32)
      deviceId  Text
      version   Int         default=1
      createdAt UTCTime     default=now()
      UniqueBillNumber number
      deriving Show Eq Generic

    BillLine sql=bill_lines
      billId    BillId
      goodId    GoodId
      qty       Rational
      price     Rational
      deriving Show Eq Generic

    SyncLog sql=sync_log
      entityType  Text
      entityId    Int64
      action      Text
      deviceId    Text
      payload     Text
      conflict    Bool      default=False
      occurredAt  UTCTime   default=now()
      deriving Show Eq Generic

    IdPool sql=id_pools
      deviceId    Text
      entityType  Text
      rangeStart  Int64
      rangeEnd    Int64
      issuedAt    UTCTime   default=now()
      UniqueDevicePool deviceId entityType
      deriving Show Eq Generic
  |]
