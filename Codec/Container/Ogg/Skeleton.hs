--
-- Module      : Skeleton
-- Copyright   : (c) Conrad Parker 2006
-- License     : BSD-style
-- Maintainer  : conradp@cse.unsw.edu.au
-- Stability   : experimental
-- Portability : portable

module Codec.Container.Ogg.Skeleton (
  OggFishead (..),
  OggFisbone (..),
  emptyFishead,
  fisheadToPacket,
  fisboneToPacket,
  trackToFisbone,
  tracksToFisbones
) where

import qualified Data.ByteString.Lazy as L
import qualified Data.ByteString.Lazy.Char8 as C
import Data.List as List
import Data.Map as Map
import Data.Maybe
import Data.Word (Word32,Word64)
import Data.Ratio

import Codec.Container.Ogg.ByteFields
import Codec.Container.Ogg.ContentType
import Codec.Container.Ogg.Granulepos
import Codec.Container.Ogg.Granulerate
import Codec.Container.Ogg.Packet
import Codec.Container.Ogg.Timestamp
import Codec.Container.Ogg.Track

------------------------------------------------------------
-- Data
--

data OggFishead =
  OggFishead {
    fisheadPrestime :: Timestamp,
    fisheadBasetime :: Timestamp
  }

type OggMsgHeaders = Map.Map String String
    
data OggFisbone =
  OggFisbone {
    fisboneSerialno :: Word32,
    fisboneNHeaders :: Int,
    fisboneGranulerate :: Granulerate,
    fisboneStartgranule :: Word64,
    fisbonePreroll :: Word32,
    fisboneGranuleshift :: Int,
    fisboneMsgHeaders :: OggMsgHeaders
  }

------------------------------------------------------------
-- OggSkeleton constants
--

-- fisheadIdent = 'fishead\0'
fisheadIdent :: L.ByteString
fisheadIdent = L.pack [0x66, 0x69, 0x73, 0x68, 0x65, 0x61, 0x64, 0x00]

-- fisboneIdent = 'fisbone\0'
fisboneIdent :: L.ByteString
fisboneIdent = L.pack [0x66, 0x69, 0x73, 0x62, 0x6f, 0x6e, 0x65, 0x00]

-- Skeleton major version generated by this module
vMajor :: Int
vMajor = 3

-- Skeleton minor version generated by this module
vMinor :: Int
vMinor = 0 

-- Offset to message header fields generated by this module
fisboneMHOffset :: Int
fisboneMHOffset = 44

-- Padding after granuleshift, before message headers
fisbonePadding :: L.ByteString
fisbonePadding = L.concat $ List.map u8Fill [z, z, z]

-- Helpers
z :: Int
z = 0

zTimestamp :: Timestamp
zTimestamp = Timestamp (Just (0, 0))

emptyFishead :: OggFishead
emptyFishead = OggFishead zTimestamp zTimestamp

------------------------------------------------------------
-- fisheadToPacket
--

fisheadToPacket :: OggTrack -> OggFishead -> OggPacket
fisheadToPacket t f = up{packetBOS = True}
  where
    up = uncutPacket d t gp
    d = fisheadWrite f
    gp = Granulepos (Just 0)

fisheadWrite :: OggFishead -> L.ByteString
fisheadWrite (OggFishead p b) = newFisheadData
  where
    newFisheadData = L.concat [hData, pData, bData, uData]
    hData = L.concat [fisheadIdent, le16Fill vMajor, le16Fill vMinor]
    pData = timestampFill p
    bData = timestampFill b
    uData = L.concat $ List.map le64Fill [z, z]

timestampFill :: Timestamp -> L.ByteString
timestampFill (Timestamp Nothing) = L.concat $ List.map le64Fill [z, z]
timestampFill (Timestamp (Just (n, d))) = L.concat $ List.map le64Fill [n, d]

------------------------------------------------------------
-- fisboneToPacket
--

fisboneToPacket :: OggTrack -> OggFisbone -> OggPacket
fisboneToPacket t f = uncutPacket d t gp
  where
    d = fisboneWrite f
    gp = Granulepos (Just 0)

fisboneWrite :: OggFisbone -> L.ByteString
fisboneWrite (OggFisbone s n (Granulerate gr) sg pr gs mhdrs) = newFisboneData
  where
    newFisboneData = L.concat [hData, fData, tData]
    hData = L.concat [fisboneIdent, le32Fill fisboneMHOffset]
    fData = L.concat [sD, nD, grD, sgD, prD, gsD]
    tData = L.concat [fisbonePadding, mhdrsD]

    sD = le32Fill s
    nD = le32Fill n
    grD = L.concat $ List.map le64Fill [numerator gr, denominator gr]
    sgD = le64Fill sg
    prD = le32Fill pr
    gsD = u8Fill gs

    mhdrsD = C.pack $ concat $ List.map serializeMH (assocs mhdrs)

    serializeMH :: (String, String) -> String
    serializeMH (k, v) = k ++ ": " ++ v ++ "\r\n"

------------------------------------------------------------
-- trackToFisbone
--

-- | Create a list of OggFisbones from a list of OggTracks, not including
-- | any OggTracks with unknown ContentType or Granulerate
tracksToFisbones :: [OggTrack] -> [OggFisbone]
tracksToFisbones ts = Data.Maybe.mapMaybe trackToFisbone ts

-- | Create an OggFisbone from a given OggTrack
trackToFisbone :: OggTrack -> Maybe OggFisbone
trackToFisbone (OggTrack serialno (Just ctype) (Just gr) gs) =
  Just (OggFisbone serialno nheaders gr startgranule pr gsi mhdrs)
  where
    nheaders = headers ctype
    pr = fromIntegral $ preroll ctype
    startgranule = 0
    gsi = maybe 0 id gs -- A Granuleshift of None is represented by 0
    -- The first given content-type is the default to use in skeleton
    mhdrs = Map.singleton "Content-Type" (head $ mime ctype)

-- If the pattern match failed, ie. any of the Maybe values were Nothing,
-- then we can't produce a valid Fisbone for this
trackToFisbone _ = Nothing
