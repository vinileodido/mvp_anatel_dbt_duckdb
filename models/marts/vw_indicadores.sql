{{ config(materialized='table') }}

with max_periodo as (
    select max(mesdatper) as max_mesdatper
    from {{ ref('stg_indicadores_rqual') }}
)

select
    i.mesdatper,
    i.ano,
    i.mes,
    i.servico,
    i.prestadora,
    al.cn,
    ib.cod_ibge,
    ib.uf,
    ib.cod_uf,
    ib.municipio as cidade,
    i.ind1,
    i.ind2,
    i.ind3,
    i.ind4,
    i.ind5,
    i.ind6,
    i.ind7,
    i.ind8,
    i.numero_medidas,
    i.numero_coletores,
    i.validade_estatistica
from {{ ref('stg_indicadores_rqual') }} i
join {{ ref('stg_ibge_municipios') }} ib
  on i.codigo_ibge = ib.cod_ibge
left join {{ ref('stg_areas_locais') }} al
  on i.codigo_ibge = al.cod_ibge
cross join max_periodo p
where i.mesdatper >= 202407
  and i.mesdatper <= p.max_mesdatper
order by i.mesdatper, ib.uf, ib.cod_ibge, i.prestadora
