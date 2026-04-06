module Main where

import Data.Aeson.Encode.Pretty  (encodePretty)
import Data.OpenApi              (OpenApi)
import Data.Proxy                (Proxy(..))
import Servant.OpenApi            (toOpenApi)
import Surypus.API.Root          (API)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Yaml            as Yaml

main :: IO ()
main = do
  let spec :: OpenApi
      spec = toOpenApi (Proxy :: Proxy (API '[JWT]))
        & info . title       .~ "Surypus ERP API"
        & info . version     .~ "1.0.0"
        & info . description ?~ "Offline-first ERP система"
  -- Генерация в YAML (для src/Surypus/API/Swagger.yaml)
  Yaml.encodeFile "src/Surypus/API/Swagger.yaml" spec
  -- Дополнительно — JSON для Swagger UI
  BL.writeFile "static/swagger.json" (encodePretty spec)
  putStrLn "✓ Swagger.yaml сгенерирован"