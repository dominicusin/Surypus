{-# LANGUAGE OverloadedStrings #-}

-- | Payment processing service.
--
-- Provides payment operations including creation, reconciliation with invoices,
-- status transitions, and refund processing. All monetary operations use
-- 'Either Text' for proper error handling.
--
-- Payment status machine:
--
-- @
-- pending → completed (payment received)
-- pending → failed (payment rejected)
-- completed → refunded (payment reversed)
-- @
--
-- Example usage:
--
-- @
-- service <- createPaymentService pool
-- case createPayment service billId amount PMCard of
--   Right payId -> putStrLn $ "Payment created: " ++ show payId
--   Left err    -> putStrLn $ "Error: " ++ show err
-- @
module Service.PaymentService
  ( -- * Service type
    PaymentService (..),
    createPaymentService,

    -- * Payment operations
    createPayment,
    completePayment,
    failPayment,
    refundPayment,
    getPaymentStatus,

    -- * Reconciliation
    reconcilePaymentWithBill,
    getTotalPaidForBill,
    getOutstandingBalance,
  )
where

import DAL.Queries (preparable)
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int16, Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Surypus.Core (PaymentMethod (..), PaymentStatus (..))

-- | Payment service with database connection pool
newtype PaymentService = PaymentService
  { paymentservicePool :: Pool
  }

-- | Create a new payment service
createPaymentService :: Pool -> PaymentService
createPaymentService = PaymentService

-- | Create a new payment in pending status
createPayment :: PaymentService -> Int64 -> Double -> PaymentMethod -> IO (Either Text Int64)
createPayment (PaymentService pool) billId amount method
  | amount <= 0 = pure . Left $ T.pack "Payment amount must be positive"
  | amount > 1e12 = pure . Left $ T.pack "Payment amount exceeds maximum"
  | otherwise = do
      res <- use pool $ Session.statement params stmt
      pure $ case res of
        Right (Just pid) -> Right pid
        Right Nothing -> Left $ T.pack "Failed to create payment"
        Left err -> Left . T.pack $ show err
  where
    params = (billId, amount, paymentMethodToInt method, toInt16 PSPending)
    stmt =
      preparable
        "INSERT INTO payment (bill_id, date, amount, payment_method, payment_status) VALUES ($1, CURRENT_DATE, $2, $3, $4) RETURNING id"
        ( ((\(a, _, _, _) -> a) >$< E.param (E.nonNullable E.int8))
            <> ((\(_, b, _, _) -> b) >$< E.param (E.nonNullable E.float8))
            <> ((\(_, _, c, _) -> c) >$< E.param (E.nonNullable E.int2))
            <> ((\(_, _, _, d) -> d) >$< E.param (E.nonNullable E.int2))
        )
        (D.rowMaybe (D.column (D.nonNullable D.int8)))

-- | Transition payment from pending to completed
completePayment :: PaymentService -> Int64 -> IO (Either Text ())
completePayment (PaymentService pool) paymentId = do
  res <- use pool $ Session.statement (toInt16 PSPending, toInt16 PSCompleted, paymentId) stmt
  pure $ case res of
    Right (Just True) -> Right ()
    Right (Just False) -> Left $ T.pack "Payment not in pending status"
    Right Nothing -> Left $ T.pack "Payment not found"
    Left err -> Left . T.pack $ show err
  where
    stmt =
      preparable
        "UPDATE payment SET payment_status = $2 WHERE id = $3 AND payment_status = $1 RETURNING TRUE"
        ( ((\(a, _, _) -> a) >$< E.param (E.nonNullable E.int2))
            <> ((\(_, b, _) -> b) >$< E.param (E.nonNullable E.int2))
            <> ((\(_, _, c) -> c) >$< E.param (E.nonNullable E.int8))
        )
        (D.rowMaybe (D.column (D.nonNullable D.bool)))

-- | Transition payment from pending to failed
failPayment :: PaymentService -> Int64 -> IO (Either Text ())
failPayment (PaymentService pool) paymentId = do
  res <- use pool $ Session.statement (toInt16 PSPending, toInt16 PSFailed, paymentId) stmt
  pure $ case res of
    Right (Just True) -> Right ()
    Right (Just False) -> Left $ T.pack "Payment not in pending status"
    Right Nothing -> Left $ T.pack "Payment not found"
    Left err -> Left . T.pack $ show err
  where
    stmt =
      preparable
        "UPDATE payment SET payment_status = $2 WHERE id = $3 AND payment_status = $1 RETURNING TRUE"
        ( ((\(a, _, _) -> a) >$< E.param (E.nonNullable E.int2))
            <> ((\(_, b, _) -> b) >$< E.param (E.nonNullable E.int2))
            <> ((\(_, _, c) -> c) >$< E.param (E.nonNullable E.int8))
        )
        (D.rowMaybe (D.column (D.nonNullable D.bool)))

-- | Refund a completed payment
refundPayment :: PaymentService -> Int64 -> IO (Either Text ())
refundPayment (PaymentService pool) paymentId = do
  res <- use pool $ Session.statement (toInt16 PSCompleted, toInt16 PSRefunded, paymentId) stmt
  pure $ case res of
    Right (Just True) -> Right ()
    Right (Just False) -> Left $ T.pack "Payment not in completed status"
    Right Nothing -> Left $ T.pack "Payment not found"
    Left err -> Left . T.pack $ show err
  where
    stmt =
      preparable
        "UPDATE payment SET payment_status = $2 WHERE id = $3 AND payment_status = $1 RETURNING TRUE"
        ( ((\(a, _, _) -> a) >$< E.param (E.nonNullable E.int2))
            <> ((\(_, b, _) -> b) >$< E.param (E.nonNullable E.int2))
            <> ((\(_, _, c) -> c) >$< E.param (E.nonNullable E.int8))
        )
        (D.rowMaybe (D.column (D.nonNullable D.bool)))

-- | Get current payment status
getPaymentStatus :: PaymentService -> Int64 -> IO (Either Text PaymentStatus)
getPaymentStatus (PaymentService pool) paymentId = do
  res <- use pool $ Session.statement paymentId stmt
  pure $ case res of
    Right (Just statusInt) ->
      case intToPaymentStatus statusInt of
        Just s -> Right s
        Nothing -> Left $ T.pack "Unknown payment status: " <> T.pack (show statusInt)
    Right Nothing -> Left $ T.pack "Payment not found"
    Left err -> Left . T.pack $ show err
  where
    stmt =
      preparable
        "SELECT payment_status FROM payment WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe (D.column (D.nonNullable D.int2)))

-- | Reconcile payment with bill: verify payment amount matches bill total
reconcilePaymentWithBill :: PaymentService -> Int64 -> IO (Either Text Bool)
reconcilePaymentWithBill (PaymentService pool) billId = do
  res <- use pool $ Session.statement billId stmt
  pure $ case res of
    Right (Just isReconciled) -> Right isReconciled
    Right Nothing -> Left $ T.pack "Bill not found"
    Left err -> Left . T.pack $ show err
  where
    stmt =
      preparable
        "SELECT COALESCE(SUM(p.amount), 0) >= b.total FROM bill b LEFT JOIN payment p ON p.bill_id = b.id AND p.payment_status = 2 WHERE b.id = $1 GROUP BY b.total, b.id"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe (D.column (D.nonNullable D.bool)))

-- | Get total paid amount for a bill (completed payments only)
getTotalPaidForBill :: PaymentService -> Int64 -> IO (Either Text Double)
getTotalPaidForBill (PaymentService pool) billId = do
  res <- use pool $ Session.statement billId stmt
  pure $ case res of
    Right (Just total) -> Right total
    Right Nothing -> Right 0.0
    Left err -> Left . T.pack $ show err
  where
    stmt =
      preparable
        "SELECT COALESCE(SUM(amount), 0) FROM payment WHERE bill_id = $1 AND payment_status = 2"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe (D.column (D.nonNullable D.float8)))

-- | Get outstanding balance for a bill (bill total - completed payments)
getOutstandingBalance :: PaymentService -> Int64 -> IO (Either Text Double)
getOutstandingBalance (PaymentService pool) billId = do
  res <- use pool $ Session.statement billId stmt
  pure $ case res of
    Right (Just balance) -> Right balance
    Right Nothing -> Left $ T.pack "Bill not found"
    Left err -> Left . T.pack $ show err
  where
    stmt =
      preparable
        "SELECT b.total - COALESCE((SELECT SUM(p.amount) FROM payment p WHERE p.bill_id = b.id AND p.payment_status = 2), 0) FROM bill b WHERE b.id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe (D.column (D.nonNullable D.float8)))

-- | Convert PaymentMethod to integer for DB storage
paymentMethodToInt :: PaymentMethod -> Int16
paymentMethodToInt PMCash = 1
paymentMethodToInt PMCard = 2
paymentMethodToInt PMTransfer = 3
paymentMethodToInt PMBonus = 4

-- | Convert integer to PaymentStatus
intToPaymentStatus :: Int16 -> Maybe PaymentStatus
intToPaymentStatus 1 = Just PSPending
intToPaymentStatus 2 = Just PSCompleted
intToPaymentStatus 3 = Just PSFailed
intToPaymentStatus 4 = Just PSRefunded
intToPaymentStatus _ = Nothing

-- | Convert PaymentStatus to integer for DB storage
toInt16 :: PaymentStatus -> Int16
toInt16 PSPending = 1
toInt16 PSCompleted = 2
toInt16 PSFailed = 3
toInt16 PSRefunded = 4
