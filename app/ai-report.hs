-- | AI-assisted business reporting CLI (v3.0 roadmap, issue #9)
-- Demonstrates LLM-assisted reporting by invoking Surypus.AI.
module Main (main) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Surypus.AI (getRecommendations, extractKeyInsights, AIConfig (..), AIProvider (..))

-- | Minimal config read from environment (API key stays server-side in real deployment).
loadConfig :: IO AIConfig
loadConfig = pure $ AIConfig
  { aiProvider = OpenAI
  , aiModel    = "gpt-4o-mini"
  , aiApiKey   = ""
  , aiEndpoint = "https://api.openai.com/v1"
  }

-- | Render a simple ASCII report from AI recommendations + insights.
renderReport :: Text -> [Text] -> [Text] -> Text
renderReport topic recs insights =
  T.unlines $
    [ "=== AI Business Report ==="
    , "Topic: " <> topic
    , ""
    , "Recommendations:"
    ] ++ map ("  - " <>) recs ++
    [ ""
    , "Key Insights:"
    ] ++ map ("  * " <>) insights

main :: IO ()
main = do
  cfg <- loadConfig
  _ <- pure cfg
  recs <- getRecommendations "quarterly business review"
  ins <- extractKeyInsights "Q3 financial summary"
  case (recs, ins) of
    (Right r, Right i) ->
      TIO.putStrLn $ renderReport "Quarterly Business Review" r i
    (Left e, _) -> TIO.putStrLn $ "AI reporting error: " <> e
    (_, Left e)  -> TIO.putStrLn $ "AI insights error: " <> e
