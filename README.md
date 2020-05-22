# cli-bake-off

This repo holds two CLIs, one using the [`click`](https://pypi.org/project/click/) library and one using [`optparse-applicative`](https://hackage.haskell.org/package/optparse-applicative).

The clis both follow basically this form:

```bash
$ geojson-stats-hs area

Usage: geojson-stats-hs area IN-FILE [--imperial]
  Calculate the area of all polygons in a geojson file
```

with an analogous command for `perimeter`.

The `optparse-applicative` CLI can be found [here](./geojson-stats). The `click` CLI can be found [here](./geojson-stats-py).

The python cli reprojects the input geojson from lat/long to web mercator before calculating areas and perimeters unless you tell it `--no-reproject`. The Haskell CLI doesn't know that projections exist at all because my geo-Haskell skills are at best second-tier.
