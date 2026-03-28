{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.AccPlan
  ( AccPlanRepository (..),
    mkAccPlanRepository,
    listAccPlansRepo,
    createAccPlanRepo,
    updateAccPlanRepo,
    deleteAccPlanRepo,
  )
where

import Data.Int (Int64)
import Domain.Accounting (AccAccount (..))
import Hasql.Pool (Pool)

data AccPlanRepository = AccPlanRepository
  { accPlanPool :: Pool
  }

mkAccPlanRepository :: Pool -> AccPlanRepository
mkAccPlanRepository = AccPlanRepository

listAccPlansRepo :: AccPlanRepository -> IO [AccAccount]
listAccPlansRepo _ = pure []

createAccPlanRepo :: AccPlanRepository -> AccAccount -> IO Int64
createAccPlanRepo _ _ = pure 0

updateAccPlanRepo :: AccPlanRepository -> Int64 -> AccAccount -> IO Bool
updateAccPlanRepo _ _ _ = pure False

deleteAccPlanRepo :: AccPlanRepository -> Int64 -> IO Bool
deleteAccPlanRepo _ _ = pure False
