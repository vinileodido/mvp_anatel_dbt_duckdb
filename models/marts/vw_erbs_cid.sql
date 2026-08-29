with base as (
    select
        ib.uf,
        ib.cod_uf,
        al.cn as cod_area,
        ib.cod_ibge,
        ib.municipio as cidade,
        case
            when ib.cod_ibge in (
                1100205,1302603,1200401,5002704,1600303,
                5300108,1400100,5103403,1721000,3550308,
                2211001,3304557,1501402,5208707,2927408,
                4205407,2111300,2704302,4314902,4106902,
                3106200,2304400,2611606,2507507,2800308,
                2408102,3205309
            ) then 'SIM' else 'NÃO'
        end as capital,
        upper(e.prestadora) as prestadora,
        e.geracao as tcn,
        count(distinct e.numero_estacao) as qtd_estac
    from {{ ref('stg_estacoes_smp') }} e
    join {{ ref('stg_ibge_municipios') }} ib
      on e.codigo_ibge = ib.cod_ibge
    left join {{ ref('stg_areas_locais') }} al
      on e.codigo_ibge = al.cod_ibge
    where e.geracao is not null
    group by 1,2,3,4,5,6,7,8
)
select
    uf,
    cod_uf,
    cod_area,
    cod_ibge,
    cidade,
    capital,
    prestadora,
    sum(case when tcn = '2G' then qtd_estac end) as tcn_2g,
    sum(case when tcn = '3G' then qtd_estac end) as tcn_3g,
    sum(case when tcn = '4G' then qtd_estac end) as tcn_4g,
    sum(case when tcn = '5G' then qtd_estac end) as tcn_5g
from base
group by 1,2,3,4,5,6,7
order by 1,2,4,7
