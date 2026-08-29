from __future__ import annotations

import argparse
import re
import shutil
import unicodedata
from pathlib import Path
from zipfile import ZipFile

import duckdb
import pandas as pd
import polars as pl
import requests

BASE_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = BASE_DIR / "data"
DOWNLOAD_DIR = DATA_DIR / "downloads"
EXTRACT_DIR = DATA_DIR / "extracted"
PARQUET_DIR = DATA_DIR / "parquet"
WAREHOUSE = BASE_DIR / "warehouse.duckdb"

URL_RQUAL_IND = "https://www.anatel.gov.br/dadosabertos/paineis_de_dados/qualidade/indicadores_rqual.zip"
URL_ESTACOES_SMP = "https://www.anatel.gov.br/dadosabertos/paineis_de_dados/outorga_e_licenciamento/estacoes_smp.zip"
URL_IBGE_MUNICIPIOS = "https://geoftp.ibge.gov.br/organizacao_do_territorio/estrutura_territorial/divisao_territorial/2023/DTB_2023.zip"
URL_ANATEL_AREAS_LOCAIS = "https://www.anatel.gov.br/dadosabertos/paineis_de_dados/areastarifarias/areaslocais.zip"

NULLS_INDICADORES = ["NÃO IDENTIFICADA"]
NULLS_ESTACOES = ["NÃO IDENTIFICADA", "#N/A", ","]


def normalize_text(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ASCII", "ignore").decode("ASCII")
    value = re.sub(r"[^A-Za-z0-9]+", "_", value).strip("_")
    return value.lower()


def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    rename_map: dict[str, str] = {}
    used: set[str] = set()
    for col in df.columns:
        candidate = normalize_text(str(col))
        base = candidate or "col"
        suffix = 2
        while candidate in used:
            candidate = f"{base}_{suffix}"
            suffix += 1
        used.add(candidate)
        rename_map[col] = candidate
    return df.rename(columns=rename_map)


def ensure_dirs() -> None:
    for path in (DATA_DIR, DOWNLOAD_DIR, EXTRACT_DIR, PARQUET_DIR):
        path.mkdir(parents=True, exist_ok=True)


def download_file(url: str, dest: Path, refresh: bool = False) -> Path:
    if dest.exists() and dest.stat().st_size > 0 and not refresh:
        print(f"cached download: {dest.name}")
        return dest

    print(f"downloading: {url}")
    with requests.get(url, stream=True, timeout=120) as response:
        response.raise_for_status()
        tmp = dest.with_suffix(dest.suffix + ".part")
        with tmp.open("wb") as fh:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    fh.write(chunk)
        tmp.replace(dest)
    print(f"saved: {dest}")
    return dest


def extract_member(zip_path: Path, member_name: str, dest: Path, refresh: bool = False) -> Path:
    if dest.exists() and dest.stat().st_size > 0 and not refresh:
        return dest

    dest.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(zip_path, "r") as zf:
        with zf.open(member_name) as source, dest.open("wb") as target:
            shutil.copyfileobj(source, target)
    return dest


def csv_to_parquet(
    csv_path: Path,
    parquet_path: Path,
    *,
    separator: str = ";",
    null_values: list[str] | None = None,
    infer_schema_length: int = 10000,
    refresh: bool = False,
) -> Path:
    if parquet_path.exists() and parquet_path.stat().st_size > 0 and not refresh:
        return parquet_path

    scan = pl.scan_csv(
        csv_path,
        separator=separator,
        encoding="utf8",
        has_header=True,
        infer_schema_length=infer_schema_length,
        null_values=null_values,
    )
    schema = scan.collect_schema()
    original_columns = [name for name, _ in schema.items()]
    exprs = [pl.col(col).alias(normalize_text(col)) for col in original_columns]
    scan.select(exprs).sink_parquet(parquet_path, compression="zstd", row_group_size=100_000)
    return parquet_path


def load_parquet_table(con: duckdb.DuckDBPyConnection, table_name: str, parquet_path: Path) -> None:
    con.execute("CREATE SCHEMA IF NOT EXISTS raw")
    con.execute(f"CREATE OR REPLACE TABLE raw.{table_name} AS SELECT * FROM read_parquet('{parquet_path.as_posix()}')")
    count = con.execute(f"SELECT count(*) FROM raw.{table_name}").fetchone()[0]
    print(f"loaded raw.{table_name}: {count} rows")


def load_dataframe_table(con: duckdb.DuckDBPyConnection, table_name: str, df: pd.DataFrame) -> None:
    con.execute("CREATE SCHEMA IF NOT EXISTS raw")
    con.register(f"tmp_{table_name}", df)
    con.execute(f"CREATE OR REPLACE TABLE raw.{table_name} AS SELECT * FROM tmp_{table_name}")
    con.unregister(f"tmp_{table_name}")
    count = con.execute(f"SELECT count(*) FROM raw.{table_name}").fetchone()[0]
    print(f"loaded raw.{table_name}: {count} rows")


def prepare_ibge(zip_path: Path, refresh: bool = False) -> pd.DataFrame:
    ods_path = EXTRACT_DIR / "DTB_2023" / "RELATORIO_DTB_BRASIL_MUNICIPIO.ods"
    extract_member(zip_path, "DTB_2023/RELATORIO_DTB_BRASIL_MUNICIPIO.ods", ods_path, refresh=refresh)
    df = pd.read_excel(ods_path, skiprows=6, engine="odf")
    df = normalize_columns(df)
    keep = [c for c in ["codigo_municipio_completo", "nome_municipio", "uf", "nome_uf"] if c in df.columns]
    df = df[keep].copy()
    if "uf" in df.columns and "nome_uf" in df.columns:
        df = df.rename(columns={"uf": "cod_uf", "nome_uf": "uf"})
    else:
        raise RuntimeError("IBGE ODS missing expected uf/nome_uf columns")
    required_order = ["codigo_municipio_completo", "nome_municipio", "cod_uf", "uf"]
    missing = [c for c in required_order if c not in df.columns]
    if missing:
        raise RuntimeError(f"IBGE ODS missing expected columns: {missing}")
    return df[required_order].copy()


def prepare_csv_raw(
    zip_path: Path,
    member_name: str,
    parquet_name: str,
    *,
    separator: str = ";",
    null_values: list[str] | None = None,
    infer_schema_length: int = 10000,
    refresh: bool = False,
) -> Path:
    csv_path = EXTRACT_DIR / member_name
    extract_member(zip_path, member_name, csv_path, refresh=refresh)
    parquet_path = PARQUET_DIR / parquet_name
    csv_to_parquet(
        csv_path,
        parquet_path,
        separator=separator,
        null_values=null_values,
        infer_schema_length=infer_schema_length,
        refresh=refresh,
    )
    return parquet_path


def collect(refresh: bool = False) -> None:
    ensure_dirs()

    downloads = {
        "indicadores_rqual.zip": download_file(URL_RQUAL_IND, DOWNLOAD_DIR / "indicadores_rqual.zip", refresh=refresh),
        "estacoes_smp.zip": download_file(URL_ESTACOES_SMP, DOWNLOAD_DIR / "estacoes_smp.zip", refresh=refresh),
        "DTB_2023.zip": download_file(URL_IBGE_MUNICIPIOS, DOWNLOAD_DIR / "DTB_2023.zip", refresh=refresh),
        "areaslocais.zip": download_file(URL_ANATEL_AREAS_LOCAIS, DOWNLOAD_DIR / "areaslocais.zip", refresh=refresh),
    }

    with ZipFile(downloads["indicadores_rqual.zip"], "r") as zf:
        indicadores_member = next(name for name in zf.namelist() if name.lower().endswith(".csv"))
    with ZipFile(downloads["estacoes_smp.zip"], "r") as zf:
        estacoes_member = next(name for name in zf.namelist() if name.lower().endswith(".csv"))
    with ZipFile(downloads["areaslocais.zip"], "r") as zf:
        areas_member = next(name for name in zf.namelist() if name.upper().endswith("CODIGOS_NACIONAIS_PGCN.CSV"))

    parquet_indicadores = prepare_csv_raw(
        downloads["indicadores_rqual.zip"],
        indicadores_member,
        "indicadores_rqual.parquet",
        separator=";",
        null_values=NULLS_INDICADORES,
        infer_schema_length=10000,
        refresh=refresh,
    )
    parquet_estacoes = prepare_csv_raw(
        downloads["estacoes_smp.zip"],
        estacoes_member,
        "estacoes_smp.parquet",
        separator=";",
        null_values=NULLS_ESTACOES,
        infer_schema_length=400000,
        refresh=refresh,
    )

    area_zip = downloads["areaslocais.zip"]
    area_csv_path = EXTRACT_DIR / areas_member
    extract_member(area_zip, areas_member, area_csv_path, refresh=refresh)
    df_areas = pd.read_csv(area_csv_path, sep=";")
    df_areas = normalize_columns(df_areas)
    area_keep = [
        c
        for c in [
            "co_municipio_ibge",
            "uf_cn",
            "nome_uf_cn",
            "no_municipio_uf",
            "cn",
            "dt_inicio_vigencia_cn",
            "dt_fim_vigencia_cn",
            "de_alteracao_regulamentar",
            "vigente",
        ]
        if c in df_areas.columns
    ]
    df_areas = df_areas[area_keep].copy()
    if df_areas.empty:
        raise RuntimeError("area code mapping is empty after normalization")

    ibge_df = prepare_ibge(downloads["DTB_2023.zip"], refresh=refresh)

    con = duckdb.connect(str(WAREHOUSE))
    con.execute("CREATE SCHEMA IF NOT EXISTS raw")
    load_parquet_table(con, "indicadores_rqual", parquet_indicadores)
    load_parquet_table(con, "estacoes_smp", parquet_estacoes)
    load_dataframe_table(con, "areas_locais", df_areas)
    load_dataframe_table(con, "ibge_municipios", ibge_df)
    con.close()

    print(f"warehouse ready: {WAREHOUSE}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Download and load the Anatel/IBGE MVP sources into DuckDB")
    parser.add_argument("--refresh", action="store_true", help="Redownload and reprocess every source")
    args = parser.parse_args()
    collect(refresh=args.refresh)


if __name__ == "__main__":
    main()
