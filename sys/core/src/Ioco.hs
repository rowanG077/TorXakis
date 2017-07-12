{-
TorXakis - Model Based Testing
Copyright (c) 2015-2016 TNO and Radboud University
See license.txt
-}


-- ----------------------------------------------------------------------------------------- --

module Ioco

-- ----------------------------------------------------------------------------------------- --
-- 
-- Test Primitives for an IOCO Model, built on Behave
-- 
-- ----------------------------------------------------------------------------------------- --
-- export


( iocoModelMenuIn    -- :: IOC.IOC BTree.Menu
, iocoModelMenuOut   -- :: IOC.IOC BTree.Menu
, iocoModelIsQui     -- :: IOC.IOC Bool
, iocoModelAfter     -- :: TxsDDefs.Action -> IOC.IOC Bool
)

-- ----------------------------------------------------------------------------------------- --
-- import 

where

import Control.Monad.State

import qualified Data.Set  as Set
import qualified Data.Map  as Map


-- import from local
import CoreUtils

-- import from behavedef
import qualified BTree

-- import from behaveenv
import qualified Behave

-- import from coreenv
import qualified EnvCore   as IOC
import qualified EnvData

-- import from defs
import qualified TxsDefs
import qualified TxsDDefs

import qualified Utils


-- ----------------------------------------------------------------------------------------- --
-- iocoModelMenuIn  :  input  menu on current btree of model, no quiescence, according to ioco
-- iocoModelMenuOut :  output menu on current btree of model, no quiescence, according to ioco


iocoModelMenu :: IOC.IOC BTree.Menu
iocoModelMenu  =  do
     validModel <- validModDef
     case validModel of
     { Nothing -> do
            IOC.putMsgs [ EnvData.TXS_CORE_SYSTEM_ERROR "iocoModelMenu without valid model" ]
            return $ []
     ; Just (TxsDefs.ModelDef insyncs outsyncs splsyncs bexp) -> do
            allSyncs <- return $ insyncs ++ outsyncs ++ splsyncs
            modSts   <- gets IOC.modsts
            return $ Behave.behMayMenu allSyncs modSts
     }


iocoModelMenuIn :: IOC.IOC BTree.Menu
iocoModelMenuIn  =  do
     menu <- iocoModelMenu
     filterM (isInCTOffers . Utils.frst) menu


iocoModelMenuOut :: IOC.IOC BTree.Menu
iocoModelMenuOut  =  do
     menu <- iocoModelMenu
     filterM (isOutCTOffers . Utils.frst) menu


-- ----------------------------------------------------------------------------------------- --
-- iocoModelIsQui :  quiescence test on current btree of model 


iocoModelIsQui :: IOC.IOC Bool
iocoModelIsQui  =  do
     validModel <- validModDef
     case validModel of
     { Nothing -> do
            IOC.putMsgs [ EnvData.TXS_CORE_SYSTEM_ERROR "iocoModelIsQui without valid model" ]
            return $ False
     ; Just (TxsDefs.ModelDef insyncs outsyncs splsyncs bexp) -> do
            modSts <- gets IOC.modsts
            return $ Behave.behRefusal modSts (Set.unions outsyncs)
     }


-- ----------------------------------------------------------------------------------------- --
-- iocoModelAfter :  do action on current btree and change environment accordingly
-- result gives success, ie. whether act can be done, if not succesful env is not changed
-- act must be a non-empty action; Act ActIn ActOut or ActQui


iocoModelAfter :: TxsDDefs.Action -> IOC.IOC Bool

iocoModelAfter act@(TxsDDefs.Act acts)  =  do
     validModel <- validModDef
     case validModel of
     { Nothing -> do
            IOC.putMsgs [ EnvData.TXS_CORE_SYSTEM_ERROR "iocoModelAfter without valid model" ]
            return $ False
     ; Just (TxsDefs.ModelDef insyncs outsyncs splsyncs bexp) -> do
            allSyncs       <- return $ insyncs ++ outsyncs ++ splsyncs
            curState       <- gets IOC.curstate
            modSts         <- gets IOC.modsts
            envb           <- filterEnvCtoEnvB
            (maybt',envb') <- lift $ runStateT (Behave.behAfterAct allSyncs modSts acts) envb
            case maybt' of
            { Nothing  -> do return $ False
            ; Just bt' -> do writeEnvBtoEnvC envb'
                             modify $ \env -> env
                               { IOC.behtrie  = (IOC.behtrie env) ++ [(curState,act,curState+1)]
                               , IOC.curstate = curState + 1
                               , IOC.modsts   = bt'
                               }
                             return $ True
            }
     }


iocoModelAfter act@(TxsDDefs.ActQui)  =  do
     validModel <- validModDef
     case validModel of
     { Nothing -> do
            IOC.putMsgs [ EnvData.TXS_CORE_SYSTEM_ERROR "iocoModelAfter without valid model" ]
            return $ False
     ; Just (TxsDefs.ModelDef insyncs outsyncs splsyncs bexp) -> do
            curState       <- gets IOC.curstate
            modSts         <- gets IOC.modsts
            envb           <- filterEnvCtoEnvB
            (maybt',envb') <- lift $ runStateT (Behave.behAfterRef modSts (Set.unions outsyncs))
                                               envb
            case maybt' of
            { Nothing  -> do return $ False
            ; Just bt' -> do writeEnvBtoEnvC envb'
                             modify $ \env -> env
                               { IOC.behtrie  = (IOC.behtrie env) ++ [(curState,act,curState+1)]
                               , IOC.curstate = curState + 1
                               , IOC.modsts   = bt'
                               }
                             return $ True
            }
     }


-- ----------------------------------------------------------------------------------------- --


validModDef :: IOC.IOC (Maybe TxsDefs.ModelDef)
validModDef  =  do
     envc <- get
     case envc of
     { IOC.Testing {IOC.modeldef = moddef} -> return $ Just moddef
     ; IOC.Simuling {IOC.modeldef = moddef} -> return $ Just moddef
     ; _ -> return $ Nothing
     }


-- ----------------------------------------------------------------------------------------- --
--                                                                                           --
-- ----------------------------------------------------------------------------------------- --
