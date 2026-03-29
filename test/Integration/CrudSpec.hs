module Integration.CrudSpec
  ( spec_crudPersons,
    spec_crudGoods,
    spec_crudLocations,
    spec_crudBills,
  )
where

import Test.Hspec

spec_crudPersons :: Spec
spec_crudPersons = describe "CRUD: Persons" $ do
  it "placeholder: person CRUD" $ do
    True `shouldBe` True

spec_crudGoods :: Spec
spec_crudGoods = describe "CRUD: Goods" $ do
  it "placeholder: goods CRUD" $ do
    True `shouldBe` True

spec_crudLocations :: Spec
spec_crudLocations = describe "CRUD: Locations" $ do
  it "placeholder: location CRUD" $ do
    True `shouldBe` True

spec_crudBills :: Spec
spec_crudBills = describe "CRUD: Bills" $ do
  it "placeholder: bill CRUD" $ do
    True `shouldBe` True
