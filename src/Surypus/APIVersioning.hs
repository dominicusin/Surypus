{-# LANGUAGE OverloadedStrings #-}

module Surypus.APIVersioning
  ( apiVersionMiddleware,
    checkAPIVersion,
    supportedAPIVersions,
    latestAPIVersion,
    APIVersionConfig (..),
    APIVersion (..),
    VersionStatus (..),
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Network.HTTP.Types as HTTP
import Network.Wai (Middleware)
import qualified Network.Wai as Wai

data APIVersion = APIVersion
  { apiVersion :: Text,
    apiReleaseDate :: Text,
    apiDeprecationDate :: Maybe Text,
    apiStatus :: VersionStatus
  }
  deriving (Show, Eq)

data VersionStatus
  = VersionCurrent
  | VersionDeprecated
  | VersionLegacy
  deriving (Show, Eq)

supportedAPIVersions :: [APIVersion]
supportedAPIVersions =
  [ APIVersion
      { apiVersion = "1.0",
        apiReleaseDate = "2024-01-01",
        apiDeprecationDate = Nothing,
        apiStatus = VersionLegacy
      },
    APIVersion
      { apiVersion = "1.1",
        apiReleaseDate = "2024-06-01",
        apiDeprecationDate = Just "2025-06-01",
        apiStatus = VersionDeprecated
      },
    APIVersion
      { apiVersion = "2.0",
        apiReleaseDate = "2025-01-01",
        apiDeprecationDate = Nothing,
        apiStatus = VersionCurrent
      }
  ]

latestAPIVersion :: APIVersion
latestAPIVersion =
  case ( [ v | v <- supportedAPIVersions, apiStatus v == VersionCurrent
         ]
       ) of
    x : _ -> x
    [] -> error _

data APIVersionConfig = APIVersionConfig
  { avcDefaultVersion :: Text,
    avcSupportedVersions :: [APIVersion],
    avcDeprecationWarningDays :: Int
  }

defaultAPIVersionConfig :: APIVersionConfig
defaultAPIVersionConfig =
  APIVersionConfig
    { avcDefaultVersion = "2.0",
      avcSupportedVersions = supportedAPIVersions,
      avcDeprecationWarningDays = 90
    }

parseAPIVersion :: Text -> Maybe Text
parseAPIVersion v
  | v `elem` ["1.0", "1.1", "2.0"] = Just v
  | otherwise = Nothing

checkAPIVersion :: Text -> Either Text APIVersion
checkAPIVersion v =
  case parseAPIVersion v of
    Nothing -> Left $ "Unsupported API version: " <> v
    Just ver ->
      case filter ((== ver) . apiVersion) supportedAPIVersions of
        [] -> Left $ "Unknown API version: " <> ver
        (version : _) -> Right version

addVersionHeaders :: APIVersion -> Wai.Response -> Wai.Response
addVersionHeaders version =
  let headers =
        [ ("X-API-Version", T.encodeUtf8 $ apiVersion version),
          ("X-API-Release-Date", T.encodeUtf8 $ apiReleaseDate version),
          ("X-API-Latest", T.encodeUtf8 $ apiVersion latestAPIVersion)
        ]
      status = apiStatus version
      headersWithDeprecation =
        case status of
          VersionDeprecated ->
            headers
              <> [ ("Deprecation", "true"),
                   ("Link", T.encodeUtf8 "<https://api.example.com/v2/docs>; rel=\"successor-version\"")
                 ]
          _ -> headers
   in Wai.mapResponseHeaders (headersWithDeprecation ++)

apiVersionMiddleware :: APIVersionConfig -> Middleware
apiVersionMiddleware cfg app req respond =
  let pathInfo = Wai.rawPathInfo req
      pathSegments = T.splitOn "/" (T.decodeUtf8 pathInfo)
      apiSegmentIndex = case pathSegments of
        ("api" : _) -> Just 2
        _ -> Nothing

      requestedVersion = case apiSegmentIndex of
        Just idx ->
          case drop (idx - 1) pathSegments of
            (v : _) -> parseAPIVersion v
            _ -> Nothing
        Nothing -> Nothing

      resolvedVersion = case requestedVersion of
        Just v ->
          case checkAPIVersion v of
            Right version -> version
            Left _ ->
              case checkAPIVersion (avcDefaultVersion cfg) of
                Right v' -> v'
                Left _ -> latestAPIVersion
        Nothing ->
          case checkAPIVersion (avcDefaultVersion cfg) of
            Right v' -> v'
            Left _ -> latestAPIVersion

      versionedReq =
        req {Wai.pathInfo = removeVersionFromPath pathSegments}
   in app versionedReq $ \response -> do
        let versionedResponse = addVersionHeaders resolvedVersion response
        respond versionedResponse
  where
    removeVersionFromPath segments =
      case segments of
        ("api" : v : rest)
          | v `elem` ["1.0", "1.1", "2.0"] -> "api" : rest
        _ -> segments

encodeUtf8 :: Text -> HTTP.HeaderValue
encodeUtf8 = T.encodeUtf8
