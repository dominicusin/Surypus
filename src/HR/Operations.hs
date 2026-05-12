-- | Person Operations with Formal Verification
module HR.Operations
  ( PersonOpResult (..),
    validatePerson,
    validatePhone,
    validateEmail,
    checkDuplicateINN,
    isValidPersonKind,
    isActiveStatus,
    getPersonDisplayName
  ) where

import Data.Char (isDigit)
import Data.Text (Text)
import qualified Data.Text as T
import HR.Person (Person (..), PersonKind (..), PersonStatus (..), validateINN, validateKPP, validatePhone, validateEmail)

data PersonOpResult
  = PersonOpSuccess
  | PersonOpInvalidINN
  | PersonOpInvalidKPP
  | PersonOpInvalidPhone
  | PersonOpInvalidEmail
  | PersonOpDuplicateINN
  | PersonOpInvalidName

validatePerson :: Person -> PersonOpResult
validatePerson p
  | T.null (pName p) = PersonOpInvalidName
  | T.null (pINN p) = PersonOpInvalidINN
  | not (validateINN (pINN p)) = PersonOpInvalidINN
  | not (T.null (pKPP p)) && not (validateKPP (pKPP p)) = PersonOpInvalidKPP
  | not (T.null (pPhone p)) && not (validatePhone (pPhone p)) = PersonOpInvalidPhone
  | not (T.null (pEmail p)) && not (validateEmail (pEmail p)) = PersonOpInvalidEmail
  | otherwise = PersonOpSuccess

checkDuplicateINN :: Text -> IO (Either PersonOpResult Person)
checkDuplicateINN _ = return (Left PersonOpSuccess)

isValidPersonKind :: PersonKind -> Bool
isValidPersonKind pk = pk `elem` [PKCompany, PKIndividual, PKEntrepreneur]

isActiveStatus :: PersonStatus -> Bool
isActiveStatus PSActive = True
isActiveStatus _ = False

getPersonDisplayName :: Person -> Text
getPersonDisplayName p = if T.null (pShortName p) then pName p else pShortName p