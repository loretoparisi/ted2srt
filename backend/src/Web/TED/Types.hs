{-# LANGUAGE DuplicateRecordFields #-}

module Web.TED.Types
  ( Talk (..)
  , SearchTalk (..)
  , Image (..)
  , Language (..)
  , Tag (..)
  , Theme (..)
  , TM (..)
  , Speaker (..)
  , Sp (..)
  , Transcript(..)
  , transcriptToText
  ) where


import           Control.Applicative ((<$>), (<*>))
import           Control.Monad       (liftM, mzero)
import           Data.Aeson
import           Data.Aeson.Types    (Options (..), defaultOptions, parseMaybe)
import qualified Data.HashMap.Strict as HM
import           Data.List           (sort)
import           Data.Maybe          (fromMaybe)
import           Data.Text           (Text)
import qualified Data.Text           as T
import           Data.Time           (UTCTime)
import           Data.Time.Format    (defaultTimeLocale, parseTimeM)
import qualified Data.Vector         as V
import           GHC.Generics        (Generic)
import           RIO

newtype TEDTime = TEDTime { fromTEDTime :: UTCTime }

instance FromJSON TEDTime where
    parseJSON = withText "TEDTime" $ \t ->
        case parseTimeM True defaultTimeLocale timeFormat (T.unpack t) of
            Just time -> return $ TEDTime time
            Nothing   -> fail $ "Failed to parse TED time: " ++ T.unpack t
      where
        timeFormat = "%Y-%m-%d %H:%M:%S"

data Image = Image
    { small  :: Text
    , medium :: Text
    } deriving (Generic, Show)
instance FromJSON Image
instance ToJSON Image

newtype TEDImage = TEDImage { fromTEDImage :: Image }

-- | "images": [{ "image": { "size": , "url": } }]
instance FromJSON TEDImage where
    parseJSON (Array v) =
        let urls = V.map parseImage v
        in  TEDImage <$> (Image <$> (urls V.! 1) <*> (urls V.! 2))
      where
        parseImage (Object o) =
            o .: "image" >>= (.: "url")
        parseImage _ = mzero
    parseJSON _ = mzero

data Language = Language
    { languageName :: Text
    , languageCode :: Text
    } deriving (Show)
instance FromJSON Language where
    parseJSON (Object v) =
        Language <$> v .: "name"
                 <*> v .: "code"
    parseJSON _          = mzero
instance ToJSON Language where
    toJSON Language{..} =
        object [ "name" .= languageName
               , "code" .= languageCode
               ]
newtype Languages = Languages { fromLanguages :: [Language] }

-- | "languages": { "en": { "name": "English", "native": true } }
instance FromJSON Languages where
    parseJSON (Object v) =
        let langCode = HM.keys v
            langName = flip map (HM.elems v) $ \lang ->
                fromMaybe (error "Failed to parse languages")
                          (parseMaybe parseLanguage lang)
        in  return $ Languages $ map (uncurry Language) $ sort $ zip langName langCode
      where
        parseLanguage (Object o) = o .: "name"
        parseLanguage _          = mzero
    parseJSON _ = mzero

data Tag = Tag
    { tag           :: Text
    } deriving (Generic, Show)
instance FromJSON Tag

data Theme = Theme
    { theme         :: TM
    } deriving (Generic, Show)
instance FromJSON Theme

data TM = TM
    { tm_id   :: Int
    , tm_name :: Text
    } deriving (Generic, Show)
instance FromJSON TM where
    parseJSON = genericParseJSON defaultOptions { fieldLabelModifier = drop 3 }

data Speaker = Speaker
    { speaker       :: Sp
    } deriving (Generic, Show)
instance FromJSON Speaker

data Sp = Sp
    { sp_id   :: Int
    , sp_name :: Text
    } deriving (Generic, Show)
instance FromJSON Sp where
    parseJSON = genericParseJSON defaultOptions { fieldLabelModifier = drop 3 }

-- | Some talks (performance) has no language infomation e.g. 581.
data Talk = Talk
    { id          :: Int
    , name        :: Text
    , description :: Text
    , slug        :: Text
    , recordedAt  :: UTCTime
    , publishedAt :: UTCTime
    , updatedAt   :: UTCTime
    , viewedCount :: Int
    , images      :: Image
    , media       :: Value
    , languages   :: [Language]
    , tags        :: [Tag]
    , themes      :: [Theme]
    , speakers    :: [Speaker]
    } deriving (Generic, Show)
instance FromJSON Talk where
    parseJSON (Object v) =
        Talk <$> v .: "id"
             <*> v .: "name"
             <*> v .: "description"
             <*> v .: "slug"
             <*> liftM fromTEDTime (v .: "recorded_at")
             <*> liftM fromTEDTime (v .: "published_at")
             <*> liftM fromTEDTime (v .: "updated_at")
             <*> v .: "viewed_count"
             <*> liftM fromTEDImage (v .: "images")
             <*> v .: "media"
             <*> liftM fromLanguages (v .: "languages")
             <*> v .: "tags"
             <*> v .: "themes"
             <*> v .: "speakers"
    parseJSON _          = mzero

data SearchTalk = SearchTalk
  { id          :: Int
  , name        :: Text
  , description :: Text
  , slug        :: Text
  , recordedAt  :: Text
  , publishedAt :: Text
  , updatedAt   :: Text
  } deriving (Generic, Show)
instance FromJSON SearchTalk where
  parseJSON = genericParseJSON defaultOptions { fieldLabelModifier = camelTo2 '_' }

data Cue = Cue
    { time :: Int
    , text :: Text
    } deriving (Generic, Show)
instance FromJSON Cue

data Paragraph = Paragraph
    { cues :: [Cue]
    } deriving (Generic, Show)
instance FromJSON Paragraph

data Transcript = Transcript
    { paragraphs :: [Paragraph]
    } deriving (Generic, Show)
instance FromJSON Transcript

transcriptToText :: Transcript -> Text
transcriptToText (Transcript ps) =
    T.intercalate "\n" $ map (
      \(Paragraph cues) -> T.intercalate " " $ map (T.replace "\n" " " . text) cues) ps
