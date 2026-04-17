module System.EmailSender where

import Control.Monad.IO.Class (MonadIO (..))
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (getCurrentTime)
import Network.Mail.SMTP
import Network.SMTP.Mailgun

-- | Email configuration
data EmailConfig = EmailConfig
  { smtpHost :: String,
    smtpPort :: Int,
    smtpUser :: String,
    smtpPass :: String,
    mgApiKey :: Maybe String,
    mgDomain :: Maybe String
  }

-- | Email message
data EmailMessage = EmailMessage
  { from :: Email,
    to :: [Email],
    subject :: String,
    body :: String,
    cc :: [Email],
    bcc :: [Email],
    attachments :: [Attach]
  }

-- | Initialize email sender
initEmailSender :: EmailConfig -> IO EmailConfig
initEmailSender config = do
  -- Validate configuration
  let valid = not (null (smtpHost config))
  if valid
    then return config
    else error "Invalid email configuration"

-- | Send email synchronously
sendEmail :: EmailConfig -> EmailMessage -> IO (Either String String)
sendEmail config msg = do
  let mail =
        simpleMail
          (fromAddress $ from msg)
          (map toAddress $ to msg)
          (map toAddress $ cc msg)
          (map toAddress $ bcc msg)
          (T.pack $ subject msg)
          (T.pack $ body msg)
          (attachments msg)

  result <- case mgApiKey config of
    Just key -> do
      -- Use Mailgun API
      let api = MailgunAPI (T.pack key) (T.pack $ fromMaybe "api.mailgun.net" (mgDomain config))
      sendMailgun api (from msg) (to msg) (subject msg) (body msg)
    Nothing -> do
      -- Use SMTP
      smtpSend (smtpHost config) (smtpPort config) (smtpUser config) (smtpPass config) mail

  case result of
    Right _ -> return $ Right "Email sent successfully"
    Left err -> return $ Left (show err)

-- | Send email with template
sendEmailTemplate :: EmailConfig -> EmailMessage -> Text -> Map.Map Text Text -> IO (Either String String)
sendEmailTemplate config msg template vars = do
  -- Render template with variables
  let renderedBody = renderTemplate template vars
  let msg' = msg {body = renderedBody}
  sendEmail config msg'

-- | Render simple template
renderTemplate :: Text -> Map.Map Text Text -> String
renderTemplate template vars = T.unpack $ T.foldl' replace template (Map.toList vars)
  where
    replace tmpl (k, v) = T.replace ("{{" <> k <> "}}") v tmpl

-- | Validate email address
validateEmail :: String -> Bool
validateEmail email = "@" `elem` email && "." `elem` email

-- | Get current timestamp for email
getCurrentTimestamp :: IO String
getCurrentTimestamp = do
  time <- getCurrentTime
  return $ show time
