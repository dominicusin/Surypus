{-@ LIQUID "--reflection" @-}
{-@ LIQUID "--ple"        @-}

module Core.Accounting
  ( debit,
    credit,
    balance,
    LedgerEntry (..),
    Account (..),
    Transaction (..),
    validateTransaction,
    processTransaction,
  )
where
