with base as (
    select
        ib.uf,
        ib.cod_uf,
        al.cn as cod_area,
        upper(e.prestadora) as prestadora,
        e.geracao as tcn,
        count(distinct e.numero_estacao) as qtd_estac
    from {{ ref('stg_estacoes_smp') }} e
    join {{ ref('stg_ibge_municipios') }} ib
      on e.codigo_ibge = ib.cod_ibge
    left join {{ ref('stg_areas_locais') }} al
      on e.codigo_ibge = al.cod_ibge
    where e.geracao is not null
    group by 1,2,3,4,5
)
select
    uf,
    cod_uf,
    cod_area,
    prestadora,
    sum(case when tcn = '2G' then qtd_estac end) as tcn_2g,
    sum(case when tcn = '3G' then qtd_estac end) as tcn_3g,
    sum(case when tcn = '4G' then qtd_estac end) as tcn_4g,
    sum(case when tcn = '5G' then qtd_estac end) as tcn_5g
from base
group by 1,2,3,4
order by 1,2,4
