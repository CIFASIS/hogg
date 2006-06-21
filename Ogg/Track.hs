--
-- Module      : Track
-- Copyright   : (c) Conrad Parker 2006
-- License     : BSD-style
-- Maintainer  : conradp@cse.unsw.edu.au
-- Stability   : experimental
-- Portability : portable

module Ogg.Track (
  OggTrack (..),
  OggType,
  nullTrack,
  readCType
) where

import Data.Word (Word8, Word32)

------------------------------------------------------------
-- Data
--

data OggType = Vorbis | Speex | Theora

data OggTrack =
  OggTrack {
    trackSerialno :: Word32,
    trackType :: Maybe OggType
  }

------------------------------------------------------------
--
--

nullTrack :: OggTrack
nullTrack = OggTrack 0 Nothing

vorbisIdent :: [Word8]
vorbisIdent = [0x01, 0x76, 0x6f, 0x72, 0x62, 0x69, 0x73]

readCType :: [Word8] -> Maybe OggType
readCType (r1:r2:r3:r4:r5:r6:r7:_)
  | [r1,r2,r3,r4,r5,r6,r7] == vorbisIdent = Just Vorbis
  | otherwise = Nothing
readCType _ = Nothing

------------------------------------------------------------
-- Show
--

instance Show OggTrack where
  show (OggTrack serialno (Just t)) =
    "serialno " ++ show serialno ++ " " ++ show t

  show (OggTrack serialno Nothing) =
    "serialno " ++ show serialno ++ " (Unknown)"

instance Show OggType where
  show Vorbis = "Vorbis"
  show Speex  = "Speex"
  show Theora = "Theora"
