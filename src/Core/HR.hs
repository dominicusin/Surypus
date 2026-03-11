-- | HR Module - Human resources
-- Re-exports all HR types
module Core.HR
  ( module Core.HR.Employee,
    module Core.HR.Position,
  )
where

import Core.HR.Employee
import Core.HR.Position
import Data.Time (Day)

-- | Calculate tenure in days
calcTenure :: Employee -> Day -> Int
calcTenure emp today = fromEnum today - fromEnum (empHireDate emp)
