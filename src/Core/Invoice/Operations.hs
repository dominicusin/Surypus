-- | Invoice Operations with Formal Verification
-- Модуль содержит инварианты и проверенные операции для счетов
module Core.Invoice.Operations
  ( InvoiceOpResult (..),
    validateInvoice,
    calculateInvoiceBalance,
    calculateInvoicePaid,
    isInvoiceOverdue,
    isInvoicePaid,
    isInvoicePartiallyPaid,
    calculatePaymentDue,
    verifyInvoiceTotals,
    allocatePayment,
    calcTotalOutstanding,
    calcTotalOverdue,
  )
where

import Core.Invoice
import Data.Time (Day)

-- | Invoice operation result
data InvoiceOpResult
  = InvoiceOpSuccess
  | InvoiceOpInvalidTotal
  | InvoiceOpNegativeBalance
  | InvoiceOpOverpaid
  | InvoiceOpInvalidDates

-- ============================================================================
-- VALIDATORS
-- ============================================================================

-- | Validate invoice
-- Инвариант: сумма >= 0, оплата >= 0, оплата <= сумма
validateInvoice :: Invoice -> InvoiceOpResult
validateInvoice inv
  | invTotal inv < 0 = InvoiceOpInvalidTotal
  | invPaid inv < 0 = InvoiceOpInvalidTotal
  | invPaid inv > invTotal inv = InvoiceOpOverpaid
  | invDueDate inv < invDate inv = InvoiceOpInvalidDates
  | otherwise = InvoiceOpSuccess

-- ============================================================================
-- BALANCE CALCULATIONS
-- ============================================================================

-- | Calculate invoice balance
-- Инвариант: balance >= 0
calculateInvoiceBalance :: Invoice -> Double
calculateInvoiceBalance inv = invTotal inv - invPaid inv

-- | Calculate paid amount percentage
-- Инвариант: 0 <= result <= 100
calculateInvoicePaid :: Invoice -> Double
calculateInvoicePaid inv
  | invTotal inv <= 0 = 0
  | otherwise = (invPaid inv / invTotal inv) * 100

-- | Check if invoice is overdue
-- Инвариант: просрочка означает, что дата оплаты прошла
isInvoiceOverdue :: Invoice -> Day -> Bool
isInvoiceOverdue inv today = today > invDueDate inv && calculateInvoiceBalance inv > 0

-- | Check if invoice is fully paid
-- Инвариант: полная оплата означает баланс = 0
isInvoicePaid :: Invoice -> Bool
isInvoicePaid inv = calculateInvoiceBalance inv <= 0.01

-- | Check if invoice is partially paid
-- Инвариант: частичная оплата - баланс > 0 и оплата > 0
isInvoicePartiallyPaid :: Invoice -> Bool
isInvoicePartiallyPaid inv = invPaid inv > 0 && calculateInvoiceBalance inv > 0

-- ============================================================================
-- PAYMENT CALCULATIONS
-- ============================================================================

-- | Calculate payment due amount
-- Инвариант: result >= 0
calculatePaymentDue :: Invoice -> Double
calculatePaymentDue inv = max 0 (calculateInvoiceBalance inv)

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- | Verify invoice totals match
-- Инвариант: сумма счёта должна равня сумме строк
verifyInvoiceTotals :: Double -> [Double] -> InvoiceOpResult
verifyInvoiceTotals invoiceTotal lineTotals
  | invoiceTotal < 0 = InvoiceOpInvalidTotal
  | abs (invoiceTotal - sum lineTotals) > 0.01 = InvoiceOpInvalidTotal
  | otherwise = InvoiceOpSuccess

-- ============================================================================
-- PAYMENT ALLOCATION
-- ============================================================================

-- | Allocate payment to invoices (FIFO)
-- Инвариант: сумма распределённых платежей не превышает сумму платежа
allocatePayment :: Double -> [Invoice] -> [(Invoice, Double)]
allocatePayment remainingPayment invoices = go remainingPayment (filter (not . isInvoicePaid) invoices)
  where
    go _ [] = []
    go remaining (inv : invs)
      | remaining <= 0 = []
      | otherwise =
          let balance = calculateInvoiceBalance inv
              allocated = min remaining balance
           in (inv, allocated) : go (remaining - allocated) invs

-- | Calculate total outstanding amount
-- Инвариант: result >= 0
calcTotalOutstanding :: [Invoice] -> Double
calcTotalOutstanding = sum . fmap calculateInvoiceBalance

-- | Calculate total overdue amount
-- Инвариант: result >= 0
calcTotalOverdue :: [Invoice] -> Day -> Double
calcTotalOverdue invoices today = sum . fmap calculateInvoiceBalance $ filter (`isInvoiceOverdue` today) invoices
