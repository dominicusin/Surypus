# Surypus Haskell Client

Haskell client library for Surypus Event Sourcing API.

## Installation

Add to your cabal file:

```cabal
build-depends:
    surypus-client >= 1.0.0
```

## Usage

```haskell
import SurypusClient

main :: IO ()
main = do
    -- Create client configuration
    cfg <- defaultClientConfig "http://localhost:3000/api/v1"
    let cfg' = withApiKey cfg "your-api-key"
           . withTenantId someTenantId
           $ cfg
    
    -- Use client
    withClient cfg' $ \client -> do
        -- Receive stock
        result <- receiveStock client ReceiveStockRequest
            { rsAggregateId = someAggregateId
            , rsGoodsId = someGoodsId
            , rsLocationId = someLocationId
            , rsQty = 100.0
            , rsCost = Money "USD" 1000
            , rsPrice = Nothing
            , rsLotNumber = Nothing
            , rsExpiryDate = Nothing
            , rsExpectedVersion = Nothing
            }
        
        print result
        
        -- Issue stock (FIFO)
        lots <- issueStock client IssueStockRequest
            { isAggregateId = someAggregateId
            , isGoodsId = someGoodsId
            , isLocationId = someLocationId
            , isQty = 50.0
            , isMethod = FIFO
            , isExpectedVersion = Nothing
            }
        
        print lots
```

## Features

- Type-safe API client
- Automatic retries with exponential backoff
- Connection pooling
- Async support (concurrent requests)
- Error handling with detailed messages

## API Coverage

- [x] Inventory Commands (receive, issue, adjust, reserve)
- [x] Inventory Queries (balance, FIFO lots)
- [x] Bill Commands (create, add line, post, cancel)
- [x] Bill Queries (get bill, list bills)
- [x] Saga Operations (start, get status, compensate)
- [x] Event Streaming (subscribe to events)

## Error Handling

```haskell
import Control.Exception (try)

result <- try $ receiveStock client req
case result of
    Left (SurypusAPIError code msg body) -> do
        putStrLn $ "API Error: " ++ show code ++ " - " ++ T.unpack msg
    Right response -> do
        print response
```
