module Main where

import Test.Hspec
import qualified DAL.TypesSpec
import qualified DAL.DBSpec

main :: IO ()
main = hspec $ do
  describe "DAL Layer Tests" $ do
    describe "DAL.Types" DAL.TypesSpec.spec
    describe "DAL.DB" DAL.DBSpec.spec
