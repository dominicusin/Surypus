{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Payroll (getEmployees, getEmployeeById, getSalaries, getSalaryByEmployee, createEmployee, createSalary) where

import DAL.Queries (getEmployeeById, getSalaryByEmployee)
import DAL.QueriesORM (getEmployees, getSalaries)
import DAL.Mutations (createEmployee, createSalary)
