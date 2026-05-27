{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Classifiers (
    -- * All classifiers
    listOksm,
    getOksm,
    getOksmByCode,
    listOkv,
    getOkv,
    listOkei,
    getOkei,
    listOkpd2,
    getOkpd2,
    listOkved2,
    getOkved2,
    listTnved,
    getTnved,
    listOkato,
    getOkato,
    listOktmo,
    getOktmo,
    listOkof,
    getOkof,
    listOkp,
    getOkp,
    listOkdp,
    getOkdp,
    listOkso,
    getOkso,
    listOkun,
    getOkun,
    listOkud,
    getOkud,
    listOkfs,
    getOkfs,
    listOknpo,
    getOknpo,
) where

import qualified DAL.Classifiers as C
import DAL.Database (Pool)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)

-- OKSM
listOksm :: Pool -> IO (QueryResult [OksmRecord])
listOksm = C.getOksmAll

getOksm :: Pool -> Int64 -> IO (QueryResult OksmRecord)
getOksm = C.getOksmById

getOksmByCode :: Pool -> Text -> IO (QueryResult OksmRecord)
getOksmByCode = C.getOksmByCode

-- OKV
listOkv :: Pool -> IO (QueryResult [OkvRecord])
listOkv = C.getOkvAll

getOkv :: Pool -> Int64 -> IO (QueryResult OkvRecord)
getOkv = C.getOkvById

-- OKEI
listOkei :: Pool -> IO (QueryResult [OkeiRecord])
listOkei = C.getOkeiAll

getOkei :: Pool -> Int64 -> IO (QueryResult OkeiRecord)
getOkei = C.getOkeiById

-- OKPD2
listOkpd2 :: Pool -> IO (QueryResult [Okpd2Record])
listOkpd2 = C.getOkpd2All

getOkpd2 :: Pool -> Int64 -> IO (QueryResult Okpd2Record)
getOkpd2 = C.getOkpd2ById

-- OKVED2
listOkved2 :: Pool -> IO (QueryResult [Okved2Record])
listOkved2 = C.getOkved2All

getOkved2 :: Pool -> Int64 -> IO (QueryResult Okved2Record)
getOkved2 = C.getOkved2ById

-- TNVED
listTnved :: Pool -> IO (QueryResult [TnvedRecord])
listTnved = C.getTnvedAll

getTnved :: Pool -> Int64 -> IO (QueryResult TnvedRecord)
getTnved = C.getTnvedById

-- OKATO
listOkato :: Pool -> IO (QueryResult [OkatoRecord])
listOkato = C.getOkatoAll

getOkato :: Pool -> Int64 -> IO (QueryResult OkatoRecord)
getOkato = C.getOkatoById

-- OKTMO
listOktmo :: Pool -> IO (QueryResult [OktmoRecord])
listOktmo = C.getOktmoAll

getOktmo :: Pool -> Int64 -> IO (QueryResult OktmoRecord)
getOktmo = C.getOktmoById

-- OKOF
listOkof :: Pool -> IO (QueryResult [OkofRecord])
listOkof = C.getOkofAll

getOkof :: Pool -> Int64 -> IO (QueryResult OkofRecord)
getOkof = C.getOkofById

-- OKP
listOkp :: Pool -> IO (QueryResult [OkpRecord])
listOkp = C.getOkpAll

getOkp :: Pool -> Int64 -> IO (QueryResult OkpRecord)
getOkp = C.getOkpById

-- OKDP
listOkdp :: Pool -> IO (QueryResult [OkdpRecord])
listOkdp = C.getOkdpAll

getOkdp :: Pool -> Int64 -> IO (QueryResult OkdpRecord)
getOkdp = C.getOkdpById

-- OKSO
listOkso :: Pool -> IO (QueryResult [OksoRecord])
listOkso = C.getOksoAll

getOkso :: Pool -> Int64 -> IO (QueryResult OksoRecord)
getOkso = C.getOksoById

-- OKUN
listOkun :: Pool -> IO (QueryResult [OkunRecord])
listOkun = C.getOkunAll

getOkun :: Pool -> Int64 -> IO (QueryResult OkunRecord)
getOkun = C.getOkunById

-- OKUD
listOkud :: Pool -> IO (QueryResult [OkudRecord])
listOkud = C.getOkudAll

getOkud :: Pool -> Int64 -> IO (QueryResult OkudRecord)
getOkud = C.getOkudById

-- OKFS
listOkfs :: Pool -> IO (QueryResult [OkfsRecord])
listOkfs = C.getOkfsAll

getOkfs :: Pool -> Int64 -> IO (QueryResult OkfsRecord)
getOkfs = C.getOkfsById

-- OKNPO
listOknpo :: Pool -> IO (QueryResult [OknpoRecord])
listOknpo = C.getOknpoAll

getOknpo :: Pool -> Int64 -> IO (QueryResult OknpoRecord)
getOknpo = C.getOknpoById
