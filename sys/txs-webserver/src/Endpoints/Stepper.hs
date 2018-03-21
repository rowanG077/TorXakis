module Endpoints.Stepper
( StartStepperEP
, startStepper
, TakeNStepsEP
, takeNSteps
) where

import           Control.Monad.IO.Class      (liftIO)
import           Data.ByteString.Lazy.Char8  (pack)
import           Data.Text                   (Text)
import           Servant

import           TorXakis.Lib                (stepper, Response (..), step, StepType (..))

import           Common (SessionId, getSession, Env)

type StartStepperEP = "stepper"
                   :> "start"
                   :> Capture "sid" SessionId
                   :> Capture "model" Text
                   :> Post '[JSON] String
                      
type TakeNStepsEP   = "stepper"
                   :> "step"
                   :> Capture "sid" SessionId
                   :> Capture "steps" Int
                   :> Post '[JSON] String

startStepper :: Env -> SessionId -> Text -> Handler String
startStepper env sid model = do
    s <- getSession env sid
    r <- liftIO $ do
            putStrLn $ "Starting stepper for model " ++ show model ++ " in session " ++ show sid 
            r <- stepper s model
            print r
            return r
    case r of
        Success -> return $ show Success
        Error m -> throwError $ err500 { errBody = pack m }

takeNSteps :: Env -> SessionId -> Int -> Handler String
takeNSteps env sid steps = do
    s <- getSession env sid
    r <- liftIO $ do
            putStrLn $ "Taking " ++ show steps ++ " steps in session " ++ show sid 
            r <- step s $ NumberOfSteps steps
            print r
            return r
    case r of
        Success -> return $ show Success
        Error m -> throwError $ err500 { errBody = pack m }

