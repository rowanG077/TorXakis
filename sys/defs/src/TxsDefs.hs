{-
TorXakis - Model Based Testing
Copyright (c) 2015-2017 TNO and Radboud University
See LICENSE at root directory of this repository.
-}
{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE DeriveGeneric     #-}
-- ----------------------------------------------------------------------------------------- --
--
-- TorXakis Interal Data Type Definitions:
--
--   *  General     :  general definitions
--   *  Frontend    :  (static) abstract syntax definitions for the TorXakis Language (.txs)
--   *  Connections :  connections to outside world
--
-- ----------------------------------------------------------------------------------------- --
module TxsDefs
( TxsDefs(..)
, TxsDefs.empty
, TxsDefs.toList
, TxsDefs.lookup
, TxsDefs.keys
, TxsDefs.elems
, TxsDefs.union
, VarEnv
, VExpr
, VEnv
, WEnv
, ProcDef(ProcDef)
, ProcId(ProcId)
, ChanId(ChanId)
, StatId(StatId)
, ModelDef(ModelDef)
, ModelId(ModelId)
, PurpDef(PurpDef)
, PurpId(PurpId)
, GoalId(GoalId)
, MapperDef(MapperDef)
, MapperId(MapperId)
, CnectDef(CnectDef)
, CnectId(CnectId)
, ExitSort(..)
, module X
)
where
import           Control.Arrow
import           Control.DeepSeq
import qualified Data.HashMap.Strict as HMap
import qualified Data.Map.Strict     as Map
import           GHC.Generics    (Generic)

import           BehExprDefs     as X
import           ConnectionDefs  as X

import           ChanId
import           CnectDef
import           CnectId
import           FuncDef
import           FuncId
import           GoalId
import           Ident
import           MapperDef
import           MapperId
import           ModelDef
import           ModelId
import           ProcDef
import           ProcId
import           PurpDef
import           PurpId
import           Sort
import           StatId
import           TxsDef
import           VarEnv
import           VarId

data  TxsDefs  =  TxsDefs { adtDefs    :: ADTDefs
                          , funcDefs   :: Map.Map FuncId (FuncDef VarId)
                          , procDefs   :: Map.Map ProcId ProcDef
                          , chanDefs   :: Map.Map ChanId ()            -- only for parsing, not envisioned for computation
                          , varDefs    :: Map.Map VarId ()             -- local
                          , statDefs   :: Map.Map StatId ()            -- local
                          , modelDefs  :: Map.Map ModelId ModelDef
                          , purpDefs   :: Map.Map PurpId PurpDef
                          , goalDefs   :: Map.Map GoalId () --BExpr    -- local, part of PurpDefs
                          , mapperDefs :: Map.Map MapperId MapperDef
                          , cnectDefs  :: Map.Map CnectId CnectDef
                          }
                  deriving (Eq,Read,Show, Generic, NFData)

empty :: TxsDefs
empty = TxsDefs  emptyADTDefs
                 Map.empty
                 Map.empty
                 Map.empty
                 Map.empty
                 Map.empty
                 Map.empty
                 Map.empty
                 Map.empty
                 Map.empty
                 Map.empty

lookup :: Ident -> TxsDefs -> Maybe TxsDef
lookup (IdADT r) txsdefs = case HMap.lookup r (adtDefsToMap $ adtDefs txsdefs) of
                                Nothing -> Nothing
                                Just d  -> Just (DefADT d)
lookup (IdFunc s) txsdefs = case Map.lookup s (funcDefs txsdefs) of
                                Nothing -> Nothing
                                Just d  -> Just (DefFunc d)
lookup (IdProc s) txsdefs = case Map.lookup s (procDefs txsdefs) of
                                Nothing -> Nothing
                                Just d  -> Just (DefProc d)
lookup (IdChan s) txsdefs = case Map.lookup s (chanDefs txsdefs) of
                                Nothing -> Nothing
                                Just _  -> Just DefChan
lookup (IdVar s) txsdefs = case Map.lookup s (varDefs txsdefs) of
                                Nothing -> Nothing
                                Just _  -> Just DefVar
lookup (IdStat s) txsdefs = case Map.lookup s (statDefs txsdefs) of
                                Nothing -> Nothing
                                Just _  -> Just DefStat
lookup (IdModel s) txsdefs = case Map.lookup s (modelDefs txsdefs) of
                                Nothing -> Nothing
                                Just d  -> Just (DefModel d)
lookup (IdPurp s) txsdefs = case Map.lookup s (purpDefs txsdefs) of
                                Nothing -> Nothing
                                Just d  -> Just (DefPurp d)
lookup (IdGoal s) txsdefs = case Map.lookup s (goalDefs txsdefs) of
                                Nothing -> Nothing
                                Just _  -> Just DefGoal
lookup (IdMapper s) txsdefs = case Map.lookup s (mapperDefs txsdefs) of
                                Nothing -> Nothing
                                Just d  -> Just (DefMapper d)
lookup (IdCnect s) txsdefs = case Map.lookup s (cnectDefs txsdefs) of
                                Nothing -> Nothing
                                Just d  -> Just (DefCnect d)

-- TODO: this is never used
toList :: TxsDefs -> [(Ident, TxsDef)]
toList t =      map (IdADT Control.Arrow.*** DefADT)            (HMap.toList (adtDefsToMap $ adtDefs t))
            ++  map (IdFunc Control.Arrow.*** DefFunc)          (Map.toList (funcDefs t))
            ++  map (IdProc Control.Arrow.*** DefProc)          (Map.toList (procDefs t))
            ++  map (IdChan Control.Arrow.*** const DefChan)    (Map.toList (chanDefs t))
            ++  map (IdVar Control.Arrow.*** const DefVar)      (Map.toList (varDefs t))
            ++  map (IdStat Control.Arrow.*** const DefStat)    (Map.toList (statDefs t))
            ++  map (IdModel Control.Arrow.*** DefModel)        (Map.toList (modelDefs t))
            ++  map (IdPurp Control.Arrow.*** DefPurp)          (Map.toList (purpDefs t))
            ++  map (IdGoal Control.Arrow.*** const DefGoal)    (Map.toList (goalDefs t))
            ++  map (IdMapper Control.Arrow.*** DefMapper)      (Map.toList (mapperDefs t))
            ++  map (IdCnect Control.Arrow.*** DefCnect)        (Map.toList (cnectDefs t))


keys :: TxsDefs -> [Ident]
keys t =        map IdADT       (HMap.keys (adtDefsToMap $ adtDefs t))
            ++  map IdFunc      (Map.keys (funcDefs t))
            ++  map IdProc      (Map.keys (procDefs t))
            ++  map IdChan      (Map.keys (chanDefs t))
            ++  map IdVar       (Map.keys (varDefs t))
            ++  map IdStat      (Map.keys (statDefs t))
            ++  map IdModel     (Map.keys (modelDefs t))
            ++  map IdPurp      (Map.keys (purpDefs t))
            ++  map IdGoal      (Map.keys (goalDefs t))
            ++  map IdMapper    (Map.keys (mapperDefs t))
            ++  map IdCnect     (Map.keys (cnectDefs t))

elems :: TxsDefs -> [TxsDef]
elems t =       map DefADT          (HMap.elems (adtDefsToMap $ adtDefs t))
            ++  map DefFunc         (Map.elems (funcDefs t))
            ++  map DefProc         (Map.elems (procDefs t))
            ++  map (const DefChan) (Map.elems (chanDefs t))
            ++  map (const DefVar)  (Map.elems (varDefs t))
            ++  map (const DefStat) (Map.elems (statDefs t))
            ++  map DefModel        (Map.elems (modelDefs t))
            ++  map DefPurp         (Map.elems (purpDefs t))
            ++  map (const DefGoal) (Map.elems (goalDefs t))
            ++  map DefMapper       (Map.elems (mapperDefs t))
            ++  map DefCnect        (Map.elems (cnectDefs t))


union :: TxsDefs -> TxsDefs -> TxsDefs
union a b = TxsDefs
                mergedADTDefs
                (Map.union (funcDefs a)  (funcDefs b)   )
                (Map.union (procDefs a)  (procDefs b)   )
                (Map.union (chanDefs a)  (chanDefs b)   )
                (Map.union (varDefs a)   (varDefs b)    )
                (Map.union (statDefs a)  (statDefs b)   )
                (Map.union (modelDefs a) (modelDefs b)  )
                (Map.union (purpDefs a)  (purpDefs b)   )
                (Map.union (goalDefs a)  (goalDefs b)   )
                (Map.union (mapperDefs a)(mapperDefs b) )
                (Map.union (cnectDefs a) (cnectDefs b)  )
            where
                Right mergedADTDefs = mergeADTDefs (adtDefs a) (adtDefs b)
