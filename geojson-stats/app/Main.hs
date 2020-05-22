module Main where

import           Data.Aeson              hiding ( Options )
import qualified Data.ByteString.Lazy          as BS
import           Data.Foldable                  ( fold )
import           Data.Geospatial
import           Data.LinearRing
import           Data.Maybe                     ( fromMaybe )
import           Data.Monoid                    ( Sum(..) )
import qualified Data.Sequence                 as Seq
import           Data.Sequence                  ( Seq(..)
                                                , (|>)
                                                )
import           Options.Applicative     hiding ( empty )
import           GHC.Generics                   ( Generic )

data Units = Metric | Imperial

data Options = Options
  { inFile :: String
  , units :: Units }

data Command =
  Area Options
  | Perimeter Options

newtype Properties = Properties { id :: String } deriving (Eq, Generic)
instance FromJSON Properties


type Polygon = Seq.Seq (LinearRing GeoPositionWithoutCRS)

linearRingArea :: LinearRing GeoPositionWithoutCRS -> Maybe (Sum Double)
linearRingArea ring =
        let points = toSeq ring
            tups =
                            points
                                    >>= (\case
                                                GeoPointXY (PointXY x y) ->
                                                        Seq.singleton (x, y)
                                                _ -> Seq.empty
                                        )
            area nonEmpty =
                            let
                                    (x :<| xs, y :<| ys) = Seq.unzip nonEmpty
                                    allXs                = x :<| xs
                                    allYs                = y :<| ys
                                    wrappedYs            = ys |> y
                                    wrappedXs            = xs |> x
                                    sumWrappedY = sum (Seq.zipWith (*) allXs wrappedYs)
                                    sumWrappedX = sum (Seq.zipWith (*) wrappedXs allYs)
                            in
                                    0.5 * abs (sumWrappedX - sumWrappedY)
        in  if Seq.null tups then Nothing else Just . Sum $ area tups


polyArea :: Polygon -> Maybe (Sum Double)
polyArea (h :<| t) =
        (-)
                <$> linearRingArea h
                <*> (fold (linearRingArea <$> t) <|> Just (Sum 0))

geoArea :: GeospatialGeometry -> Maybe (Sum Double)
geoArea (MultiPolygon geoMultiPolygon) =
        fold $ polyArea <$> _unGeoMultiPolygon geoMultiPolygon
geoArea _ = Nothing

area :: Seq.Seq (GeoFeature a) -> Sum Double
area features =
        let geoms = _geometry <$> features
            areas = geoArea <$> geoms
        in  fromMaybe (Sum 0) $ fold areas

optParser :: Parser Options
optParser = Options <$> argument str (metavar "IN-FILE") <*> flag
        Metric
        Imperial
        (long "imperial" <> help "Use imperial units instead of metric")

areaOptions :: Parser Command
areaOptions = Area <$> optParser

perimeterOptions :: Parser Command
perimeterOptions = Perimeter <$> optParser

cmdParser :: Parser Command
cmdParser =
        subparser
                $  command
                           "area"
                           (info
                                   areaOptions
                                   (progDesc
                                           "Calculate the area of all polygons in a geojson file"
                                   )
                           )
                <> command
                           "perimeter"
                           (info
                                   perimeterOptions
                                   (progDesc
                                           "Calculate the perimeter of all polygons in a geojson file"
                                   )
                           )

readJson :: String -> IO (Maybe (GeoFeatureCollection Properties))
readJson s = decode <$> BS.readFile s

main :: IO ()
main = do
        parsed <- execParser
                (info
                        cmdParser
                        (progDesc
                                "Calculate area or perimeter of polygons in a geojson file"
                        )
                )
        case parsed of
                Area opts -> do
                        collection <- readJson . inFile $ opts
                        print
                                $  "Features area: "
                                ++ (   show
                                   .   sum
                                   $   area
                                   .   _geofeatures
                                   <$> collection
                                   )
                _ -> print "Gonna do perimeter"
