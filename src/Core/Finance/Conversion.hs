{-# LANGUAGE OverloadedStrings #-}

module Core.Finance.Conversion
  ( convertAmount,
  )
where

import Core.Currency (Currency (..))

-- | Convert amount from one currency to another using base rates
convertAmount :: Currency -> Currency -> Double -> Double
convertAmount from to amount
  | curRate to == 0 = 0
  | otherwise = amount * curRate from / curRate to
