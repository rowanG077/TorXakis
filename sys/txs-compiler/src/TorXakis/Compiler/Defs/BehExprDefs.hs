{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module TorXakis.Compiler.Defs.BehExprDefs where

import qualified Data.Map as Map
import           Control.Monad.Error.Class         (liftEither)
import           Data.Maybe                        (fromMaybe)
import qualified Data.Set                          as Set
import           Data.Text (Text)

import           StdTDefs (chanIdIstep)
import           ConstDefs                         (Const (Cbool))
import           SortId                            (sortIdBool, SortId)
import           TxsDefs                           (ActOffer (ActOffer), BExpr, ChanOffer (Quest, Exclam),
                                                    Offer (Offer), chanid, actionPref, stop, valueEnv)
import           ValExpr                           (cstrConst)
import           ChanId (ChanId (ChanId), chansorts, name, unid)
import           VarId (VarId, varsort)
import           FuncId (FuncId)
import           FuncDef (FuncDef)
import           ValExpr (ValExpr)
    
import           TorXakis.Compiler.Data
import           TorXakis.Compiler.Maps
import           TorXakis.Compiler.MapsTo
import           TorXakis.Compiler.ValExpr.ValExpr
import           TorXakis.Parser.Data

toBExpr :: ( MapsTo Text ChanId mm
           , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [FuncDefInfo]) mm
           , MapsTo (Loc VarDeclE) VarId mm
           , MapsTo FuncDefInfo FuncId mm
           , MapsTo FuncId (FuncDef VarId) mm )
        => mm -> BExpDecl -> CompilerM BExpr
toBExpr _ Stop             = return stop
toBExpr mm (ActPref ao be) = actionPref <$> toActOffer mm ao <*> toBExpr mm be
toBExpr mm (LetBExp vs be) = valueEnv   <$> venv <*> toBExpr mm be
    where
      venv = Map.fromList <$> traverse vpair vs
      vpair :: LetVarDecl -> CompilerM (VarId, ValExpr VarId)
      vpair vd = do
          vId <- mm .@ getLoc vd
          ex  <- liftEither $
              expDeclToValExpr mm (varsort vId) (varDeclExp vd)
          return (vId, ex)

toActOffer :: ( MapsTo Text ChanId mm
              , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [FuncDefInfo]) mm
              , MapsTo (Loc VarDeclE) VarId mm
              , MapsTo FuncDefInfo FuncId mm
              , MapsTo FuncId (FuncDef VarId) mm )
           => mm -> ActOfferDecl -> CompilerM ActOffer
toActOffer mm (ActOfferDecl osd mc) = do
    os <- traverse (toOffer mm) osd
    c  <- fromMaybe (return . cstrConst . Cbool $ True)
                    (liftEither . expDeclToValExpr mm sortIdBool <$> mc)
    -- Filter the internal actions (to comply with the current TorXakis compiler).
    let os' = filter ((chanIdIstep /=) . chanid) os
    return $ ActOffer (Set.fromList os') c

toOffer :: ( MapsTo Text ChanId mm
           , MapsTo (Loc VarDeclE) VarId mm
           , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [FuncDefInfo]) mm
           , MapsTo (Loc VarDeclE) VarId mm
           , MapsTo FuncDefInfo FuncId mm
           , MapsTo FuncId (FuncDef VarId) mm )
        => mm -> OfferDecl -> CompilerM Offer
toOffer mm (OfferDecl cr cods) = do
    cId  <- lookupM (chanRefName cr) mm
            <!!> cr
    ofrs <- traverse (uncurry (toChanOffer mm))
                     (zip (chansorts cId) cods)
    -- | TODO: QUESTION: Here TorXakis assigns the empty list of SortId's to
    -- the EXIT channel. Why is TorXakis not using the expected SortId's? To
    -- comply with the curent compiler I have to erase the sort Ids.
    return $
        case name cId of
            "EXIT"  -> Offer (ChanId (name cId) (unid cId) []) ofrs                      
            _      -> Offer cId ofrs
    

toChanOffer :: ( MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [FuncDefInfo]) mm
               , MapsTo (Loc VarDeclE) VarId mm
               , MapsTo FuncDefInfo FuncId mm
               , MapsTo FuncId (FuncDef VarId) mm )
            => mm
            -> SortId -- ^ Expected sort id's the offer
            -> ChanOfferDecl
            -> CompilerM ChanOffer
toChanOffer mm _ (QuestD vd) =
    Quest  <$> mm .@ getLoc vd
toChanOffer mm eSid (ExclD ex) = liftEither $
    Exclam <$> expDeclToValExpr mm eSid ex


