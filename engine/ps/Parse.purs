module Parse where

import Control.Alt
import Control.Lazy
import Control.Monad

import Data.Array (fromFoldable, toUnfoldable)
import Data.Array.NonEmpty (toArray)
import Data.Functor
import Data.List (List(..))
import Data.Traversable
import Data.Tuple (Tuple, Tuple(..), fst)
import Data.String.CodeUnits (fromCharArray, singleton)

import Parsing
import Parsing.Combinators (between, try)
import Parsing.Combinators.Array
import Parsing.String
import Parsing.String.Basic

import Prelude

-- Primitives
type ParserS = Parser String

-- Command schemas
data AtomType = 
      CommandName
    | RawParameter  
    | Square
    | Curly

data Atom = Atom AtomType String
data Multiplicity = Zero | One | KleeneStar | KleenePlus 

data Schema = Schema AtomType Multiplicity
newtype Schemata = Schemata (Array Schema)

data CommandType = Def | NewCommand | RenewCommand | NewEnvironment | RenewEnvironment

toCommandTypeName :: CommandType -> Tuple String CommandType
toCommandTypeName Def = Tuple "\\def" Def
toCommandTypeName NewCommand = Tuple "\\newcommand" NewCommand
toCommandTypeName RenewCommand = Tuple "\\renewcommand" RenewCommand
toCommandTypeName NewEnvironment = Tuple "\\newenvironment" NewEnvironment
toCommandTypeName RenewEnvironment = Tuple "\\renewenvironment" RenewEnvironment

toSchemata :: CommandType -> Schemata
toSchemata Def =            Schemata [Schema CommandName One,
                                      Schema Square KleeneStar, 
                                      Schema RawParameter KleeneStar, 
                                      Schema Curly One]
toSchemata NewCommand =     Schemata [Schema CommandName One,
                                      Schema Square Zero,
                                      Schema Square KleeneStar,
                                      Schema Curly One]
toSchemata NewEnvironment = Schemata [Schema CommandName One,
                                      Schema Square Zero,
                                      Schema Square KleeneStar,
                                      Schema Curly One]
toSchemata RenewCommand =            toSchemata NewCommand
toSchemata RenewEnvironment =        toSchemata NewEnvironment

-- Basic command, with or without optional arguments
newtype Command = Command {type :: CommandType, atoms :: Array Atom}

-- Utility functions
word :: ParserS String
word = fromCharArray <$> many letter

concater :: forall a. Parser a String -> Parser a String -> Parser a String
concater a b = (<>) <$> a <*> b
infixl 4 concater as +-+

matchDelims :: Char -> Char -> ParserS String
matchDelims ld rd = let
    lds = singleton ld
    rds = singleton rd
    noBrackets = fromCharArray <$> toArray <$> many1 (noneOf [ld, rd])
    matchInsideDelims ld_ rd_ = defer $ \_ ->
        (string lds +-+ (fold <$> many (matchInsideDelims ld_ rd_)) +-+ string rds)
        <|> noBrackets
    in defer $ \_ ->
            (string lds +-+ (fold <$> many (matchInsideDelims ld rd)) +-+ string rds)

-- Parsing by multiplicity
parseMultiplicity :: forall a. Multiplicity -> (ParserS a -> ParserS (Array a))
parseMultiplicity Zero = map pure <<< try
parseMultiplicity One = map pure
parseMultiplicity KleeneStar = many
parseMultiplicity KleenePlus = \pr -> toArray <$> many1 pr

-- Atomic parsers
parseAtom :: AtomType -> ParserS Atom
parseAtom CommandName =
    Atom CommandName <$> ((const "" <$> string "\\") +-+ word)
parseAtom RawParameter = 
    Atom RawParameter <$> ((const "" <$> string "#") +-+ word)
parseAtom Square = Atom Square <$> matchDelims '[' ']'
parseAtom Curly = Atom Curly <$> matchDelims '{' '}'

-- Schematic parsers
parseSchema :: Schema -> ParserS (Array Atom)
parseSchema (Schema at am) = parseMultiplicity am $ parseAtom at

parseSchemata :: Schemata -> ParserS (Array (Array Atom))
parseSchemata (Schemata scm) = sequence $ map parseSchema scm

-- Command parsers
parseSingleCommand :: ParserS (Tuple String CommandType)
parseSingleCommand = let
    psc cmd = Tuple <$> (string $ fst $ toCommandTypeName cmd) <*> pure cmd
    in 
            psc Def 
        <|> psc NewCommand 
        <|> psc RenewCommand 
        <|> psc NewEnvironment 
        <|> psc RenewEnvironment

parseCommand :: ParserS Command
parseCommand = do
    Tuple st ct <- parseSingleCommand
    at <- join <$> (parseSchemata $ toSchemata ct)
    pure $ Command {type: ct, atoms: at}
