#!/usr/bin/env runhaskell
-- Mini generator: scan sql/procedures.sql for function names and emit skeleton wrappers
import System.IO
import System.Environment
import Data.List
import Data.Char

camelCase :: String -> String
camelCase s = case parts of
  [] -> ""
  (h:rest) -> (map toLower h) ++ concatMap (	 -> case t of
                                                  (c:cs) -> toUpper c : map toLower cs
                                                  [] -> []) rest
  where parts = split '_' s

split :: Char -> String -> [String]
split delim s = case dropWhile (== delim) s of
  "" -> []
  s' -> w : split delim s''
    where (w, s'') = break (== delim) s'

generateForName :: String -> String
generateForName name =
  let f = camelCase name
  in unlines
     [ "get" ++ f ++ " :: Pool -> Maybe Double -> IO (QueryResult [" ++ name ++ "])"  -- naive
     , "get" ++ f ++ " _ _ = pure $ QueryError (T.pack \"Not implemented\")"
     , ""]

main :: IO ()
main = do
  args <- getArgs
  -- naive: just scan sql/procedures.sql for lines containing FUNCTION
  content <- readFile "sql/procedures.sql"
  let ls = lines content
      fns = map (trim . takeWhile (not . (== '('))) $ filter (\l -> isInfixOf "FUNCTION" l) ls
      unique = nub $ filter (not . null) fns
  putStrLn "-- Generated wrappers (skeletons) --"
  mapM_ (putStrLn . generateForName) unique

trim :: String -> String
trim = f where f = reverse . dropWhile isSpace . reverse . dropWhile isSpace
