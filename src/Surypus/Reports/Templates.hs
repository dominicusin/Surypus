{-# LANGUAGE DeriveGeneric #-}
-- ============================================================================
-- REPORT TEMPLATE LOADER
-- ============================================================================
{-# LANGUAGE OverloadedStrings #-}

module Surypus.Reports.Templates
  ( ReportTemplate (..),
    loadTemplate,
    loadTemplateFromFile,
    listTemplates,
    getTemplatePath,
    TemplateType (..),
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import System.FilePath ((</>))

-- ============================================================================
-- TEMPLATE TYPES
-- ============================================================================

data TemplateType
  = Invoice -- Счёт-фактура
  | Order -- Счёт на оплату
  | GoodsRequisition -- Товарная накладная (ТОРГ-12)
  | Act -- Акт выполненных работ
  | Payroll -- Расчётная ведомость
  | Inventory -- Остатки товаров
  | Balance -- Бухгалтерский баланс
  | CashIn -- Приходный кассовый ордер
  | CashOut -- Расходный кассовый ордер
  | Custom Text -- Пользовательский шаблон
  deriving (Show, Eq)

templateTypeToFile :: TemplateType -> Text
templateTypeToFile Invoice = "invoice.yaml"
templateTypeToFile Order = "order.yaml"
templateTypeToFile GoodsRequisition = "goods_requisition.yaml"
templateTypeToFile Act = "act.yaml"
templateTypeToFile Payroll = "payroll.yaml"
templateTypeToFile Inventory = "inventory.yaml"
templateTypeToFile Balance = "balance.yaml"
templateTypeToFile CashIn = "cash_in.yaml"
templateTypeToFile CashOut = "cash_out.yaml"
templateTypeToFile (Custom name) = name <> ".yaml"

templateTypeToName :: TemplateType -> Text
templateTypeToName Invoice = "Счёт-фактура"
templateTypeToName Order = "Счёт на оплату"
templateTypeToName GoodsRequisition = "Товарная накладная"
templateTypeToName Act = "Акт выполненных работ"
templateTypeToName Payroll = "Расчётная ведомость"
templateTypeToName Inventory = "Остатки товаров"
templateTypeToName Balance = "Бухгалтерский баланс"
templateTypeToName CashIn = "Приходный кассовый ордер"
templateTypeToName CashOut = "Расходный кассовый ордер"
templateTypeToName (Custom name) = name

-- ============================================================================
-- TEMPLATE INFO (removed unused functions)
-- ============================================================================

-- templateInfo tpl = (templateTypeToName tpl, templateTypeToFile tpl)

-- allTemplates =
--   [ Invoice,
--     Order,
--     GoodsRequisition,
--     Act,
--     Payroll,
--     Inventory,
--     Balance,
--     CashIn,
--     CashOut
--   ]
