{-
TorXakis - Model Based Testing
Copyright (c) 2015-2017 TNO and Radboud University
See LICENSE at root directory of this repository.
-}
{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -fno-warn-missing-fields #-}
-- | Examples of usage of 'TorXakis.Lib'.
--
-- This file is meant to server as an example of usage of the 'TorXakis.Lib'.
-- These examples can be used as reference for developers of tools on top this
-- library.

module TorXakis.Lib.Examples where

import           Control.Concurrent           (threadDelay)
import           Control.Concurrent.Async     (async, cancel)
import           Control.Concurrent.STM.TChan (writeTChan)
import           Control.Monad                (void)
import           Control.Monad.STM            (atomically)
import           Data.Conduit                 (runConduit, (.|))
import           Data.Conduit.Combinators     (mapM_, sinkList, take)
import           Data.Conduit.TQueue          (sourceTQueue)
import           Data.Foldable                (traverse_)
import qualified Data.Map                     as Map
import qualified Data.Set                     as Set
import           Lens.Micro                   ((^.))
import           Prelude                      hiding (mapM_, take)
import           System.FilePath              ((</>))
import           System.Process               (StdStream (NoStream), proc,
                                               std_out, withCreateProcess)
import           System.Timeout               (timeout)

import           ChanId                       (ChanId (ChanId))
import           ConstDefs                    (Const (Cstring))
import           EnvData                      (Msg)
import           Id                           (Id (Id))
import           SortId                       (SortId (SortId))
import           TorXakis.Lib
import           TorXakis.Lib.Internal
import           TxsDDefs                     (Action (Act, ActQui))

-- | Get the next N messages in the session.
--
-- If no messages are available this call will block waiting for new messages.
-- Normally one won't use such a function, but it is useful when playing with
-- the core 'TorXakis' function in an GHCi session.
--
getNextNMsgs :: Session -> Int -> IO [Msg]
getNextNMsgs s n =
    runConduit $ sourceTQueue (s ^. sessionMsgs) .| take n .| sinkList

-- | Get and print the next messages.
printNextNMsgs :: Session -> Int -> IO ()
printNextNMsgs s n = getNextNMsgs s n >>= traverse_ print

-- | This example shows how to load a 'TorXakis' model, and run a couple of
-- steps with the stepper, leveraging on @Conduit@s for printing messages as
-- they become available.
testEchoReactive :: IO ()
testEchoReactive = do
    cs <- readFile $ "test" </> "data" </> "Echo.txs"
    s <- newSession
    -- Spawn off the printer process:
    a <- async (printer s)
    -- Load the model:
    r <- load s cs
    putStrLn $ "Result of `load`: " ++ show r
    -- Start the stepper:
    _  <- setStep s "Model"
    -- r' <- startStep s
    -- putStrLn $ "Result of `stepper`: " ++ show r'
    -- Run a couple of steps:
    r'' <- step s (NumberOfSteps 10)
    -- Note that the step function is asynchronous: it will return immediately:
    putStrLn $ "Result of `step`: " ++ show r''
    -- Run a couple more of steps:
    void $ step s (NumberOfSteps 10)
    -- Wait for the first verdict:
    waitForVerdict s >>= print
    -- Wait for the second verdict:
    waitForVerdict s >>= print
    -- Cancel the printer (we aren't interested in any more messages, as a
    -- verdict has been reached):
    cancel a

printer :: Session -> IO ()
printer s = runConduit $
    sourceTQueue (s ^. sessionMsgs) .|  mapM_ print

-- | This example shows how use the action parsing capabilities of the library.
testParseAction :: FilePath -> IO (Either Error Action)
testParseAction path = do
    cs <- readFile path
    s <- newSession
    r <- load s cs
    putStrLn $ "Result of `load`: " ++ show r
    _  <- setStep s "Model"
    -- r' <- startStep s
    -- putStrLn $ "Result of `step`: " ++ show r'
    parseAction s "In ! 90"

-- | This example parses a wrong action.
testParseWrongAction :: FilePath -> IO (Either Error Action)
testParseWrongAction path = do
    cs <- readFile path
    s <- newSession
    r <- load s cs
    putStrLn $ "Result of `load`: " ++ show r
    _  <- setStep s "Model"
    -- r' <- startStep s
    -- putStrLn $ "Result of `step`: " ++ show r'
    parseAction s "In" -- Error: no offer of type Int.

-- | This example shows what happens when you load an invalid file.
testWrongFile :: IO (Response ())
testWrongFile = do
    cs <- readFile $ "test" </> "data" </> "wrong.txt"
    s <- newSession
    -- Load the model:
    r <- load s cs
    putStrLn $ "Result of `load wrong.txt`: " ++ show r
    return r

testInfo :: IO ()
testInfo = case info of
    Info _v _b -> return ()

testPutToWReadsWorld :: IO Bool
testPutToWReadsWorld = do
    s <- newSession
    let fWCh = s ^. fromWorldChan
        txsChanId = ChanId "DummyChan" (Id 42) [SortId "DummySort" (Id 43)]
        actP = Act $ Set.fromList [(txsChanId, [Cstring "Action NOT to be put"])]
        actG = Act $ Set.fromList [(txsChanId, [Cstring "Action to be gotten"])]
        fakeSendToW :: ToWorldMapping
        fakeSendToW = error "This function should not be called in testPutToWReadsWorld, since there's an action waiting in fromWorldChan."
        toWMMs = Map.singleton txsChanId fakeSendToW
    atomically $ writeTChan fWCh actG
    action <- putToW 0 fWCh toWMMs actP
    atomically $ writeTChan fWCh actG
    action' <- putToW 0 fWCh Map.empty ActQui
    return $ action == actG && action' == actG

-- | This example tries to stop the core before all steps are taken.
-- Outcome: txsStop waits for current steps to finish, i.e. does not cancel.
testPrematureStop :: IO ()
testPrematureStop = do
    cs <- readFile $ "test" </> "data" </> "Echo.txs"
    s <- newSession
    a <- async (printer s)
    void $ load s cs
    void $ setStep s "Model"
    -- void $ startStep s
    r <- step s (NumberOfSteps 20)
    putStrLn $ "Result of `step`: " ++ show r
    r' <- stop s
    putStrLn $ "Result of `stop`: " ++ show r'
    r'' <- step s (NumberOfSteps 20)
    putStrLn $ "Result of `step` 2: " ++ show r''
    -- putStrLn $ "Results: " ++ show r ++ show r' ++ show r''
    waitForVerdict s >>= print
    -- Cancel the printer (we aren't interested in any more messages, as a
    -- verdict has been reached):
    cancel a

-- | Example of testing with an action.
testWithUserActions :: FilePath -> IO (Either Error ())
testWithUserActions path = do
    cs <- readFile path
    s <- newSession
    a <- async (printer s)
    void $ load s cs
    void $ setStep s "Model"
    -- void $ startStep s
    Right act0 <- parseAction s "In ! 22"
    _ <- step s (AnAction act0)
    Right act1 <- parseAction s "Out ! 22"
    r <- step s (AnAction act1)
    void $ waitForVerdict s
    threadDelay (1 * seconds)
    cancel a
    return r

testVals :: IO ()
testVals = do
    s <- newSession
    a <- async (printer s)
    cs <- readFile $ "test" </> "data" </> "Echo.txs"
    void $ load s cs
    vals <- getVals s
    x <- createVal s "x = 42"
    valsx <- getVals s
    y <- createVal s "y = 42"
    valsxy <- getVals s
    print $ "vals = " ++ show vals
    print $ "x = " ++ show x
    print $ "valsx = " ++ show valsx
    print $ "y = " ++ show y
    print $ "valsxy = " ++ show valsxy
    threadDelay (10 ^ (5 :: Int))
    cancel a

testTester :: IO (Maybe ())
testTester = timeout (10 * seconds) $
    withCreateProcess (proc "java" ["-cp","../../examps/LuckyPeople/sut","LuckyPeople"])
        {std_out = NoStream} $ \_stdin _stdout _stderr _ph -> do
            cs <- readFile $ ".." </> ".." </> "examps" </> "LuckyPeople" </> "spec" </> "LuckyPeople.txs"
            s <- newSession
            a <- async (printer s)
            _ <- load s cs
            _ <- setTest "Model" "Sut" "" s
            r <- test s (NumberOfSteps 10)
            putStrLn $ "Result of `test`: " ++ show r
            void $ test s (NumberOfSteps 10)
            waitForVerdict s >>= print
            waitForVerdict s >>= print
            cancel a

seconds :: Int
seconds = 10 ^ (6 :: Int)

-- | Test info
--
-- TODO: for now I'm putting this test here. We should find the right place for
-- this test. Once a new command line interface for TorXakis which uses
-- 'txs-lib' is ready we can proceed with removing this test.
-- testTorXakisWithInfo :: IO (Either SomeException Verdict)
-- testTorXakisWithInfo = withCreateProcess (proc "txs-webserver-exe" []) {std_out = NoStream} $ \_stdin _stdout _stderr _ph -> do
--     s <- newSession
--     cs <- readFile $   ".." </> ".."
--                    </> "examps" </> "TorXakisWithEcho"
--                    </> "TorXakisWithEchoInfoOnly.txs"
--     _ <- load s cs
--     st <- readTVarIO (s ^. sessionState)
--     let Just mDef = st ^. tdefs . ix ("Model" :: Name)
--         outChId = getOutChanId mDef
--         inChId  = getInChanId  mDef
--         mSendToW :: ToWorldMapping -- [Const] -> IO (Maybe Action)
--         mSendToW = ToWorldMapping $ \xs ->
--             case xs of
--                 [Cstr {cstrId = CstrId { name = "CmdInfo"}} ] ->
--                     -- This is where we send the command through HTTP
--                     Just <$> actInfo st outChId
--                 _   -> error $ "Didn't expect this data on channel " ++ show inChId
--                             ++ " (got " ++ show xs ++ ")"
--         s' :: Session
--         s' = s & wConnDef . toWorldMappings .~ Map.singleton inChId mSendToW
--     _ <- tester s' "Model"
--     _ <- test s' (NumberOfSteps 10)
--     a <- async (printer s')
--     v <- waitForVerdict s'
--     cancel a
--     return v

-- testTorXakisWithEcho :: IO (Either SomeException Verdict)
-- testTorXakisWithEcho = withCreateProcess (proc "txs-webserver-exe" []) {std_out = NoStream} $ \_stdin _stdout _stderr _ph -> do
--     s <- newSession
--     cs <- readFile $  ".." </> ".." </> "examps"
--                   </> "TorXakisWithEcho" </> "TorXakisWithEcho.txs"
--     _ <- load s cs
--     st <- readTVarIO (s ^. sessionState)
--     let Just mDef = st ^. tdefs . ix ("Model" :: Name)
--         outChId = getOutChanId mDef
--         inChId  = getInChanId  mDef
--         mSendToW :: ToWorldMapping -- [Const] -> IO (Maybe Action)
--         mSendToW = ToWorldMapping $ \xs ->
--             case xs of
--                 [Cstr { cstrId = CstrId { name = "CmdInfo" }} ] -> Just <$> actInfo st outChId
--                 [Cstr { cstrId = CstrId { name = "CmdLoad" }
--                       , args = [Cstring { cString = fileToLoad }]
--                       }] -> Just <$> actLoad st outChId fileToLoad
--                 [Cstr { cstrId = CstrId { name = "CmdStepper" }
--                       , args = [Cstring { cString = modelToStep }]
--                       }] -> Just <$> actStepper st outChId modelToStep
--                 [Cstr { cstrId = CstrId { name = "CmdStep" }
--                       , args = [Cint { cInt = stepCount }]
--                       }] -> actStep st outChId stepCount
--                 _   -> do putStrLn $ "Didn't expect this data on channel " ++ show inChId ++ " (got " ++ show xs ++ ")"
--                           return $ Just ActQui
--         mInitWorld :: TChan Action -> IO [ThreadId]
--         mInitWorld fWCh = do
--             tid <- forkIO $ do
--                 let
--                     writeToChan :: TChan Action -> BS.ByteString -> IO (TChan Action)
--                     writeToChan ch bs = do
--                         let nextLine = BS.unpack bs -- `head . lines` is not necessary, because every bs chunk is one line
--                             jsonStr = dropPrefix "data:" nextLine
--                         case decode $ BSL.pack jsonStr of
--                             Just AnAction{act = Act pairSet } -> do
--                                 let [(ChanId{ChanId.name=chNm},[prm])] = Set.toList pairSet
--                                 a <- createResponseAction st outChId "ResponseAction"
--                                                 [ cstrConst (Cstring chNm)
--                                                 , cstrConst prm
--                                                 ]
--                                 atomically $ writeTChan ch a
--                             _ -> return ()
--                         return ch
--                 initSession
--                 _ <- forever $ foldGet writeToChan fWCh "http://localhost:8080/session/sse/1/messages"
--                 return ()
--             return [tid]
--         s' :: Session
--         s' = s & wConnDef . toWorldMappings .~ Map.singleton inChId mSendToW
--                & wConnDef . initWorld .~ mInitWorld
--     _ <- tester s' "Model"
--     _ <- test s' (NumberOfSteps 20)
--     a <- async (printer s')
--     v <- waitForVerdict s'
--     cancel a
--     return v

-- actInfo :: SessionSt -> ChanId -> IO Action
-- actInfo st outChId = do
--     -- In this case it's just a GET request
--     -- TODO: This address should be extracted from Model CNECTDEF
--     resp <- get "http://localhost:8080/info"
--     let status = resp ^. responseStatus . statusCode
--     if status /= 200
--         then createResponseAction st outChId "ResponseFailure" [cstrConst (Cstring $ T.pack $ "/info returned unxpected status: " ++ show status)]
--         else createResponseAction st outChId "ResponseInfo" $ infoParams resp
--               where
--                 infoParams r =
--                     let Just (String version'  ) = r ^? responseBody . key "version"
--                         Just (String buildTime') = r ^? responseBody . key "buildTime"
--                     in  [cstrConst (Cstring version')
--                         , cstrConst (Cstring buildTime')]

-- actLoad ::  SessionSt -> ChanId -> Text -> IO Action
-- actLoad st outChId path = do
--     resp <- post "http://localhost:8080/session/1/model" [partFile "txs" (T.unpack $ "..\\..\\" <> path)]
--     case resp ^. responseStatus . statusCode of
--         201 -> createResponseAction st outChId "ResponseSuccess" []
--         s   -> createResponseAction st outChId "ResponseFailure" [cstrConst (Cstring $ T.pack $ "/session/1/model returned unxpected status: " ++ show s)]

-- actStepper ::  SessionSt -> ChanId -> Text -> IO Action
-- actStepper st outChId model = do
--     resp <- post (T.unpack $ "http://localhost:8080/stepper/start/1/" <> model) [partText "" ""]
--     case resp ^. responseStatus . statusCode of
--         200 -> createResponseAction st outChId "ResponseSuccess" []
--         s   -> createResponseAction st outChId "ResponseFailure" [cstrConst (Cstring $ "/stepper/start/1/" <> model <> " returned unxpected status: " <> T.pack (show s))]

-- actStep ::  SessionSt -> ChanId -> Integer -> IO (Maybe Action)
-- actStep st outChId n = do
--     resp <- post ("http://localhost:8080/stepper/step/1/" ++ show n) [partText "" ""]
--     case resp ^. responseStatus . statusCode of
--         200 -> return Nothing
--         s   -> Just <$> createResponseAction st outChId "ResponseFailure"
--                             [cstrConst (Cstring $ T.pack $ "/stepper/step/1/" ++ show n ++ " returned unxpected status: " ++ show s)]

-- initSession :: IO ()
-- initSession = do
--     resp <- post "http://localhost:8080/session/new" [partText "" ""]
--     let status = resp ^. responseStatus . statusCode
--     when (status /= 201) $
--         error $ "/session/new returned unxpected status: " ++ show status

-- getOutChanId :: ModelDef -> ChanId
-- getOutChanId mDef =
--     let [setChId] = mDef ^. modelOutChans
--         [outChId] = Set.toList setChId
--     in  outChId

-- getInChanId :: ModelDef -> ChanId
-- getInChanId mDef =
--     let [setChId] = mDef ^. modelInChans
--         [inChId] = Set.toList setChId
--     in inChId

-- createResponseAction :: SessionSt -> ChanId -> Text -> [ValExpr VarId] -> IO Action
-- createResponseAction st outChId rNm params = do
--     let [sId] = [ SortId n i
--                 | (SortId n i, _) <- Map.toList $ sortDefs (st ^. tdefs)
--                 ,  n == "Response" ]
--         ft = st ^. sigs . funcTable
--     res <- apply st ft rNm params sId
--     case res of
--         Right cnst -> return $ Act $ Set.fromList [(outChId, [cnst])]
--         Left  err  -> error $ "Can't create ResponseAction " ++ T.unpack rNm ++ " because: " ++ err

-- apply :: SessionSt -> FuncTable VarId -> Text -> [ValExpr VarId] -> SortId -> IO (Either String Const)
-- apply st ft fn vs sId = do
--     let sig = Signature (sortOf <$> vs) sId
--     case Map.lookup sig (signHandler fn ft) of
--         Nothing -> return $ Left $ "No handler found for sig:" ++ show sig
--         Just f  ->
--             let envB = EnvB
--                         { smts = Map.empty
--                         , E.tdefs = st ^. tdefs
--                         , E.sigs = st ^. sigs
--                         , stateid = -1
--                         , E.unid = 10000
--                         , E.params = Map.empty
--                         , msgs = []
--                         }
--             in evalStateT (eval (f vs)) envB -- TODO: Should not use eval, just parse a Response with new ADTDefs.
