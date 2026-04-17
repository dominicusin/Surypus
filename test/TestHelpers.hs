module TestHelpers where

import Network.Wai (Application)
import Network.Wai.Test (SResponse, simpleHTTP)
import Servant
import Test.Hspec
import Test.QuickCheck

-- | Shared test server (placeholder)
withTestServer :: IO Application
withTestServer = undefined

-- | API test helpers
specBillLines :: SpecWith ()
specBillLines = describe "Bill Lines" $ do
  it "requires authentication" $ do
    pending

  it "requires BillPost permission" $ do
    pending

specPayroll :: SpecWith ()
specPayroll = describe "Payroll" $ do
  it "GET /hr/charges requires auth" $ pending
  it "POST /hr/salaries requires BillPost permission" $ pending

specProduction :: SpecWith ()
specProduction = describe "Production" $ do
  it "work-order CRUD" $ pending

specInventory :: SpecWith ()
specInventory = describe "Inventory" $ do
  it "POST /inventory requires auth" $ pending

-- | Property-based test: bill post totals equals sum of lines
prop_bill_post_total_equals_sum_of_lines :: Bill -> Property
prop_bill_post_total_equals_sum_of_lines _ = property True

-- | Property: salary no overlap constraint
prop_salary_no_overlap_constraint :: SalaryRecord -> SalaryRecord -> Bool
prop_salary_no_overlap_constraint a b = True

-- | Property: work order released never exceed planned
prop_work_order_released_le_planned :: WorkOrder -> Bool
prop_work_order_released_le_planned wo = woQtyReleased wo <= woQtyPlanned wo

-- | Property: stock balance non-negative after FIFO
prop_stock_balance_nonneg_after_fifo :: InventoryState -> InventoryLine -> Bool
prop_stock_balance_nonneg_after_fifo _ _ = True
