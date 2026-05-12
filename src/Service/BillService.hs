-- | Bill Service - orchestrates bill operations including posting
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Service.BillService where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import qualified Data.Text as T
import DAL.DB
import DAL.EventStore (appendEvent, EventType(..), EventData(..), EventMetadata(..))
import Finance.Types (AccTurn (..))

-- | Bill-related types - using DB stub types for simplicity
type BillId = Int64
type GoodsId = Int64

-- | Bill line for posting
data BillLine = BillLine
  { blId :: Int64
  , blBillId :: BillId
  , blGoodsId :: GoodsId
  , blQty :: Double
  , blPrice :: Double
  , blDiscount :: Double
  , blAmount :: Double
  } deriving (Show, Eq)

-- | Post result
data PostResult
  = PostSuccess
      { postedBillId :: BillId
      , postedLines :: [BillLine]
      , createdAccTurns :: [AccTurn]
      , updatedStock :: [(GoodsId, Double)]
      }
  | PostFailed Text
  deriving (Show, Eq)

-- | Result type
type ServiceResult a = Either Text a

-- | Post a bill - creates accounting entries, updates stock, emits events
postBill :: Database -> BillId -> Day -> Double -> Double -> [BillLine] -> IO (ServiceResult PostResult)
postBill db bid bdate total discount billLines = do
  case validateBill total billLines of
    Left err -> pure (Left err)
    Right calculatedLines -> do
      -- Step 1: Insert bill to database
      let billStub = BillStub { DAL.DB.billId = bid, DAL.DB.billTotal = total }
      liftIO $ insertBill db billStub
      -- Step 2: Create accounting turn entries
      let accTurns = createAccountingEntries bid bdate total discount calculatedLines
      -- Step 3: Update stock levels
      let stockUpdates = updateStockLevels calculatedLines
      -- Step 4: Emit event
      emitEvent <- emitBillPostedEvent bid calculatedLines
      case emitEvent of
        Left err -> pure (Left err)
        Right _ -> pure (Right (PostSuccess
          { postedBillId = bid
          , postedLines = calculatedLines
          , createdAccTurns = accTurns
          , updatedStock = stockUpdates
          }))

-- | Validate bill
validateBill :: Double -> [BillLine] -> ServiceResult [BillLine]
validateBill total [] = Left "Bill must have at least one line"
validateBill total billLines =
  if total < 0
    then Left "Bill total cannot be negative"
    else Right (map calculateLineAmount billLines)

-- | Calculate line amount (qty * price - discount)
calculateLineAmount :: BillLine -> BillLine
calculateLineAmount line =
  line { blAmount = blQty line * blPrice line - blDiscount line }

-- | Create accounting turn entries
createAccountingEntries :: BillId -> Day -> Double -> Double -> [BillLine] -> [AccTurn]
createAccountingEntries bid bdate total discount billLines =
  let totalDebit = sum (map blAmount billLines)
      debitAmt = totalDebit - discount
      date = bdate
      -- Debit entry (account 10)
      entry1 = AccTurn
        { atId = 1
        , atAcctId = 10
        , atArId = 0
        , atDate = date
        , atAmount = debitAmt
        , atCurId = 1
        , atCurRate = 1.0
        , atFlags = 0
        , atBillId = bid
        , atCorrId = 0
        , atDbtAmt = debitAmt
        , atCrdAmt = 0
        }
      -- Credit entry (account 20)
      entry2 = AccTurn
        { atId = 2
        , atAcctId = 20
        , atArId = 0
        , atDate = date
        , atAmount = total
        , atCurId = 1
        , atCurRate = 1.0
        , atFlags = 0
        , atBillId = bid
        , atCorrId = 0
        , atDbtAmt = 0
        , atCrdAmt = total
        }
  in [entry1, entry2]

-- | Update stock levels for each goods
updateStockLevels :: [BillLine] -> [(GoodsId, Double)]
updateStockLevels billLines =
  map (\l -> (blGoodsId l, blQty l)) billLines

-- | Emit event for bill posted
emitBillPostedEvent :: BillId -> [BillLine] -> IO (ServiceResult ())
emitBillPostedEvent bid billLines = do
  let totalAmount = sum (map blAmount billLines)
      descText = T.pack ("Bill " ++ show bid ++ " posted")
      eventDataVal = EventData
        { edOldBalance = Nothing
        , edNewBalance = Just totalAmount
        , edChangeAmount = Just totalAmount
        , edAccountCode = Nothing
        , edAccountName = Just descText
        , edAccountType = Nothing
        , edCurrencyId = Nothing
        , edJournalEntryId = Just bid
        , edDebitAccountId = Nothing
        , edCreditAccountId = Nothing
        , edDescription = Just descText
        , edCustomData = Nothing
        }
      metadataVal = Just $ EventMetadata
        { emTrigger = Nothing
        , emUser = Nothing
        , emRequestId = Nothing
        , emCorrelationId = Nothing
        }
  result <- appendEvent bid JournalEntryPosted eventDataVal metadataVal
  pure (case result of
    Left err -> Left err
    Right _ -> Right ())

-- | Calculate total amount from lines
calcBillTotal :: [BillLine] -> Double
calcBillTotal = sum . map blAmount