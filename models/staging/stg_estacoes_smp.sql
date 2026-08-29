select
    cast(codigo_ibge as integer) as codigo_ibge,
    upper(trim(empresa_estacao)) as prestadora,
    cast(numero_estacao as varchar) as numero_estacao,
    upper(trim(geracao)) as geracao,
    * exclude (codigo_ibge, empresa_estacao, numero_estacao, geracao)
from {{ source('raw', 'estacoes_smp') }}
