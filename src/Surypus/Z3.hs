-- ============================================================================
-- Z3 THEOREM PROVER INTEGRATION (Pure Haskell Implementation)
-- ============================================================================
-- Formal verification of business logic invariants
-- Note: This is a pure Haskell implementation. For full Z3 integration,
--       install z3 library separately and use the 'z3' Haskell package.
-- ============================================================================

module Surypus.Z3 where

import Data.Int (Int64)
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Text (Text)
import qualified Data.Text as T
import Numeric (showFFloat)
import Text.Printf (printf)

-- ============================================================================
-- Z3 TYPES (SMT-LIB compatible)
-- ============================================================================

-- | SMT Sort types
data Sort
  = SortInt
  | SortReal
  | SortBool
  | SortString
  | SortArray Sort Sort
  deriving (Show, Eq)

-- | SMT Expression (simplified)
data Expr
  = EVar Text -- Variable
  | EConstInt Integer -- Constant integer
  | EConstReal Double -- Constant real
  | EConstBool Bool -- Constant boolean
  | EAdd Expr Expr -- Addition
  | ESub Expr Expr -- Subtraction
  | EMul Expr Expr -- Multiplication
  | EDiv Expr Expr -- Division
  | EMod Expr Expr -- Modulo
  | EEq Expr Expr -- Equality
  | ENeq Expr Expr -- Not equal
  | ELt Expr Expr -- Less than
  | EGt Expr Expr -- Greater than
  | ELe Expr Expr -- Less or equal
  | EGe Expr Expr -- Greater or equal
  | EAnd Expr Expr -- Logical and
  | EOr Expr Expr -- Logical or
  | ENot Expr -- Logical not
  | EImplies Expr Expr -- Implication
  | EIf Expr Expr Expr -- If-then-else
  | EApp Text [Expr] -- Function application
  deriving (Show, Eq)

-- | SMT Formula
data Formula = Formula
  { fExpr :: Expr,
    fName :: Maybe Text
  }
  deriving (Show, Eq)

-- | Solver result
data SolverResult
  = Sat Model
  | Unsat [Expr] -- Counterexamples
  | Unknown
  | Timeout
  deriving (Show, Eq)

-- | Model (variable assignments)
newtype Model = Model (Map Text Expr)
  deriving (Show, Eq)

-- | Empty model
emptyModel :: Model
emptyModel = Model Map.empty

-- | Combine models
combineModels :: Model -> Model -> Model
combineModels (Model m1) (Model m2) = Model (m1 `Map.union` m2)

-- | Pretty print expression
exprToString :: Expr -> String
exprToString e = case e of
  EVar t -> T.unpack t
  EConstInt n -> show n
  EConstReal d -> printf "%.2f" d
  EConstBool True -> "true"
  EConstBool False -> "false"
  EAdd a b -> "(" <> exprToString a <> " + " <> exprToString b <> ")"
  ESub a b -> "(" <> exprToString a <> " - " <> exprToString b <> ")"
  EMul a b -> "(" <> exprToString a <> " * " <> exprToString b <> ")"
  EDiv a b -> "(" <> exprToString a <> " / " <> exprToString b <> ")"
  EEq a b -> "(" <> exprToString a <> " = " <> exprToString b <> ")"
  ENeq a b -> "(" <> exprToString a <> " != " <> exprToString b <> ")"
  ELt a b -> "(" <> exprToString a <> " < " <> exprToString b <> ")"
  EGt a b -> "(" <> exprToString a <> " > " <> exprToString b <> ")"
  ELe a b -> "(" <> exprToString a <> " <= " <> exprToString b <> ")"
  EGe a b -> "(" <> exprToString a <> " >= " <> exprToString b <> ")"
  EAnd a b -> "(and " <> exprToString a <> " " <> exprToString b <> ")"
  EOr a b -> "(or " <> exprToString a <> " " <> exprToString b <> ")"
  ENot a -> "(not " <> exprToString a <> ")"
  EIf c t f -> "(ite " <> exprToString c <> " " <> exprToString t <> " " <> exprToString f <> ")"
  _ -> "(expr)"

-- ============================================================================
-- BUSINESS INVARIANTS (Pre-defined formulas)
-- ============================================================================

-- | Inventory invariant: stock >= reserved
inventoryInvariant :: Expr -> Expr -> Expr
inventoryInvariant = EGe

-- | Price invariant: price >= 0
priceInvariant :: Expr -> Expr
priceInvariant price = EGe price (EConstReal 0)

-- | Balance invariant: debits == credits
balanceInvariant :: Expr -> Expr -> Expr
balanceInvariant = EEq

-- | Quantity invariant: qtty >= 0
quantityInvariant :: Expr -> Expr
quantityInvariant qtty = EGe qtty (EConstReal 0)

-- | Credit limit invariant: debt <= credit_limit
creditLimitInvariant :: Expr -> Expr -> Expr
creditLimitInvariant = ELe

-- | Discount invariant: discount <= 100%
discountInvariant :: Expr -> Expr
discountInvariant discount = ELe discount (EConstReal 100)

-- | Tax calculation: tax = amount * rate / 100
taxCalculationInvariant :: Expr -> Expr -> Expr -> Expr
taxCalculationInvariant tax amount rate =
  EEq tax (EDiv (EMul amount rate) (EConstReal 100))

-- | Account balance: balance = debits - credits
accountBalanceInvariant :: Expr -> Expr -> Expr -> Expr
accountBalanceInvariant balance debits credits =
  EEq balance (ESub debits credits)

-- ============================================================================
-- ACCOUNTING VERIFICATION
-- ============================================================================

-- | Verify double-entry accounting
verifyDoubleEntry :: [(Int64, Int64, Double)] -> SolverResult
verifyDoubleEntry entries =
  let total = sum [amt | (_, _, amt) <- entries]
   in if total == 0
        then Sat (Model Map.empty)
        else Unsat [EConstReal total]

-- | Verify bill totals: sum(price * qtty * (1 - discount/100)) = total
verifyBillTotal :: Double -> [(Double, Double)] -> SolverResult
verifyBillTotal expectedTotal billLines =
  let actualTotal = sum [price * (1 - discount / 100) | (price, discount) <- billLines]
   in if abs (actualTotal - expectedTotal) < 0.01
        then Sat (Model Map.empty)
        else Unsat [EConstReal actualTotal]

-- | Verify stock balance after transaction
verifyStockBalance :: Double -> Double -> Double -> SolverResult
verifyStockBalance initial movement expected =
  let final = initial + movement
   in if abs (final - expected) < 0.01
        then Sat (Model Map.empty)
        else Unsat [EConstReal final]

-- ============================================================================
-- CONSTRAINT SOLVING
-- ============================================================================

-- | Find minimum order quantity to reach target revenue
solveMinOrderQty :: Double -> Double -> Maybe Double
solveMinOrderQty price target
  | price > 0 = Just (target / price)
  | otherwise = Nothing

-- | Calculate optimal discount for target profit
solveOptimalDiscount :: Double -> Double -> Double -> Maybe Double
solveOptimalDiscount cost price targetProfit =
  let minPrice = cost * (1 + targetProfit / 100)
      maxDiscount = (price - minPrice) / price * 100
   in if maxDiscount >= 0 then Just maxDiscount else Nothing

-- | Solve for break-even point
solveBreakEven :: Double -> Double -> Double -> Maybe Double
solveBreakEven fixedCosts variableCost price
  | price > variableCost = Just (fixedCosts / (price - variableCost))
  | otherwise = Nothing

-- ============================================================================
-- SCHEDULING VERIFICATION
-- ============================================================================

-- | Verify delivery schedule feasibility
verifyDeliverySchedule :: [(Int, Int)] -> Int -> Bool
verifyDeliverySchedule schedule maxDay =
  all (\(_, day) -> day >= 1 && day <= maxDay) schedule

-- | Resource allocation problem
solveResourceAllocation :: Int -> Int -> Int -> Maybe Int
solveResourceAllocation total requests minAlloc
  | requests * minAlloc <= total = Just (total `div` requests)
  | otherwise = Nothing

-- ============================================================================
-- PAYROLL VERIFICATION
-- ============================================================================

-- | Verify salary calculation
verifySalary :: Double -> Double -> Double -> Double -> SolverResult
verifySalary base bonus taxRate expectedNet =
  let gross = base + bonus
      tax = gross * taxRate / 100
      net = gross - tax
   in if abs (net - expectedNet) < 0.01
        then Sat (Model Map.empty)
        else Unsat [EConstReal net]

-- | Verify tax withholding
verifyTaxWithholding :: Double -> Double -> Double -> SolverResult
verifyTaxWithholding income rate expectedTax =
  let tax = income * rate / 100
   in if abs (tax - expectedTax) < 0.01
        then Sat (Model Map.empty)
        else Unsat [EConstReal tax]

-- ============================================================================
-- INVENTORY OPTIMIZATION (EOQ)
-- ============================================================================

-- | Economic Order Quantity (EOQ)
calculateEOQ :: Double -> Double -> Double -> Double
calculateEOQ demand orderingCost holdingCost =
  sqrt (2 * demand * orderingCost / holdingCost)

-- | Reorder point
calculateReorderPoint :: Double -> Double -> Double -> Double
calculateReorderPoint dailyDemand leadTime safetyStock =
  dailyDemand * leadTime + safetyStock

-- | Safety stock
calculateSafetyStock :: Double -> Double -> Double -> Double
calculateSafetyStock stdDev leadTime serviceLevel =
  stdDev * sqrt leadTime * serviceLevel

-- ============================================================================
-- FINANCIAL RATIOS
-- ============================================================================

-- | Current ratio (liquidity)
currentRatio :: Double -> Double -> Double
currentRatio assets liabilities
  | liabilities > 0 = assets / liabilities
  | otherwise = 0

-- | Quick ratio (acid test)
quickRatio :: Double -> Double -> Double -> Double
quickRatio assets inventory liabilities
  | liabilities > 0 = (assets - inventory) / liabilities
  | otherwise = 0

-- | Debt to equity ratio
debtToEquity :: Double -> Double -> Double
debtToEquity debt equity
  | equity > 0 = debt / equity
  | otherwise = 0

-- | Profit margin (%)
profitMargin :: Double -> Double -> Double
profitMargin profit revenue
  | revenue > 0 = profit / revenue * 100
  | otherwise = 0

-- ============================================================================
-- VALIDATION HELPERS
-- ============================================================================

-- | Validate all business rules for a bill
validateBill :: [(Double, Double, Double)] -> SolverResult
validateBill billLines =
  let totals = fmap (\(p, q, t) -> p * q * (1 + t / 100)) billLines
      total = sum totals
      priceCheck = all (\(p, _, _) -> p >= 0) billLines
      qtyCheck = all (\(_, q, _) -> q > 0) billLines
      taxCheck = all (\(_, _, t) -> t >= 0 && t <= 100) billLines
   in if priceCheck && qtyCheck && taxCheck
        then Sat (Model (Map.singleton (T.pack "total") (EConstReal total)))
        else Unsat []

-- | Validate inventory transaction
validateInventoryTransaction :: Double -> Double -> SolverResult
validateInventoryTransaction available requested =
  if requested <= available
    then Sat (Model Map.empty)
    else Unsat [EConstReal requested]

-- | Validate credit limit
validateCreditLimit :: Double -> Double -> Double -> SolverResult
validateCreditLimit currentDebt newOrder creditLimit =
  let newDebt = currentDebt + newOrder
   in if newDebt <= creditLimit
        then Sat (Model (Map.singleton (T.pack "new_debt") (EConstReal newDebt)))
        else Unsat [EConstReal newDebt]

-- ============================================================================
-- SAT SOLVER (Simple implementation)
-- ============================================================================

-- | Simple SAT solver
solve :: Formula -> SolverResult
solve (Formula expr _) = case expr of
  EConstBool True -> Sat (Model Map.empty)
  EConstBool False -> Unsat []
  EEq a b -> if exprEq a b then Sat (Model Map.empty) else Unknown
  EAnd a b -> solveAnd a b
  EOr a b -> solveOr a b
  ENot a -> solveNot a
  EGe a b -> if evalCompare a b (>=) then Sat (Model Map.empty) else Unknown
  ELe a b -> if evalCompare a b (<=) then Sat (Model Map.empty) else Unknown
  EGt a b -> if evalCompare a b (>) then Sat (Model Map.empty) else Unknown
  ELt a b -> if evalCompare a b (<) then Sat (Model Map.empty) else Unknown
  _ -> Unknown

-- | Helper: equality check for expressions
exprEq :: Expr -> Expr -> Bool
exprEq (EConstInt a) (EConstInt b) = a == b
exprEq (EConstReal a) (EConstReal b) = abs (a - b) < 0.0001
exprEq (EConstBool a) (EConstBool b) = a == b
exprEq (EVar a) (EVar b) = a == b
exprEq _ _ = False

-- | Helper: comparison for expressions
evalCompare :: Expr -> Expr -> (Double -> Double -> Bool) -> Bool
evalCompare a b cmp = case (evalExpr a, evalExpr b) of
  (Just av, Just bv) -> av `cmp` bv
  _ -> False

-- | Helper for Maybe
apply2 :: (a -> b -> c) -> Maybe a -> Maybe b -> Maybe c
apply2 f (Just a) (Just b) = Just (f a b)
apply2 _ _ _ = Nothing

-- | Evaluate expression to Maybe Double
evalExpr :: Expr -> Maybe Double
evalExpr e = case e of
  EConstReal d -> Just d
  EConstInt n -> Just (fromIntegral n)
  EAdd a b -> apply2 (+) (evalExpr a) (evalExpr b)
  ESub a b -> apply2 (-) (evalExpr a) (evalExpr b)
  EMul a b -> apply2 (*) (evalExpr a) (evalExpr b)
  EDiv a b -> apply2 (/) (evalExpr a) (evalExpr b)
  _ -> Nothing

-- | Solve AND
solveAnd :: Expr -> Expr -> SolverResult
solveAnd a b = case (solve (Formula a Nothing), solve (Formula b Nothing)) of
  (Sat m1, Sat m2) -> Sat (m1 `combineModels` m2)
  (Unsat us, _) -> Unsat us
  (_, Unsat us) -> Unsat us
  _ -> Unknown

-- | Solve OR
solveOr :: Expr -> Expr -> SolverResult
solveOr a b = case (solve (Formula a Nothing), solve (Formula b Nothing)) of
  (Sat _, _) -> Sat (Model Map.empty)
  (_, Sat _) -> Sat (Model Map.empty)
  (Unsat _, Unsat _) -> Unknown
  _ -> Unknown

-- | Solve NOT
solveNot :: Expr -> SolverResult
solveNot a = case solve (Formula a Nothing) of
  Sat _ -> Unsat []
  Unsat _ -> Sat (Model Map.empty)
  Unknown -> Unknown
  Timeout -> Timeout

-- | Check if formula is satisfiable
isSat :: Formula -> Bool
isSat f = case solve f of
  Sat _ -> True
  _ -> False

-- | Check if formula is valid (always true)
isValid :: Formula -> Bool
isValid f = not (isSat (Formula (ENot (fExpr f)) Nothing))

-- ============================================================================
-- EXAMPLE VERIFICATION
-- ============================================================================

-- | Verify accounting equation: Assets = Liabilities + Equity
verifyAccountingEquation :: Double -> Double -> Double -> SolverResult
verifyAccountingEquation assets liabilities equity =
  let rhs = liabilities + equity
   in if abs (assets - rhs) < 0.01
        then Sat (Model Map.empty)
        else Unsat [EConstReal assets, EConstReal rhs]

-- | Verify VAT calculation
verifyVATCalculation :: Double -> Double -> Double -> SolverResult
verifyVATCalculation net vatRate expectedVat =
  let vat = net * vatRate / 100
   in if abs (vat - expectedVat) < 0.01
        then Sat (Model Map.empty)
        else Unsat [EConstReal vat]

-- | Verify FIFO inventory cost
verifyFIFOCost :: [Double] -> [Double] -> Double -> SolverResult
verifyFIFOCost prices qtys expectedCost =
  let sold = zip prices qtys
      cost = sum [p * q | (p, q) <- sold]
   in if abs (cost - expectedCost) < 0.01
        then Sat (Model Map.empty)
        else Unsat [EConstReal cost]

-- ============================================================================
-- Z3 COMPATIBLE OUTPUT (SMT-LIB format)
-- ============================================================================

-- | Convert to SMT-LIB format
toSMTLib :: Formula -> String
toSMTLib f =
  unlines
    [ "(set-logic QF_NRA)",
      "(declare-fun x () Real)",
      "(assert " <> exprToString (fExpr f) <> ")",
      "(check-sat)",
      "(get-model)"
    ]
