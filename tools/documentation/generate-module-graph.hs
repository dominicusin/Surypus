#!/usr/bin/env runhaskell
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- | Generate a Mermaid module-dependency graph from Surypus Haskell sources.
--
-- Usage:
--   runhaskell tools/documentation/generate-module-graph.hs > docs/generated/graphs/modules.mmd
--
-- The graph is built by parsing @module X where ...@ declarations and their
-- import lines, so it is always in sync with the actual source.
module Main where

import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath ((</>), takeExtension, dropExtension, splitDirectories)
import System.IO (readFile)
import Data.List (sort, isPrefixOf, isSuffixOf)
import Data.Char (isSpace)
import qualified Data.Set as S
import Text.Regex.TDFA ((=~))

-- | Collect all .hs files under src/
listHsFiles :: FilePath -> IO [FilePath]
listHsFiles root = do
  exists <- doesDirectoryExist root
  if not exists
    then return []
    else go root
  where
    go dir = do
      xs <- listDirectory dir
      fpaths <- mapM (\x -> let p = dir </> x in do
                            isDir <- doesDirectoryExist p
                            if isDir then go p else return [p]) xs
      return (concat fpaths)

-- | Extract module name and imports from a file
parseFile :: FilePath -> IO (Maybe String, [String])
parseFile fp = do
  content <- readFile fp
  let mods = getAllMatches (content =~ ("^module\\s+([A-Z][A-Za-z0-9.]*)." :: String)) :: [String]
      modName = if null mods then Nothing else Just (mods !! 0)
      imports = map (dropWhile isSpace)
              . filter (("import" `isPrefixOf`) . dropWhile isSpace)
              . lines $ content
      importMods = map (\l -> l =~ ("^import\\s+([A-Z][A-Za-z0-9.<>.()]*)" :: String) :: [String]) imports
      modRefs = concat importMods
  return (modName, modRefs)

getAllMatches :: String -> String -> [String]
getAllMatches s pat = case s =~ pat of
  (_ : _ : ms) -> ms
  _            -> []

main :: IO ()
main = do
  files <- listHsFiles "src"
  results <- mapM parseFile files
  let entries = [(fp, m, imps) | (fp, m, imps) <- zip3 files (map fst results) (map snd results), isJust m]
      modGraph = [(dropExtension (takeFileName fp), mods) | (fp, Just m, imps) <- entries, let mods = map takeModuleMod imps]
      -- Build dot-style edges
      edges = [(takeModuleMod fp, m) | (fp, _, imps) <- entries, m <- imps, let _ = takeModuleMod fp]
  putStrLn "---"
  putStrLn "flowchart TD"
  putStrLn "    title \"Surypus Module Dependency Graph (generated from src/)\""
  putStrLn "    ---"
  -- Add subgraph clusters by top-level module
  let topLevel = S.fromList [take 1 (takeWhile (/='.') m) | (_, m) <- map fst entries ++ [(m,_) | (_,_,imps) <- results, m <- imps, not (null m)]]
  mapM_ (\t -> putStrLn $ "    subgraph \"" ++ t ++ "\"") topLevel
  putStrLn "    end"
  putStrLn "    ---"
  mapM_ (\(a,b) -> putStrLn $ "    " ++ sanitize a ++ " --> " ++ sanitize b) edges
  putStrLn ""
  where
    takeModuleMod s = case words s of
      (_:m:_) -> m
      _       -> ""
    sanitize = filter (\c -> c `elem` (['A'..'Z'] ++ ['a'..'z'] ++ ['0'..'9'] ++ '.'))
