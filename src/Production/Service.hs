{-# LANGUAGE OverloadedStrings #-}

-- | Service command interpreter inspired by ppmain's SrvcCmd state machine.
module Production.Service
  ( ServiceCommand (..),
    ServiceState,
    ServicePhase (..),
    initialServiceState,
    parseServiceCommand,
    serviceCommandHelp,
    transition,
    serviceStatePhase
  ) where

import Data.Text (Text)
import qualified Data.Text as T

-- | Service phases representing the state machine of ppmain.
data ServicePhase
  = PhaseStopped
  | PhaseRunning
  | PhaseDaemon
  deriving (Eq, Show)

-- | Service state including locking flag.
data ServiceState = ServiceState
  { ssPhase :: ServicePhase,
    ssLocked :: Bool
  }
  deriving (Eq, Show)

{-@ measure serviceStatePhase @-}
serviceStatePhase :: ServiceState -> ServicePhase
serviceStatePhase (ServiceState ph _) = ph

{-@ type ServiceStateStopped = {v:ServiceState | serviceStatePhase v == PhaseStopped} @-}
{-@ type ServiceStateRunning = {v:ServiceState | serviceStatePhase v == PhaseRunning} @-}

-- | Initial state mirrors ppmain before a command executes.
initialServiceState :: ServiceState
initialServiceState =
  ServiceState
    { ssPhase = PhaseStopped,
      ssLocked = False
    }

-- | Commands that ppmain understands.
data ServiceCommand
  = CmdInstall (Maybe Text) (Maybe Text)
  | CmdUninstall
  | CmdStart
  | CmdStop
  | CmdRun
  | CmdClient
  | CmdDaemon
  | CmdRFID
  | CmdHelp
  deriving (Eq, Show)

serviceCommandDescriptions :: [(Text, Text)]
serviceCommandDescriptions =
  [ ("install", "Register service [login] [password]"),
    ("uninstall", "Unregister service"),
    ("start", "Start service"),
    ("stop", "Stop service"),
    ("run", "Run service in foreground"),
    ("client", "Run client utilities"),
    ("daemon", "Run daemonized background job"),
    ("rfidprcssr", "Execute RFID processor loop"),
    ("help", "Show this help text")
  ]

-- | Help text similar to ppmain OutHelp.
serviceCommandHelp :: Text
serviceCommandHelp =
  T.unlines $ "ppws <command>" : fmap (\(cmd, desc) -> "  " <> cmd <> "\t" <> desc) serviceCommandDescriptions

-- | Parse the args that mimic ppmain's command line.
parseServiceCommand :: [String] -> Maybe ServiceCommand
parseServiceCommand args = case fmap (T.toLower . T.pack) args of
  ("install" : login : pw : _) -> Just $ CmdInstall (Just login) (Just pw)
  ("install" : login : _) -> Just $ CmdInstall (Just login) Nothing
  ("install" : _) -> Just $ CmdInstall Nothing Nothing
  ("uninstall" : _) -> Just CmdUninstall
  ("start" : _) -> Just CmdStart
  ("stop" : _) -> Just CmdStop
  ("run" : _) -> Just CmdRun
  ("client" : _) -> Just CmdClient
  ("daemon" : _) -> Just CmdDaemon
  ("rfidprcssr" : _) -> Just CmdRFID
  ("help" : _) -> Just CmdHelp
  _ -> Nothing

-- | Start service only if phase is stopped.

{-@ startService :: ServiceStateStopped -> ServiceStateRunning @-}
startService :: ServiceState -> ServiceState
startService st = st {ssPhase = PhaseRunning}

-- | Stop service only if it was running or daemonized.

{-@ stopService :: ServiceStateRunning -> ServiceStateStopped @-}
stopService :: ServiceState -> ServiceState
stopService st = st {ssPhase = PhaseStopped}

-- | Terminal transition evaluation.
transition :: ServiceState -> ServiceCommand -> Either Text ServiceState
transition st cmd = case cmd of
  CmdInstall _ _ ->
    Right st
  CmdUninstall ->
    Right st
  CmdStart ->
    if ssPhase st == PhaseStopped
      then Right $ startService st
      else Left "Service must be stopped before start"
  CmdStop ->
    if ssPhase st == PhaseRunning || ssPhase st == PhaseDaemon
      then Right $ stopService st
      else Left "Service must be running before stop"
  CmdRun ->
    if ssPhase st == PhaseStopped
      then Right $ startService st
      else Left "Service already running"
  CmdDaemon ->
    Right $ st {ssPhase = PhaseDaemon}
  CmdClient ->
    Right st
  CmdRFID ->
    Right st
  CmdHelp ->
    Right st

-- | Expose the current service phase.
-- serviceStatePhase :: ServiceState -> ServicePhase
-- serviceStatePhase = ssPhase
