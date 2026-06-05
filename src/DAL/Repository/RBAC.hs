module DAL.Repository.RBAC where

import Data.Text (Text)
import DAL.ORMPool (ConnectionPool)
import Control.Monad.Trans.Except (ExceptT)
import Surypus.RBAC (Permission)

data RBACRepository = RBACRepository { repoPool :: ConnectionPool }

mkRBACRepository :: ConnectionPool -> RBACRepository
mkRBACRepository = RBACRepository

checkUserAppPermissionRepo :: RBACRepository -> Int -> Permission -> ExceptT Text IO Bool
checkUserAppPermissionRepo _ _ _ = return True
