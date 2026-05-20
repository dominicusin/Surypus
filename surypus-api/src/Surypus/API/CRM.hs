{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

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
import GHC.Generics (Generic)
import Control.Exception (try, SomeException)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Statement
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Data.Functor.Contravariant ((>$<))
import DAL.Database (Pool, usePool)
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
  let stmt = Statement.Statement
        "SELECT d.id, d.deal_name, d.deal_value, s.stage_name, \
        \  p.full_name, co.company_name, \
        \  d.expected_close_date::TEXT, d.priority, d.probability, d.is_active \
        \FROM crm_deals d \
        \LEFT JOIN crm_pipeline_stages s ON d.stage_id = s.id \
        \LEFT JOIN persons p ON d.person_id = p.id \
        \LEFT JOIN companies co ON d.company_id = co.id \
        \ORDER BY d.created_at DESC"
        ()
        (D.rowList $ Deal
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
  result <- try $ usePool pool $ Session.statement () stmt
  case result of
    Right deals -> return $ QuerySuccess deals
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)

createDeal :: Pool -> DealInput -> IO (QueryResult Deal)
createDeal pool input = do
  let stmt = Statement.Statement
        "INSERT INTO crm_deals (tenant_id, deal_name, deal_value, stage_id, \
        \  person_id, company_id, expected_close_date, priority, probability) \
        \VALUES ('00000000-0000-0000-0000-000000000000', $1, $2, $3::UUID, $4::UUID, $5::UUID, $6::DATE, $7, \
        \  (SELECT stage_probability FROM crm_pipeline_stages WHERE id = $3::UUID)) \
        \RETURNING id::TEXT, $1, $2, (SELECT stage_name FROM crm_pipeline_stages WHERE id = $3::UUID), \
        \  NULL::TEXT, NULL::TEXT, $6::TEXT, $7, \
        \  (SELECT stage_probability FROM crm_pipeline_stages WHERE id = $3::UUID), TRUE"
        ( E.param (E.nonNullable E.text) >$< (\(DealInput n _ _ _ _ _ p) -> n)
        <> E.param (E.nonNullable E.float8) >$< (\(DealInput _ v _ _ _ _ _) -> v)
        <> E.param (E.nonNullable E.text) >$< (\(DealInput _ _ s _ _ _ _) -> s)
        <> E.param (E.nullable E.text) >$< (\(DealInput _ _ _ p _ _ _) -> p)
        <> E.param (E.nullable E.text) >$< (\(DealInput _ _ _ _ c _ _) -> c)
        <> E.param (E.nullable E.text) >$< (\(DealInput _ _ _ _ _ d _) -> d)
        <> E.param (E.nonNullable E.text) >$< (\(DealInput _ _ _ _ _ _ p) -> p))
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
  result <- try $ usePool pool $ Session.statement input stmt
  case result of
    Right deal -> return $ QuerySuccess deal
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)

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
  result <- try $ usePool pool $ Session.statement did stmt
  case result of
    Right deal -> return $ QuerySuccess deal
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)

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
        (E.param (E.nonNullable E.text) <> E.param (E.nonNullable E.text))
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
  result <- try $ usePool pool $ Session.statement (did, newStageId) stmt
  case result of
    Right deal -> return $ QuerySuccess deal
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)

getPipelineForecast :: Pool -> IO (QueryResult [PipelineForecast])
getPipelineForecast pool = do
  let stmt = Statement.Statement
        "SELECT stage_name, deal_count, pipeline_value, weighted_forecast \
        \FROM mv_crm_pipeline_forecast ORDER BY stage_order"
        ()
        (D.rowList $ PipelineForecast
          <$> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.int8)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.float8))
        True
  result <- try $ usePool pool $ Session.statement () stmt
  case result of
    Right forecast -> return $ QuerySuccess forecast
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)

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
  result <- try $ usePool pool $ Session.statement dealId stmt
  case result of
    Right activities -> return $ QuerySuccess activities
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)

updateDeal :: Pool -> Text -> DealInput -> IO (QueryResult Deal)
updateDeal _ _ _ = return $ QueryError "Not implemented"

deleteDeal :: Pool -> Text -> IO (QueryResult ())
deleteDeal _ _ = return $ QueryError "Not implemented"

createActivity :: Pool -> ActivityInput -> IO (QueryResult Activity)
createActivity _ _ = return $ QueryError "Not implemented"
