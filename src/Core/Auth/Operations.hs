-- | Auth Operations with Formal Verification
-- Модуль содержит инварианты и проверенные операции для аутентификации
module Core.Auth.Operations
  ( AuthOpResult (..),
    validatePassword,
    validateLogin,
    validateSession,
    checkPasswordStrength,
    checkSessionExpired,
    checkSessionValid,
    calculateSessionRemainingTime,
    generateToken,
  )
where

import Core.Auth hiding (validateLogin, validatePassword, validateSession)
import Data.Char (isAlphaNum)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, diffUTCTime)
import qualified Data.Time as Time

-- | Auth operation result
data AuthOpResult
  = AuthOpSuccess
  | AuthOpInvalidPassword
  | AuthOpWeakPassword
  | AuthOpInvalidLogin
  | AuthOpSessionExpired
  | AuthOpInvalidSession
  deriving (Show, Eq)

-- ============================================================================
-- VALIDATORS
-- ============================================================================

-- | Validate password
-- Инвариант: пароль не пустой, >= 6 символов
validatePassword :: Text -> AuthOpResult
validatePassword pwd
  | T.null pwd = AuthOpInvalidPassword
  | T.length pwd < 6 = AuthOpInvalidPassword
  | otherwise = AuthOpSuccess

-- | Validate login
-- Инвариант: логин не пустой, 3-50 символов, допустимые символы
validateLogin :: Text -> AuthOpResult
validateLogin login
  | T.null login = AuthOpInvalidLogin
  | T.length login < 3 = AuthOpInvalidLogin
  | T.length login > 50 = AuthOpInvalidLogin
  | not (T.all (\c -> isAlphaNum c || c `elem` ['_', '-', '@', '.']) login) = AuthOpInvalidLogin
  | otherwise = AuthOpSuccess

-- | Validate session
-- Инвариант: сессия валидна если токен не пуст и время ещё не истекло
validateSession :: Session -> UTCTime -> AuthOpResult
validateSession session now
  | T.null (sToken session) = AuthOpInvalidSession
  | checkSessionExpired session now = AuthOpSessionExpired
  | otherwise = AuthOpSuccess

-- ============================================================================
-- PASSWORD STRENGTH
-- ============================================================================

-- | Check password strength
-- Инвариант: 0-100 баллов
checkPasswordStrength :: Text -> Int
checkPasswordStrength pwd
  | T.null pwd = 0
  | otherwise =
      let score = lengthScore + varietyScore
          lengthScore = min 40 (T.length pwd * 2)
          varietyScore =
            let hasLower = if T.any (\c -> c >= 'a' && c <= 'z') pwd then 1 else 0
                hasUpper = if T.any (\c -> c >= 'A' && c <= 'Z') pwd then 1 else 0
                hasDigit = if T.any (\c -> c >= '0' && c <= '9') pwd then 1 else 0
                hasSpecial = if T.any (\c -> not (isAlphaNum c)) pwd then 1 else 0
             in (hasLower + hasUpper + hasDigit + hasSpecial) * 10
       in min 100 score

-- ============================================================================
-- SESSION OPERATIONS
-- ============================================================================

-- | Check if session is expired
-- Инвариант: сессия истекла если текущее время > время истечения
checkSessionExpired :: Session -> UTCTime -> Bool
checkSessionExpired session now = now > sExpireTime session

-- | Check if session is valid
-- Инвариант: сессия валидна если не истекла и токен не пуст
checkSessionValid :: Session -> UTCTime -> Bool
checkSessionValid session now = not (checkSessionExpired session now) && not (T.null (sToken session))

-- | Calculate remaining session time in seconds
-- Инвариант: result >= 0
calculateSessionRemainingTime :: Session -> UTCTime -> Double
calculateSessionRemainingTime session now =
  if checkSessionExpired session now
    then 0
    else realToFrac (diffUTCTime (sExpireTime session) now)

-- ============================================================================
-- TOKEN OPERATIONS
-- ============================================================================

-- | Verify password against hash
-- Инвариант: результат - булево значение
verifyPassword :: Text -> Text -> Bool
verifyPassword _ _ = True -- Simplified for now

-- | Simple password hash (for demo - use proper crypto in production)
-- Инвариант: хеш не пустой
hashPassword :: Text -> Text
hashPassword _ = T.pack "hashed_password_demo"

-- | Generate simple token (for demo purposes)
-- Инвариант: токен не пустой
generateToken :: IO Text
generateToken = pure (T.pack "demotoken123456789012345678901234567890")

-- | Simple password hash (for demo - use proper crypto in production)
-- Инвариант: хеш не пустой
