module Parse where

import Control.Alt
import Control.Lazy

import Data.Array.NonEmpty (toArray)
import Data.Either
import Data.Traversable
import Data.Tuple (Tuple, Tuple(..), fst)
import Data.String.Common (joinWith)
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
      Number  
    | Square
    | Curly

data Atom = Atom AtomType String
data Multiplicity = Zero | One | KleeneStar | KleenePlus 

data Schema = Schema AtomType Multiplicity
newtype Schemata = Schemata (Array Schema)

data CommandType = NewCommand | RenewCommand | NewEnvironment | RenewEnvironment

-- Basic command, with or without optional arguments
newtype Command = Command {ctype :: CommandType, cname :: String, atoms :: Array Atom}

-- Show functions
instance showAtom :: Show Atom where
    show (Atom Number str) = "[" <> str <> "]"
    show (Atom Square str) = "[" <> str <> "]"
    show (Atom Curly str) = "{" <> str <> "}"

instance showCommandType :: Show CommandType where
    show NewCommand = "\\newcommand"
    show RenewCommand = "\\renewcommand"
    show NewEnvironment = "\\newenvironment"
    show RenewEnvironment = "\\renewenvironment"

instance showCommand :: Show Command where
    show (Command { ctype: tp, cname: na, atoms: at }) = 
           show tp 
        <> "\\"
        <> na 
        <> (fold $ show <$> at)

-- Conversion functions
toCommandTypeName :: CommandType -> Tuple String CommandType
toCommandTypeName NewCommand = Tuple "\\newcommand" NewCommand
toCommandTypeName RenewCommand = Tuple "\\renewcommand" RenewCommand
toCommandTypeName NewEnvironment = Tuple "\\newenvironment" NewEnvironment
toCommandTypeName RenewEnvironment = Tuple "\\renewenvironment" RenewEnvironment

toSchemata :: CommandType -> Schemata
toSchemata NewCommand =     Schemata [Schema Number Zero,
                                      Schema Square KleeneStar,
                                      Schema Curly One]
toSchemata NewEnvironment = Schemata [Schema Number Zero,
                                      Schema Square KleeneStar,
                                      Schema Curly One]
toSchemata RenewCommand =            toSchemata NewCommand
toSchemata RenewEnvironment =        toSchemata NewEnvironment




-- Utility functions
word :: ParserS String
word = fromCharArray <$> many letter

concater :: forall a m. (Monoid m) => Parser a m -> Parser a m -> Parser a m 
concater a b = (<>) <$> a <*> b
infixl 4 concater as +-+

eat :: forall m. (Monoid m) => ParserS m -> ParserS m
eat = map (const mempty)

eatString :: String -> ParserS String
eatString = eat <<< string

matchDelims :: Char -> Char -> ParserS String
matchDelims ld rd = let
    lds = singleton ld
    rds = singleton rd
    noBrackets = fromCharArray <$> toArray <$> many1 (noneOf [ld, rd])
    matchInsideDelims ld_ rd_ = defer $ \_ ->
        (string lds +-+ (fold <$> many (matchInsideDelims ld_ rd_)) +-+ string rds)
        <|> noBrackets
    in defer $ \_ ->
            ((string lds *> (fold <$> many (matchInsideDelims ld rd))) <* string rds)

ignoreWhitespace :: ParserS String -> ParserS String
ignoreWhitespace ps = (whiteSpace *> ps) <* whiteSpace

matchAll :: forall a. ParserS a -> ParserS (Array a)
matchAll ps = let
    scanner = 
        defer $ \_ -> (ps <|> (anyChar *> scanner))
    in many scanner

-- Parsing by multiplicity
parseMultiplicity :: forall s a. Multiplicity -> (Parser s a -> Parser s (Array a))
parseMultiplicity Zero = map pure <<< try
parseMultiplicity One = map pure
parseMultiplicity KleeneStar = many
parseMultiplicity KleenePlus = \pr -> toArray <$> many1 pr

-- Atomic parsers
parseCommandName :: ParserS String
parseCommandName = let
    base = string "\\" *> word
    in      base 
        <|> ((string "{" *> base) <* string "}")

parseAtom :: AtomType -> ParserS Atom
parseAtom Number = Atom Number <$> (string "[" *> (singleton <$> digit)) <* string "]"
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
            psc NewCommand 
        <|> psc RenewCommand 
        <|> psc NewEnvironment 
        <|> psc RenewEnvironment

parseCommand :: ParserS Command
parseCommand = do
    Tuple _ ct <- parseSingleCommand
    na <- parseCommandName
    at <- join <$> (parseSchemata $ toSchemata ct)
    pure $ Command {ctype: ct, cname: na, atoms: at}

parseStyle :: ParserS (Array Command)
parseStyle = matchAll parseCommand

-- Run parsers (literal LaTeX syntax)
runParseCommand :: String -> Either ParseError Command
runParseCommand = flip runParser parseCommand

runParseStyle :: String -> Either ParseError (Array Command)
runParseStyle = flip runParser parseStyle

toFile :: String -> String
toFile = 
        either (const "") identity 
    <<< map (joinWith "\n") 
    <<< map (map show) 
    <<< runParseStyle