{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeOperators              #-}
module TorXakis.Compiler.Data where

import           Control.Arrow             ((|||))
import           Control.Monad.Error.Class (MonadError, liftEither)
import           Control.Monad.State       (MonadState, StateT, get, put)
import           Data.Either.Utils         (maybeToEither)
import           Data.Map                  (Map)
import qualified Data.Map                  as Map
import           Data.Monoid               (Monoid, (<>))
import           Data.Text                 (Text)
import qualified Data.Text                 as T
import           GHC.Exts                  (IsList, Item, fromList, toList)
import           Prelude                   hiding (lookup)

import           CstrId                    (CstrId)
import           FuncDef                   (FuncDef)
import           FuncId                    (FuncId, funcsort)
import           SortId                    (SortId)
import           VarId                     (VarId)

import           TorXakis.Compiler.Error
import           TorXakis.Parser.Data      hiding (St, nextId)

-- | Single environment
newtype SEnv t = SEnv { fromSEnv :: t}

-- | Incremental environment, to allow the compiler to fill in the environment
-- in several passes.
data IEnv f0 f1 f2 f3 f4 f5 f6 = IEnv
    { sortIdT    :: f0
    , cstrIdT    :: f1
    , varSortIdT :: f2
    , varIdT     :: f3
    , varDeclT   :: f4
    , funcIdT    :: f5
    , funcDefT   :: f6
    }

emptyEnv :: IEnv () () () () () () ()
emptyEnv = IEnv () () () () () () ()

class HasSortIds e where
    -- | Find the `SortId` that corresponds to the given name. This assumes
    -- that sort names are unique.
    findSortId  :: e -> (Text, Loc t) -> Either Error SortId
    findSortIdM :: e -> (Text, Loc t) -> CompilerM SortId
    findSortIdM e t = liftEither $ findSortId e t
    getSortIdMap :: e -> Map Text SortId
    allSortIds :: e -> [SortId]
    allSortIds e = Map.elems $ getSortIdMap e

class HasCstrIds e where
    -- | Find the `CstrId` that correspond to the parser location of a
    -- constructor declaration.
    -- TODO: make this type-safe!
    -- Something like Map (Loc Var) VarId
    -- So that you cannot use this with the location of anything else.
    findCstrId :: e -> Loc CstrE -> Either Error CstrId
    findCstrIdM :: e -> Loc CstrE -> CompilerM CstrId
    findCstrIdM e i = liftEither $ findCstrId e i

-- | The environment has the @SortId@'s of the variable declarations.
class HasVarSortIds e where
    findVarDeclSortId :: e -> Loc VarDeclE -> Either Error SortId
    findVarDeclSortIdM :: e -> Loc VarDeclE -> CompilerM SortId
    findVarDeclSortIdM e l = liftEither $ findVarDeclSortId e l

class HasVarIds e where
    -- | Find the variable id that corresponds to the given parser location.
    --
    -- For now only field id's can define new `VarId`s.
    findVarId :: e -> Loc VarDeclE -> Either Error VarId
    findVarIdM :: e -> Loc VarDeclE -> CompilerM VarId
    findVarIdM e i = liftEither $ findVarId e i

class HasVarDecls e where
    -- | Find the variable declaration or function declaration that corresponds
    -- to parser-location of a variable reference.
    --
    -- An identifier "x" could refer to a function (for instance in the case of
    -- a constant), and that's why this function can return a 'FuncDecl' as
    -- well as a 'VarDecl'.
    --
    -- For now variables only occur in expressions.
    --
    -- TODO: rename this to something like 'findIdentDecl' or something like that
    findVarDecl :: e -> Loc VarRefE
                -> Either Error (Loc VarDeclE :| Loc FuncDeclE :| PredefName)
    -- findVarDecl :: e -> Loc VarRefE -> Either Error (Either (Loc VarDeclE) (Loc FuncDeclE))

    findFuncDecl :: e -> Loc VarRefE -> Either Error (Loc FuncDeclE :| PredefName)
    findFuncDecl e l =
        Left ||| const (Left err) ||| Right $ findVarDecl e l
       where
         err = Error
             { errorType = FunctionNotDefined
             , errorLoc  = getErrorLoc l
             , errorMsg  = "Could not function declaration."
             }

-- TODO determine the right kind of precedence.
infixr 5 :|
 -- TODO: you might want to replace the 'Either's by ':|'.
type (:|) = Either

class HasFuncIds e where
    -- | Find the function id that corresponds to the given parser location.
    --
    -- findFuncId :: e -> Loc FuncDeclE -> Either Error FuncId
    findFuncId :: e -> Loc FuncDeclE :| PredefName -> Either Error FuncId
    findFuncIdM :: e -> Loc FuncDeclE :| PredefName -> CompilerM FuncId
    findFuncIdM e i = liftEither $ findFuncId e i

class HasFuncDefs e where
    -- | Find the function definition that corresponds with a given function id.
    findFuncDef :: e -> FuncId -> Either Error (FuncDef VarId)
    getFuncDefT :: e -> Map FuncId (FuncDef VarId)

instance HasSortIds (IEnv (Map Text SortId) f1 f2 f3 f4 f5 f6) where
    findSortId IEnv{sortIdT = sm} (t, l) = maybeToEither err . Map.lookup t $ sm
        where err = Error
                  { errorType = UndefinedRef
                  , errorLoc = getErrorLoc l
                  , errorMsg = "Could not find sort " <> t
                  }

    getSortIdMap IEnv{sortIdT = sm} = sm

lookup :: (Ord a, Show a) => a -> Map a b -> Text -> Either Error b
lookup a ab what =  maybeToEither err . Map.lookup a $ ab
        where err = Error
                  { errorType = UndefinedRef
                  , errorLoc  = NoErrorLoc-- TODO: is it OK that we cannot give a location error here?
                  , errorMsg  = "Could not find " <> what
                  }

lookupM :: (Ord a, Show a) => a -> Map a b -> Text -> CompilerM b
lookupM a ab what = liftEither $ lookup a ab what

lookupWithLoc :: (Ord a, Show a, HasErrorLoc a) => a -> Map a b -> Text -> Either Error b
lookupWithLoc a ab what = maybeToEither err . Map.lookup a $ ab
    where err = Error
              { errorType = UndefinedRef
              , errorLoc  = getErrorLoc a
              , errorMsg  = "Could not find " <> what
              }

lookupWithLocM :: (Ord a, Show a, HasErrorLoc a) => a -> Map a b -> Text -> CompilerM b
lookupWithLocM a ab what = liftEither $ lookupWithLoc a ab what

instance HasCstrIds (IEnv f0 (Map (Loc CstrE) CstrId) f2 f3 f4 f5 f6) where
    findCstrId IEnv{cstrIdT = cm} i = lookupWithLoc i cm "constructor by parser location id "

instance HasVarSortIds (IEnv f0 f1 (Map (Loc VarDeclE) SortId) f3 f4 f5 f6) where
    -- TODO: remove duplication WRT to @instance HasVarSortIds (SEnv (Map (Loc VarDeclE) SortId))@
    findVarDeclSortId IEnv{varSortIdT = vsm} l = lookupWithLoc l vsm "sort of variable at location "

instance HasVarIds (IEnv f0 f1 f2 (Map (Loc VarDeclE) VarId) f4 f5 f6) where
    findVarId IEnv{varIdT = vm} i = lookupWithLoc i vm "variable by parser location id"

instance HasVarDecls (IEnv f0 f1 f2 f3 (Map (Loc VarRefE) (Loc VarDeclE :| Loc FuncDeclE :| PredefName)) f5 f6) where
    findVarDecl IEnv{varDeclT = vm} i = lookupWithLoc i vm "variable declaration by parser location id"

instance HasFuncIds (IEnv f0 f1 f2 f3 f4 (Map (Loc FuncDeclE :| PredefName) FuncId) f6) where
    findFuncId IEnv {funcIdT = fm} i = lookupWithLoc i fm "function id by parser location id"

findFuncSortIdByLoc :: HasFuncIds e => e -> Loc FuncDeclE :| PredefName -> Either Error SortId
findFuncSortIdByLoc e l = funcsort <$> findFuncId e l

instance HasFuncDefs (IEnv f0 f1 f2 f3 f4 f5 (Map FuncId (FuncDef VarId))) where
    findFuncDef IEnv{funcDefT = fm} = findFuncDef (SEnv fm)
    getFuncDefT IEnv{funcDefT = fm} = getFuncDefT (SEnv fm)

instance HasFuncDefs (SEnv (Map FuncId (FuncDef VarId))) where
    findFuncDef (SEnv fm) i = lookup i fm (T.pack . show $ i )
    getFuncDefT (SEnv fm) = fm

instance Ord a => Monoid (SEnv (Map a b)) where
    mempty = SEnv Map.empty
    SEnv fm0 `mappend` SEnv fm1 = SEnv (fm0 `mappend` fm1)

instance Ord a => IsList (SEnv (Map a b)) where
    type Item (SEnv (Map a b)) = (a, b)

    fromList = SEnv . fromList
    toList   = toList . fromSEnv

isMemberOf :: Ord a => a -> SEnv (Map a b) -> Bool
isMemberOf a (SEnv ab) = Map.member a ab

instance HasVarSortIds (SEnv (Map (Loc VarDeclE) SortId)) where
    findVarDeclSortId (SEnv vsm) l = lookupWithLoc l vsm "sort of variable at location "

-- | Name of the pre-defined functions. We're using the name of the function as unique identifier.
--
newtype PredefName = PredefName { predefName :: Text } deriving (Eq, Ord, Show)

newtype St = St { nextId :: Int } deriving (Eq, Show)

newState :: St
-- TODO: document why '1000' was chosen.
newState = St 1000

newtype CompilerM a = CompilerM { runCompiler :: StateT St (Either Error) a }
    deriving (Functor, Applicative, Monad, MonadState St, MonadError Error)

getNextId :: CompilerM Int
getNextId = do
    i <- nextId <$> get
    put (St $ i + 1)
    return i