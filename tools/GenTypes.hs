module Main where

import qualified Data.Yaml as Yaml
import OpenAPI.CodeGenerator
import System.Environment (getArgs)

main :: IO ()
main = do
  args <- getArgs
  let yamlFile = case args of
        [f] -> f
        _   -> "src/Surypus/API/Swagger.yaml"
  spec <- Yaml.decodeFileThrow yamlFile
  let config = CodeGeneratorConfig
        { cgcModuleName = "Surypus.API.Generated"
        , cgcOutputDir  = "src"
        , cgcSpec       = spec
        }
  generateCode config
  putStrLn "✓ Типы сгенерированы из Swagger.yaml"