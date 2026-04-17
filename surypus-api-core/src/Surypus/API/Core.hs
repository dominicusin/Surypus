{-# LANGUAGE DuplicateRecordFields #-}

module Surypus.API.Core
  ( module Surypus.API.Root,
    module Surypus.API.Server,
    module Surypus.API.Types,
  )
where

-- Re-export core API surface to enable staged migration
import Surypus.API.Root
import Surypus.API.Server
import Surypus.API.Types
