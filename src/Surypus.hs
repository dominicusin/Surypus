-- | Surypus - Formally verified ERP system
--
-- This module re-exports the core subsystems of the Surypus ERP:
--
-- * 'Surypus.Core' - Unified domain model with entity classes
-- * 'Surypus.RBAC' - Role-based access control
-- * 'Surypus.JWT' - JSON Web Token authentication
-- * 'Surypus.Types' - Core types (Decimal, etc.)
-- * 'Surypus.Error' - Error types
-- * 'Surypus.Validation' - Input validation
-- * 'Surypus.Cache' - Caching infrastructure
module Surypus
  ( -- * Core Domain
    module Surypus.Core,

    -- * Access Control
    module Surypus.RBAC,
    module Surypus.RBAC.Store,

    -- * Authentication
    module Surypus.JWT,

    -- * Types
    module Surypus.Types,
    module Surypus.Error,
    module Surypus.Validation,
    module Surypus.Cache,

    -- * API
    module Surypus.API.Server,
    module Surypus.API.Authorization,
    module Surypus.API.Health,

    -- * Reporting
    module Surypus.Reports,
    module Surypus.Reports.Templates,

    -- * Infrastructure
    module Surypus.Config,
    module Surypus.Event,
    module Surypus.I18n,
    module Surypus.Logging,
  )
where

import Surypus.API.Authorization
import Surypus.API.Health
import Surypus.API.Server
import Surypus.Cache
import Surypus.Config
import Surypus.Core
import Surypus.Error
import Surypus.Event
import Surypus.I18n
import Surypus.JWT
import Surypus.Logging
import Surypus.RBAC
import Surypus.RBAC.Store
import Surypus.Reports
import Surypus.Reports.Templates
import Surypus.Types
import Surypus.Validation
