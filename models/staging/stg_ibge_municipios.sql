select
    cast(codigo_municipio_completo as integer) as cod_ibge,
    trim(nome_municipio) as municipio,
    cast(cod_uf as integer) as cod_uf,
    trim(uf) as uf
from {{ source('raw', 'ibge_municipios') }}
