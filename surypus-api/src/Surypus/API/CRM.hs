{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveGeneric #-}

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
  , Contact(..), ContactInput(..)
  , listContacts, createContact, getContact, updateContact, deleteContact, searchContacts
  , Company(..), CompanyInput(..)
  , listCompanies, createCompany, getCompany, updateCompany, deleteCompany, searchCompanies
  , PipelineStage(..), StageRule(..), StageTransition(..)
  , listPipelineStages, getStageRules, refreshPipelineForecast, getStageHistory
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, genericToJSON, genericParseJSON, defaultOptions, fieldLabelModifier)
import GHC.Generics (Generic)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Statement
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Data.Functor.Contravariant ((>$<))
import Data.Functor.Contravariant.Divisible (divided)
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
        E.noParams
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
  res <- usePool pool $ Session.statement () stmt
  case res of
    Right deals -> return $ QuerySuccess deals
    Left err -> return $ QueryError (T.pack $ show err)

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
        (((\(DealInput n _ _ _ _ _ _) -> n) >$< E.param (E.nonNullable E.text))
         <> ((\(DealInput _ v _ _ _ _ _) -> v) >$< E.param (E.nonNullable E.float8))
         <> ((\(DealInput _ _ s _ _ _ _) -> s) >$< E.param (E.nonNullable E.text))
         <> ((\(DealInput _ _ _ p _ _ _) -> p) >$< E.param (E.nullable E.text))
         <> ((\(DealInput _ _ _ _ c _ _) -> c) >$< E.param (E.nullable E.text))
         <> ((\(DealInput _ _ _ _ _ d _) -> d) >$< E.param (E.nullable E.text))
         <> ((\(DealInput _ _ _ _ _ _ p) -> p) >$< E.param (E.nonNullable E.text)))
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
  res <- usePool pool $ Session.statement input stmt
  case res of
    Right deal -> return $ QuerySuccess deal
    Left err -> return $ QueryError (T.pack $ show err)

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
  res <- usePool pool $ Session.statement did stmt
  case res of
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
        (divided (E.param (E.nonNullable E.text)) (E.param (E.nonNullable E.text)))
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
  res <- usePool pool $ Session.statement (did, newStageId) stmt
  case res of
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
  res <- usePool pool $ Session.statement () stmt
  case res of
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
  res <- usePool pool $ Session.statement dealId stmt
  case res of
    Right activities -> return $ QuerySuccess activities
    Left err -> return $ QueryError (T.pack $ show err)

updateDeal :: Pool -> Text -> DealInput -> IO (QueryResult Deal)
updateDeal _ _ _ = return $ QueryError "Not implemented"

deleteDeal :: Pool -> Text -> IO (QueryResult ())
deleteDeal _ _ = return $ QueryError "Not implemented"

createActivity :: Pool -> ActivityInput -> IO (QueryResult Activity)
createActivity _ _ = return $ QueryError "Not implemented"

-- Contact types
data Contact = Contact
  { cId :: !Text, cName :: !Text, cEmail :: !(Maybe Text)
  } deriving (Show, Eq, Generic)
instance ToJSON Contact
instance FromJSON Contact

data ContactInput = ContactInput
  { ciName :: !Text, ciEmail :: !(Maybe Text)
  } deriving (Show, Eq, Generic)
instance ToJSON ContactInput
instance FromJSON ContactInput

listContacts :: Pool -> IO (QueryResult [Contact])
listContacts _ = return $ QuerySuccess []

createContact :: Pool -> ContactInput -> IO (QueryResult Contact)
createContact _ _ = return $ QueryError "Not implemented"

getContact :: Pool -> Text -> IO (QueryResult Contact)
getContact _ _ = return $ QueryError "Not implemented"

updateContact :: Pool -> Text -> ContactInput -> IO (QueryResult Contact)
updateContact _ _ _ = return $ QueryError "Not implemented"

deleteContact :: Pool -> Text -> IO (QueryResult ())
deleteContact _ _ = return $ QueryError "Not implemented"

searchContacts :: Pool -> Text -> IO (QueryResult [Contact])
searchContacts _ _ = return $ QuerySuccess []

-- Company types
data Company = Company
  { compId :: !Text, compName :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON Company
instance FromJSON Company

data CompanyInput = CompanyInput
  { compName :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON CompanyInput
instance FromJSON CompanyInput

listCompanies :: Pool -> IO (QueryResult [Company])
listCompanies _ = return $ QuerySuccess []

createCompany :: Pool -> CompanyInput -> IO (QueryResult Company)
createCompany _ _ = return $ QueryError "Not implemented"

getCompany :: Pool -> Text -> IO (QueryResult Company)
getCompany _ _ = return $ QueryError "Not implemented"

updateCompany :: Pool -> Text -> CompanyInput -> IO (QueryResult Company)
updateCompany _ _ _ = return $ QueryError "Not implemented"

deleteCompany :: Pool -> Text -> IO (QueryResult ())
deleteCompany _ _ = return $ QueryError "Not implemented"

searchCompanies :: Pool -> Text -> IO (QueryResult [Company])
searchCompanies _ _ = return $ QuerySuccess []

-- Pipeline types
data PipelineStage = PipelineStage
  { psId :: !Text, psName :: !Text, psProbability :: !Int
  } deriving (Show, Eq, Generic)
instance ToJSON PipelineStage
instance FromJSON PipelineStage

data StageRule = StageRule
  { srId :: !Text, srName :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON StageRule
instance FromJSON StageRule

data StageTransition = StageTransition
  { stId :: !Text, stFromStage :: !Text, stToStage :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON StageTransition
instance FromJSON StageTransition

listPipelineStages :: Pool -> IO (QueryResult [PipelineStage])
listPipelineStages _ = return $ QuerySuccess []

getStageRules :: Pool -> Text -> IO (QueryResult [StageRule])
getStageRules _ _ = return $ QuerySuccess []

refreshPipelineForecast :: Pool -> IO (QueryResult ())
refreshPipelineForecast _ = return $ QuerySuccess ()

getStageHistory :: Pool -> Text -> IO (QueryResult [StageTransition])
getStageHistory _ _ = return $ QuerySuccess []
