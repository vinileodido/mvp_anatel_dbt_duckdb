with source as (
    select
        cast(co_municipio_ibge as integer) as cod_ibge,
        cast(cn as integer) as cn,
        upper(trim(vigente)) as flag_vigente,
        try_strptime(dt_inicio_vigencia_cn, '%d/%m/%Y') as dt_inicio_vigencia_cn
    from {{ source('raw', 'areas_locais') }}
),
ranked as (
    select
        cod_ibge,
        cn,
        row_number() over (
            partition by cod_ibge
            order by dt_inicio_vigencia_cn desc nulls last, cn desc
        ) as rn
    from source
    where flag_vigente = 'SIM'
)

select
    cod_ibge,
    cn
from ranked
where rn = 1
