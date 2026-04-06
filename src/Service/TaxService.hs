{-# LANGUAGE OverloadedStrings #-}

-- | Tax calculation service using PostgreSQL stored procedures.
--
-- This module provides a high-level interface for tax calculations by delegating
-- computations to PostgreSQL functions. All operations return 'Either' types
-- for proper error handling.
--
-- Example usage:
--
-- @
-- service <- createTaxService pool
-- case calcVAT service price rate of
--   Right vat -> putStrLn $ "VAT: " ++ show vat
--   Left err  -> putStrLn $ "Error: " ++ show err
-- @
module Service.TaxService
  ( -- * Service type
    TaxService (..),
    createTaxService,

    -- * VAT calculations
    calcVAT,
    calcVATFromInclusive,
    calcPriceWithoutVAT,
    calcTaxInclusive,
    extractVAT,
  )
where

import DAL.Queries (preparable)
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Data.Scientific (Scientific)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Surypus.Types (Decimal (..))

newtype TaxService = TaxService
  { taxservicePool :: Pool
  }

createTaxService :: Pool -> TaxService
createTaxService = TaxService

-- | Calculate VAT amount using PostgreSQL procedure
calcVAT :: TaxService -> Decimal -> Decimal -> IO (Either Text Decimal)
calcVAT (TaxService pool) amount rate = do
  let toScientific :: Int64 -> Scientific
      toScientific = fromInteger . fromIntegral
      params = (toScientific (unDecimal amount), toScientific (unDecimal rate))
      stmt =
        preparable
          "SELECT calc_vat($1, $2)"
          ((fst >$< E.param (E.nonNullable E.numeric)) <> (snd >$< E.param (E.nonNullable E.numeric)))
          (D.singleRow (D.column (D.nullable D.numeric)))
  res <- use pool $ Session.statement params stmt
  case res of
    Right (Just numericValue) -> pure . Right $ Decimal (round numericValue)
    Right Nothing -> pure . Left $ "VAT calculation returned NULL"
    Left err -> pure . Left . T.pack $ show err

-- | Extract VAT from inclusive price using PostgreSQL procedure
calcVATFromInclusive :: TaxService -> Decimal -> Decimal -> IO (Either Text Decimal)
calcVATFromInclusive (TaxService pool) inclusive rate = do
  let toScientific :: Int64 -> Scientific
      toScientific = fromInteger . fromIntegral
      params = (toScientific (unDecimal inclusive), toScientific (unDecimal rate))
      stmt =
        preparable
          "SELECT calc_vat_inclusive($1, $2)"
          ((fst >$< E.param (E.nonNullable E.numeric)) <> (snd >$< E.param (E.nonNullable E.numeric)))
          (D.singleRow (D.column (D.nullable D.numeric)))
  res <- use pool $ Session.statement params stmt
  case res of
    Right (Just numericValue) -> pure . Right $ Decimal (round numericValue)
    Right Nothing -> pure . Left $ "VAT from inclusive calculation returned NULL"
    Left err -> pure . Left . T.pack $ show err

-- | Calculate price without VAT from inclusive price using PostgreSQL procedure
calcPriceWithoutVAT :: TaxService -> Decimal -> Decimal -> IO (Either Text Decimal)
calcPriceWithoutVAT (TaxService pool) inclusive rate = do
  let toScientific :: Int64 -> Scientific
      toScientific = fromInteger . fromIntegral
      params = (toScientific (unDecimal inclusive), toScientific (unDecimal rate))
      stmt =
        preparable
          "SELECT calc_price_without_vat($1, $2)"
          ((fst >$< E.param (E.nonNullable E.numeric)) <> (snd >$< E.param (E.nonNullable E.numeric)))
          (D.singleRow (D.column (D.nullable D.numeric)))
  res <- use pool $ Session.statement params stmt
  case res of
    Right (Just numericValue) -> pure . Right $ Decimal (round numericValue)
    Right Nothing -> pure . Left $ "Price without VAT calculation returned NULL"
    Left err -> pure . Left . T.pack $ show err

-- | Calculate price with VAT using PostgreSQL procedure
calcTaxInclusive :: TaxService -> Decimal -> Decimal -> IO (Either Text Decimal)
calcTaxInclusive (TaxService pool) price rate = do
  let toScientific :: Int64 -> Scientific
      toScientific = fromInteger . fromIntegral
      params = (toScientific (unDecimal price), toScientific (unDecimal rate))
      stmt =
        preparable
          "SELECT ($1) + calc_vat($1, $2)"
          ((fst >$< E.param (E.nonNullable E.numeric)) <> (snd >$< E.param (E.nonNullable E.numeric)))
          (D.singleRow (D.column (D.nullable D.numeric)))
  res <- use pool $ Session.statement params stmt
  case res of
    Right (Just numericValue) -> pure . Right $ Decimal (round numericValue)
    Right Nothing -> pure . Left $ "Price with VAT calculation returned NULL"
    Left err -> pure . Left . T.pack $ show err

-- | Extract VAT from inclusive price (alias for calcVATFromInclusive)
extractVAT :: TaxService -> Decimal -> Decimal -> IO (Either Text Decimal)
extractVAT = calcVATFromInclusive
