module TestFixtures where

data Fixtures = Fixtures
  { fixturePersonId :: Int,
    fixtureGoodsId :: Int,
    fixtureLocationId :: Int,
    fixtureBillId :: Int,
    fixtureTaxId :: Int,
    fixtureCurrencyId :: Int,
    fixturePriceId :: Int,
    fixturePaymentId :: Int,
    fixtureOrderId :: Int,
    fixtureAccountId :: Int
  }
  deriving (Show, Eq)

placeholderFixtures :: Fixtures
placeholderFixtures =
  Fixtures
    { fixturePersonId = 1,
      fixtureGoodsId = 1,
      fixtureLocationId = 1,
      fixtureBillId = 1,
      fixtureTaxId = 1,
      fixtureCurrencyId = 1,
      fixturePriceId = 1,
      fixturePaymentId = 1,
      fixtureOrderId = 1,
      fixtureAccountId = 1
    }
