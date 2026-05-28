{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.Classifiers (
    -- * OKSM
    getOksmAll,
    getOksmById,
    getOksmByCode,

    -- * OKV
    getOkvAll,
    getOkvById,
    getOkvByCode,

    -- * OKEI
    getOkeiAll,
    getOkeiById,
    getOkeiByCode,

    -- * OKPD2
    getOkpd2All,
    getOkpd2ById,
    getOkpd2ByCode,
    getOkpd2ByParent,

    -- * OKVED2
    getOkved2All,
    getOkved2ById,
    getOkved2ByCode,
    getOkved2ByParent,

    -- * TNVED
    getTnvedAll,
    getTnvedById,
    getTnvedByCode,
    getTnvedByParent,

    -- * OKATO
    getOkatoAll,
    getOkatoById,
    getOkatoByCode,
    getOkatoByParent,

    -- * OKTMO
    getOktmoAll,
    getOktmoById,
    getOktmoByCode,
    getOktmoByParent,

    -- * OKOF
    getOkofAll,
    getOkofById,
    getOkofByCode,
    getOkofByParent,

    -- * OKP
    getOkpAll,
    getOkpById,
    getOkpByCode,
    getOkpByParent,

    -- * OKDP
    getOkdpAll,
    getOkdpById,
    getOkdpByCode,
    getOkdpByParent,

    -- * OKSO
    getOksoAll,
    getOksoById,
    getOksoByCode,

    -- * OKUN
    getOkunAll,
    getOkunById,
    getOkunByCode,
    getOkunByParent,

    -- * OKUD
    getOkudAll,
    getOkudById,
    getOkudByCode,

    -- * OKFS
    getOkfsAll,
    getOkfsById,
    getOkfsByCode,

    -- * OKNPO
    getOknpoAll,
    getOknpoById,
    getOknpoByCode,
) where

import Surypus.DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding as TE
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

preparable :: T.Text -> E.Params params -> D.Result result -> Statement params result
preparable sql encoder decoder = Statement (TE.encodeUtf8 sql) encoder decoder True

queryList :: Pool -> D.Row a -> Text -> IO (QueryResult [a])
queryList pool rowDecoder sql = do
    let stmt = preparable sql E.noParams (D.rowList rowDecoder)
    res <- use pool $ Session.statement () stmt
    pure $ case res of
        Right rows -> QuerySuccess rows
        Left err -> QueryError (T.pack $ show err)

queryById :: Pool -> D.Row a -> Text -> Int64 -> IO (QueryResult a)
queryById pool rowDecoder sql pid = do
    let stmt = preparable sql (E.param (E.nonNullable E.int8)) (D.rowMaybe rowDecoder)
    res <- use pool $ Session.statement pid stmt
    pure $ case res of
        Right (Just v) -> QuerySuccess v
        Right Nothing -> QueryError "Not Found"
        Left err -> QueryError (T.pack $ show err)

queryByCode :: Pool -> D.Row a -> Text -> Text -> IO (QueryResult a)
queryByCode pool rowDecoder sql code = do
    let stmt = preparable sql (E.param (E.nonNullable E.text)) (D.rowMaybe rowDecoder)
    res <- use pool $ Session.statement code stmt
    pure $ case res of
        Right (Just v) -> QuerySuccess v
        Right Nothing -> QueryError "Not Found"
        Left err -> QueryError (T.pack $ show err)

queryByParent :: Pool -> D.Row a -> Text -> Text -> IO (QueryResult [a])
queryByParent pool rowDecoder sql parentCode = do
    let stmt = preparable sql (E.param (E.nonNullable E.text)) (D.rowList rowDecoder)
    res <- use pool $ Session.statement parentCode stmt
    pure $ case res of
        Right rows -> QuerySuccess rows
        Left err -> QueryError (T.pack $ show err)

-- ── Row Decoders ────────────────────────────────────────────────────────────

oksmRow :: D.Row OksmRecord
oksmRow =
    OksmRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.text)

okvRow :: D.Row OkvRecord
okvRow =
    OkvRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)

okeiRow :: D.Row OkeiRecord
okeiRow =
    OkeiRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.text)

okpd2Row :: D.Row Okpd2Record
okpd2Row =
    Okpd2Record
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)

okved2Row :: D.Row Okved2Record
okved2Row =
    Okved2Record
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)

tnvedRow :: D.Row TnvedRecord
tnvedRow =
    TnvedRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.text)

okatoRow :: D.Row OkatoRecord
okatoRow =
    OkatoRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)
        <*> (fromIntegral <$> D.column (D.nonNullable D.int2))

oktmoRow :: D.Row OktmoRecord
oktmoRow =
    OktmoRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)

okofRow :: D.Row OkofRecord
okofRow =
    OkofRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)

okpRow :: D.Row OkpRecord
okpRow =
    OkpRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)

okdpRow :: D.Row OkdpRecord
okdpRow =
    OkdpRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)

oksoRow :: D.Row OksoRecord
oksoRow =
    OksoRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)

okunRow :: D.Row OkunRecord
okunRow =
    OkunRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)

okudRow :: D.Row OkudRecord
okudRow =
    OkudRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)

okfsRow :: D.Row OkfsRecord
okfsRow =
    OkfsRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)

oknpoRow :: D.Row OknpoRecord
oknpoRow =
    OknpoRecord
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)

-- ── Query functions ─────────────────────────────────────────────────────────

oksmCols :: Text
oksmCols = "id, code::text, name::text, full_name::text, alpha2::text, alpha3::text"

okvCols :: Text
okvCols = "id, code::text, letter_code::text, name::text, countries::text"

okeiCols :: Text
okeiCols = "id, code::text, name::text, national_symbol::text, international_symbol::text, national_letter_code::text, international_letter_code::text, section::text"

stdCols :: Text
stdCols = "id, code::text, name::text"

stdPCCols :: Text
stdPCCols = "id, code::text, name::text, parent_code::text"

tnvedCols :: Text
tnvedCols = "id, code::text, name::text, parent_code::text, section_num::text, group_num::text"

okatoCols :: Text
okatoCols = "id, code::text, name::text, parent_code::text, level"

-- OKSM
getOksmAll :: Pool -> IO (QueryResult [OksmRecord])
getOksmAll pool = queryList pool oksmRow $ "SELECT " <> oksmCols <> " FROM oksm ORDER BY code"

getOksmById :: Pool -> Int64 -> IO (QueryResult OksmRecord)
getOksmById pool = queryById pool oksmRow $ "SELECT " <> oksmCols <> " FROM oksm WHERE id = $1"

getOksmByCode :: Pool -> Text -> IO (QueryResult OksmRecord)
getOksmByCode pool = queryByCode pool oksmRow $ "SELECT " <> oksmCols <> " FROM oksm WHERE code = $1"

-- OKV
getOkvAll :: Pool -> IO (QueryResult [OkvRecord])
getOkvAll pool = queryList pool okvRow $ "SELECT " <> okvCols <> " FROM okv ORDER BY code"

getOkvById :: Pool -> Int64 -> IO (QueryResult OkvRecord)
getOkvById pool = queryById pool okvRow $ "SELECT " <> okvCols <> " FROM okv WHERE id = $1"

getOkvByCode :: Pool -> Text -> IO (QueryResult OkvRecord)
getOkvByCode pool = queryByCode pool okvRow $ "SELECT " <> okvCols <> " FROM okv WHERE code = $1"

-- OKEI
getOkeiAll :: Pool -> IO (QueryResult [OkeiRecord])
getOkeiAll pool = queryList pool okeiRow $ "SELECT " <> okeiCols <> " FROM okei ORDER BY code"

getOkeiById :: Pool -> Int64 -> IO (QueryResult OkeiRecord)
getOkeiById pool = queryById pool okeiRow $ "SELECT " <> okeiCols <> " FROM okei WHERE id = $1"

getOkeiByCode :: Pool -> Text -> IO (QueryResult OkeiRecord)
getOkeiByCode pool = queryByCode pool okeiRow $ "SELECT " <> okeiCols <> " FROM okei WHERE code = $1"

-- OKPD2
getOkpd2All :: Pool -> IO (QueryResult [Okpd2Record])
getOkpd2All pool = queryList pool okpd2Row $ "SELECT " <> stdPCCols <> " FROM okpd2 ORDER BY code"

getOkpd2ById :: Pool -> Int64 -> IO (QueryResult Okpd2Record)
getOkpd2ById pool = queryById pool okpd2Row $ "SELECT " <> stdPCCols <> " FROM okpd2 WHERE id = $1"

getOkpd2ByCode :: Pool -> Text -> IO (QueryResult Okpd2Record)
getOkpd2ByCode pool = queryByCode pool okpd2Row $ "SELECT " <> stdPCCols <> " FROM okpd2 WHERE code = $1"

getOkpd2ByParent :: Pool -> Text -> IO (QueryResult [Okpd2Record])
getOkpd2ByParent pool = queryByParent pool okpd2Row $ "SELECT " <> stdPCCols <> " FROM okpd2 WHERE parent_code = $1 ORDER BY code"

-- OKVED2
getOkved2All :: Pool -> IO (QueryResult [Okved2Record])
getOkved2All pool = queryList pool okved2Row $ "SELECT " <> stdPCCols <> " FROM okved2 ORDER BY code"

getOkved2ById :: Pool -> Int64 -> IO (QueryResult Okved2Record)
getOkved2ById pool = queryById pool okved2Row $ "SELECT " <> stdPCCols <> " FROM okved2 WHERE id = $1"

getOkved2ByCode :: Pool -> Text -> IO (QueryResult Okved2Record)
getOkved2ByCode pool = queryByCode pool okved2Row $ "SELECT " <> stdPCCols <> " FROM okved2 WHERE code = $1"

getOkved2ByParent :: Pool -> Text -> IO (QueryResult [Okved2Record])
getOkved2ByParent pool = queryByParent pool okved2Row $ "SELECT " <> stdPCCols <> " FROM okved2 WHERE parent_code = $1 ORDER BY code"

-- TNVED
getTnvedAll :: Pool -> IO (QueryResult [TnvedRecord])
getTnvedAll pool = queryList pool tnvedRow $ "SELECT " <> tnvedCols <> " FROM tnved ORDER BY code"

getTnvedById :: Pool -> Int64 -> IO (QueryResult TnvedRecord)
getTnvedById pool = queryById pool tnvedRow $ "SELECT " <> tnvedCols <> " FROM tnved WHERE id = $1"

getTnvedByCode :: Pool -> Text -> IO (QueryResult TnvedRecord)
getTnvedByCode pool = queryByCode pool tnvedRow $ "SELECT " <> tnvedCols <> " FROM tnved WHERE code = $1"

getTnvedByParent :: Pool -> Text -> IO (QueryResult [TnvedRecord])
getTnvedByParent pool = queryByParent pool tnvedRow $ "SELECT " <> tnvedCols <> " FROM tnved WHERE parent_code = $1 ORDER BY code"

-- OKATO
getOkatoAll :: Pool -> IO (QueryResult [OkatoRecord])
getOkatoAll pool = queryList pool okatoRow $ "SELECT " <> okatoCols <> " FROM okato ORDER BY code"

getOkatoById :: Pool -> Int64 -> IO (QueryResult OkatoRecord)
getOkatoById pool = queryById pool okatoRow $ "SELECT " <> okatoCols <> " FROM okato WHERE id = $1"

getOkatoByCode :: Pool -> Text -> IO (QueryResult OkatoRecord)
getOkatoByCode pool = queryByCode pool okatoRow $ "SELECT " <> okatoCols <> " FROM okato WHERE code = $1"

getOkatoByParent :: Pool -> Text -> IO (QueryResult [OkatoRecord])
getOkatoByParent pool = queryByParent pool okatoRow $ "SELECT " <> okatoCols <> " FROM okato WHERE parent_code = $1 ORDER BY code"

-- OKTMO
getOktmoAll :: Pool -> IO (QueryResult [OktmoRecord])
getOktmoAll pool = queryList pool oktmoRow $ "SELECT " <> stdPCCols <> " FROM oktmo ORDER BY code"

getOktmoById :: Pool -> Int64 -> IO (QueryResult OktmoRecord)
getOktmoById pool = queryById pool oktmoRow $ "SELECT " <> stdPCCols <> " FROM oktmo WHERE id = $1"

getOktmoByCode :: Pool -> Text -> IO (QueryResult OktmoRecord)
getOktmoByCode pool = queryByCode pool oktmoRow $ "SELECT " <> stdPCCols <> " FROM oktmo WHERE code = $1"

getOktmoByParent :: Pool -> Text -> IO (QueryResult [OktmoRecord])
getOktmoByParent pool = queryByParent pool oktmoRow $ "SELECT " <> stdPCCols <> " FROM oktmo WHERE parent_code = $1 ORDER BY code"

-- OKOF
getOkofAll :: Pool -> IO (QueryResult [OkofRecord])
getOkofAll pool = queryList pool okofRow $ "SELECT " <> stdPCCols <> " FROM okof ORDER BY code"

getOkofById :: Pool -> Int64 -> IO (QueryResult OkofRecord)
getOkofById pool = queryById pool okofRow $ "SELECT " <> stdPCCols <> " FROM okof WHERE id = $1"

getOkofByCode :: Pool -> Text -> IO (QueryResult OkofRecord)
getOkofByCode pool = queryByCode pool okofRow $ "SELECT " <> stdPCCols <> " FROM okof WHERE code = $1"

getOkofByParent :: Pool -> Text -> IO (QueryResult [OkofRecord])
getOkofByParent pool = queryByParent pool okofRow $ "SELECT " <> stdPCCols <> " FROM okof WHERE parent_code = $1 ORDER BY code"

-- OKP
getOkpAll :: Pool -> IO (QueryResult [OkpRecord])
getOkpAll pool = queryList pool okpRow $ "SELECT " <> stdPCCols <> " FROM okp ORDER BY code"

getOkpById :: Pool -> Int64 -> IO (QueryResult OkpRecord)
getOkpById pool = queryById pool okpRow $ "SELECT " <> stdPCCols <> " FROM okp WHERE id = $1"

getOkpByCode :: Pool -> Text -> IO (QueryResult OkpRecord)
getOkpByCode pool = queryByCode pool okpRow $ "SELECT " <> stdPCCols <> " FROM okp WHERE code = $1"

getOkpByParent :: Pool -> Text -> IO (QueryResult [OkpRecord])
getOkpByParent pool = queryByParent pool okpRow $ "SELECT " <> stdPCCols <> " FROM okp WHERE parent_code = $1 ORDER BY code"

-- OKDP
getOkdpAll :: Pool -> IO (QueryResult [OkdpRecord])
getOkdpAll pool = queryList pool okdpRow $ "SELECT " <> stdPCCols <> " FROM okdp ORDER BY code"

getOkdpById :: Pool -> Int64 -> IO (QueryResult OkdpRecord)
getOkdpById pool = queryById pool okdpRow $ "SELECT " <> stdPCCols <> " FROM okdp WHERE id = $1"

getOkdpByCode :: Pool -> Text -> IO (QueryResult OkdpRecord)
getOkdpByCode pool = queryByCode pool okdpRow $ "SELECT " <> stdPCCols <> " FROM okdp WHERE code = $1"

getOkdpByParent :: Pool -> Text -> IO (QueryResult [OkdpRecord])
getOkdpByParent pool = queryByParent pool okdpRow $ "SELECT " <> stdPCCols <> " FROM okdp WHERE parent_code = $1 ORDER BY code"

-- OKSO
getOksoAll :: Pool -> IO (QueryResult [OksoRecord])
getOksoAll pool = queryList pool oksoRow $ "SELECT " <> stdCols <> " FROM okso ORDER BY code"

getOksoById :: Pool -> Int64 -> IO (QueryResult OksoRecord)
getOksoById pool = queryById pool oksoRow $ "SELECT " <> stdCols <> " FROM okso WHERE id = $1"

getOksoByCode :: Pool -> Text -> IO (QueryResult OksoRecord)
getOksoByCode pool = queryByCode pool oksoRow $ "SELECT " <> stdCols <> " FROM okso WHERE code = $1"

-- OKUN
getOkunAll :: Pool -> IO (QueryResult [OkunRecord])
getOkunAll pool = queryList pool okunRow $ "SELECT " <> stdPCCols <> " FROM okun ORDER BY code"

getOkunById :: Pool -> Int64 -> IO (QueryResult OkunRecord)
getOkunById pool = queryById pool okunRow $ "SELECT " <> stdPCCols <> " FROM okun WHERE id = $1"

getOkunByCode :: Pool -> Text -> IO (QueryResult OkunRecord)
getOkunByCode pool = queryByCode pool okunRow $ "SELECT " <> stdPCCols <> " FROM okun WHERE code = $1"

getOkunByParent :: Pool -> Text -> IO (QueryResult [OkunRecord])
getOkunByParent pool = queryByParent pool okunRow $ "SELECT " <> stdPCCols <> " FROM okun WHERE parent_code = $1 ORDER BY code"

-- OKUD
getOkudAll :: Pool -> IO (QueryResult [OkudRecord])
getOkudAll pool = queryList pool okudRow $ "SELECT " <> stdCols <> " FROM okud ORDER BY code"

getOkudById :: Pool -> Int64 -> IO (QueryResult OkudRecord)
getOkudById pool = queryById pool okudRow $ "SELECT " <> stdCols <> " FROM okud WHERE id = $1"

getOkudByCode :: Pool -> Text -> IO (QueryResult OkudRecord)
getOkudByCode pool = queryByCode pool okudRow $ "SELECT " <> stdCols <> " FROM okud WHERE code = $1"

-- OKFS
getOkfsAll :: Pool -> IO (QueryResult [OkfsRecord])
getOkfsAll pool = queryList pool okfsRow $ "SELECT " <> stdCols <> " FROM okfs ORDER BY code"

getOkfsById :: Pool -> Int64 -> IO (QueryResult OkfsRecord)
getOkfsById pool = queryById pool okfsRow $ "SELECT " <> stdCols <> " FROM okfs WHERE id = $1"

getOkfsByCode :: Pool -> Text -> IO (QueryResult OkfsRecord)
getOkfsByCode pool = queryByCode pool okfsRow $ "SELECT " <> stdCols <> " FROM okfs WHERE code = $1"

-- OKNPO
getOknpoAll :: Pool -> IO (QueryResult [OknpoRecord])
getOknpoAll pool = queryList pool oknpoRow $ "SELECT " <> stdCols <> " FROM oknpo ORDER BY code"

getOknpoById :: Pool -> Int64 -> IO (QueryResult OknpoRecord)
getOknpoById pool = queryById pool oknpoRow $ "SELECT " <> stdCols <> " FROM oknpo WHERE id = $1"

getOknpoByCode :: Pool -> Text -> IO (QueryResult OknpoRecord)
getOknpoByCode pool = queryByCode pool oknpoRow $ "SELECT " <> stdCols <> " FROM oknpo WHERE code = $1"
