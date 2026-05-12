module DAL.Repository.RBAC where

import Data.Text (Text)
import Hasql.Pool (Pool)
import Control.Monad.Trans.Except (ExceptT)
import Surypus.RBAC (Permission)

data RBACRepository = RBACRepository { repoPool :: Pool }

mkRBACRepository :: Pool -> RBACRepository
mkRBACRepository = RBACRepository

checkUserAppPermissionRepo :: RBACRepository -> Int -> Permission -> ExceptT Text IO Bool
checkUserAppPermissionRepo _ _ _ = return True
