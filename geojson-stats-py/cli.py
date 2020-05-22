import click
import fiona
from functools import partial
import pyproj
import requests
from shapely.geometry import shape
from shapely.ops import transform


def hectares_to_square_miles(hectares: float) -> float:
    return hectares * 0.00386102


def read_geojson_geometries(infile: str, do_reproject: bool) -> dict:
    reproject = partial(
        pyproj.transform, pyproj.Proj("epsg:4326"), pyproj.Proj("epsg:3857")
    )

    if infile.startswith("http"):
        features = requests.get(infile).json()["features"]
        if do_reproject:
            return [transform(reproject, shape(x["geometry"])) for x in features]
        else:
            return [shape(x["geometry"]) for x in features]
    else:
        with fiona.open(infile) as collection:
            if do_reproject:
                return [transform(reproject, shape(x["geometry"])) for x in collection]
            else:
                return [shape(x["geometry"]) for x in collection]


@click.group()
def cli():
    pass


@click.command()
@click.argument("infile")
@click.option("--metric/--imperial", default=True)
@click.option("--reproject/--no-reproject", default=True)
def area(infile: str, metric: bool, reproject: bool):
    geoms = read_geojson_geometries(infile, reproject)
    total_area_meters = sum([x.area for x in geoms])
    if metric:
        print(f"Area in metric units: {total_area_meters:.2f} square meters")
    else:
        print(
            f"Area in imperial units: {hectares_to_square_miles(area_to_hectares(total_area_meters))} square miles"
        )


@click.command()
@click.argument("infile")
@click.option("--metric/--imperial", default=True)
@click.option("--reproject/--no-reproject", default=True)
def perimeter(infile: str, metric: bool, reproject: bool):
    geoms = read_geojson_geometries(infile, reproject)
    total_perimeter_meters = sum([x.boundary.length for x in geoms])
    if metric:
        print(f"Perimeter in metric units: {total_perimeter_meters:.2f} meters")
    else:
        print(
            f"Perimeter in imperial units: {total_perimeter_meters * 1.09361:.2f} yards"
        )


cli.add_command(area)
cli.add_command(perimeter)

if __name__ == "__main__":
    cli()
