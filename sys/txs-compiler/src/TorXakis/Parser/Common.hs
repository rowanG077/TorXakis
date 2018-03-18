module TorXakis.Parser.Common where

-- TODO: use selective imports.
import qualified Data.Text as T
import           Data.Text (Text)
import           Control.Monad.State (State, put, get)
import           Text.Parsec ( ParsecT, (<|>), many, label, eof, unexpected, sepBy
                             , getPosition, sourceLine, sourceColumn
                             , getState
                             , putState
                             )
import           Text.Parsec.Token
import           Text.Parsec.Char (lower, upper, oneOf, alphaNum, letter)
import           Control.Monad (void)
import           Control.Monad.Identity (Identity, runIdentity)

import           TorXakis.Parser.Data

type ParserInput = String

type TxsParser = ParsecT ParserInput St Identity

txsLangDef :: GenLanguageDef ParserInput St Identity
txsLangDef = LanguageDef
    { commentStart    = "{-"
    , commentEnd      = "-}"
    , commentLine     = "--"
    , nestedComments  = True
    , identStart      = letter
    , identLetter     = alphaNum <|> oneOf "_'"
    , opStart         = opLetter txsLangDef
    , opLetter        = oneOf ":!#$%&*+./<=>?@\\^|-~"
    , reservedNames   = ["TYPEDEF", "ENDDEF", "FUNCDEF"]
    , reservedOpNames = []
    , caseSensitive   = True
    }

txsTokenP :: GenTokenParser ParserInput St Identity
txsTokenP = makeTokenParser txsLangDef

txsIdentLetter :: TxsParser Char
txsIdentLetter = identLetter txsLangDef

txsSymbol :: String -> TxsParser ()
txsSymbol = void . symbol txsTokenP

txsLexeme :: TxsParser a -> TxsParser a
txsLexeme = lexeme txsTokenP

getMetadata :: TxsParser (Metadata t)
getMetadata = do
    i <- getNextId
    p <- getPosition
    return $ Metadata (sourceLine p) (sourceColumn p) (Loc i)

getNextId :: TxsParser Int
getNextId = do
    St i <- getState
    putState $ St (i + 1)
    return i

-- | Parser for upper case identifiers.
ucIdentifier :: String -> TxsParser Text
ucIdentifier what = identifierNE idStart
    where
      idStart = upper
                `label`
                (what ++ " must start with an uppercase character")

lcIdentifier :: TxsParser Text
lcIdentifier = identifierNE idStart
    where
      idStart = lower <|> oneOf "_"
                `label`
                "Identifiers must start with a lowercase character or '_'"

-- | Parser for non-empty identifiers.
identifierNE :: TxsParser Char -> TxsParser Text
identifierNE idStart = T.cons <$> idStart <*> idEnd
    where
      idEnd  = T.pack <$> many txsIdentLetter