{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE Arrows #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.API.CRM
  ( Deal(..)
  , DealInput(..)
  , DealStage(..)
  , Activity(..)
  , ActivityInput(..)
  , PipelineForecast(..)
  , listDeals
  , createDeal
  , getDeal
  , updateDeal
  , deleteDeal
  , updateDealStage
  , getPipelineForecast
  , listActivities
  , createActivity
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, genericToJSON, genericParseJSON, defaultOptions, fieldLabelModifier)
import Data.Profunctor.Product.Default (Default)
import GHC.Generics (Generic)
import qualified Database.PostgreSQL.Simple as PGS
import qualified Opaleye as OE
import qualified Opaleye.Internal.HaskellDB.PrimQuery as OPQ
import qualified Opaleye.Internal.PGTypes as OPG
import qualified Opaleye.Internal.Tag as OITag
import Data.Functor.Contravariant ((>$<))
import DAL.Database (Pool, usePool, runQuery, runCommand)
import DAL.Types (QueryResult(..))

data DealStage = DealStage
  { dsId :: !Text
  , dsName :: !Text
  , dsOrder :: !Int
  , dsProbability :: !Double
  } deriving (Show, Eq, Generic)

instance ToJSON DealStage

data Deal = Deal
  { dealId :: !Text
  , dealName :: !Text
  , dealValue :: !Double
  , dealStage :: !Text
  , dealPerson :: !(Maybe Text)
  , dealCompany :: !(Maybe Text)
  , dealExpectedClose :: !(Maybe Text)
  , dealPriority :: !Text
  , dealProbability :: !Double
  , dealActive :: !Bool
  } deriving (Show, Eq, Generic)

instance ToJSON Deal

data DealInput = DealInput
  { diName :: !Text
  , diValue :: !Double
  , diStageId :: !Text
  , diPersonId :: !(Maybe Text)
  , diCompanyId :: !(Maybe Text)
  , diExpectedClose :: !(Maybe Text)
  , diPriority :: !Text
  } deriving (Show, Eq, Generic)

instance ToJSON DealInput
instance FromJSON DealInput

data Activity = Activity
  { actId :: !Text
  , actDealId :: !Text
  , actType :: !Text
  , actSubject :: !Text
  , actDescription :: !(Maybe Text)
  , actDate :: !Text
  , actCompleted :: !Bool
  } deriving (Show, Eq, Generic)

instance ToJSON Activity

data ActivityInput = ActivityInput
  { aiDealId :: !Text
  , aiType :: !Text
  , aiSubject :: !Text
  , aiDescription :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance ToJSON ActivityInput
instance FromJSON ActivityInput

data PipelineForecast = PipelineForecast
  { pfStage :: !Text
  , pfDealCount :: !Int64
  , pfPipelineValue :: !Double
  , pfWeightedForecast :: !Double
  } deriving (Show, Eq, Generic)

instance ToJSON PipelineForecast

listDeals :: Pool -> IO (QueryResult [Deal])
listDeals pool = do
   let query = OE.sql 
         "SELECT d.id, d.deal_name, d.deal_value, s.stage_name, \
         \  p.full_name, co.company_name, \
         \  d.expected_close_date::TEXT, d.priority, d.probability, d.is_active \
         \FROM crm_deals d \
         \LEFT JOIN crm_pipeline_stages s ON d.stage_id = s.id \
         \LEFT JOIN persons p ON d.person_id = p.id \
         \LEFT JOIN companies co ON d.company_id = co.id \
         \ORDER BY d.created_at DESC"
         (OE.makeColumns (,,,,,,,,,) 
            OE.text
            OE.text
            OE.double
            OE.text
            OE.text
            OE.text
            OE.text
            OE.text
            OE.double
            OE.bool
         ) OE.noParams
   result <- runQuery pool query
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map (\(dealId, dealName, dealValue, stageName, personFullName, companyName, expectedCloseDate, priority, probability, isActive) ->
        Deal dealId dealName dealValue stageName (Just personFullName) (Just companyName) (Just expectedCloseDate) priority probability isActive) cols

createDeal :: Pool -> DealInput -> IO (QueryResult Deal)
createDeal pool input = do
   let insert = OE.insert crmDealsTable
         OE.constNothing
         ( T.pack "00000000-0000-0000-0000-000000000000"  -- tenant_id
         , diName input                                 -- deal_name
         , diValue input                                -- deal_value
         , (read $ diStageId input :: UUID)             -- stage_id
         , (read <$> diPersonId input)                  -- person_id
         , (read <$> diCompanyId input)                 -- company_id
         , (read <$> diExpectedClose input)             -- expected_close_date
         , diPriority input                             -- priority
         , OE.constant (0 :: Double)                    -- probability (will be updated by trigger or app logic)
         )
   result <- runCommand pool insert
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right count -> if count > 0
                    then getDeal pool ""  -- TODO: Get the actual ID from the insert
                    else return $ QueryError "Failed to create deal"

getDeal :: Pool -> Text -> IO (QueryResult Deal)
getDeal pool did = do
  let stmt = Statement.Statement
        "SELECT d.id, d.deal_name, d.deal_value, s.stage_name, \
        \  p.full_name, co.company_name, \
        \  d.expected_close_date::TEXT, d.priority, d.probability, d.is_active \
        \FROM crm_deals d \
        \LEFT JOIN crm_pipeline_stages s ON d.stage_id = s.id \
        \LEFT JOIN persons p ON d.person_id = p.id \
        \LEFT JOIN companies co ON d.company_id = co.id \
        \WHERE d.id = $1::UUID"
        (E.param (E.nonNullable E.text))
        (D.singleRow $ Deal
          <$> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.bool))
        True
  result <- usePool pool $ Session.statement did stmt
  case result of
    Right deal -> return $ QuerySuccess deal
    Left err -> return $ QueryError (T.pack $ show err)

updateDealStage :: Pool -> Text -> Text -> IO (QueryResult Deal)
updateDealStage pool did newStageId = do
  let stmt = Statement.Statement
        "UPDATE crm_deals SET stage_id = $2::UUID, \
        \  probability = (SELECT stage_probability FROM crm_pipeline_stages WHERE id = $2::UUID), \
        \  updated_at = NOW() \
        \WHERE id = $1::UUID \
        \RETURNING id::TEXT, deal_name, deal_value, \
        \  (SELECT stage_name FROM crm_pipeline_stages WHERE id = $2::UUID), \
        \  NULL::TEXT, NULL::TEXT, expected_close_date::TEXT, priority, \
        \  (SELECT stage_probability FROM crm_pipeline_stages WHERE id = $2::UUID), is_active"
        (((\(did, _) -> did) >$< E.param (E.nonNullable E.text)) <>
         ((\(_, nid) -> nid) >$< E.param (E.nonNullable E.text)))
        (D.singleRow $ Deal
          <$> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.bool))
        True
  result <- usePool pool $ Session.statement (did, newStageId) stmt
  case result of
    Right deal -> return $ QuerySuccess deal
    Left err -> return $ QueryError (T.pack $ show err)

getPipelineForecast :: Pool -> IO (QueryResult [PipelineForecast])
getPipelineForecast pool = do
  let stmt = Statement.Statement
        "SELECT stage_name, deal_count, pipeline_value, weighted_forecast \
        \FROM mv_crm_pipeline_forecast ORDER BY stage_order"
        E.noParams
        (D.rowList $ PipelineForecast
          <$> D.column (D.nonNullable D.text)
          <*> (fromIntegral <$> D.column (D.nonNullable D.int8))
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.float8))
        True
  result <- usePool pool $ Session.statement () stmt
  case result of
    Right forecast -> return $ QuerySuccess forecast
    Left err -> return $ QueryError (T.pack $ show err)

listActivities :: Pool -> Text -> IO (QueryResult [Activity])
listActivities pool dealId = do
  let stmt = Statement.Statement
        "SELECT id::TEXT, deal_id::TEXT, activity_type, subject, \
        \  description, activity_date::TEXT, is_completed \
        \FROM crm_activities WHERE deal_id = $1::UUID ORDER BY activity_date DESC"
        (E.param (E.nonNullable E.text))
        (D.rowList $ Activity
          <$> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.bool))
        True
  result <- usePool pool $ Session.statement dealId stmt
  case result of
    Right activities -> return $ QuerySuccess activities
    Left err -> return $ QueryError (T.pack $ show err)

updateDeal :: Pool -> Text -> DealInput -> IO (QueryResult Deal)
updateDeal _ _ _ = return $ QueryError "Not implemented"

deleteDeal :: Pool -> Text -> IO (QueryResult ())
deleteDeal _ _ = return $ QueryError "Not implemented"

createActivity :: Pool -> ActivityInput -> IO (QueryResult Activity)
createActivity _ _ = return $ QueryError "Not implemented"
