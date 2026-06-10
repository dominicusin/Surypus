{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Payroll (getEmployees, getEmployeeById, getSalaries, getSalaryByEmployee) where

import DAL.Queries (getEmployeeById, getSalaryByEmployee)
import DAL.QueriesORM (getEmployees, getSalaries)
