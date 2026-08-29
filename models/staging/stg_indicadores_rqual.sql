with source_data as (
    select
        cast(ano as integer) as ano,
        cast(mes as integer) as mes,
        cast(codigo_ibge as integer) as codigo_ibge,
        upper(trim(prestadora)) as prestadora,
        trim(uf) as uf,
        trim(municipio) as municipio,
        trim(servico) as servico,
        trim(tipo) as tipo,
        upper(trim(indicador)) as indicador,
        try_cast(replace(resultado, ',', '.') as double) as resultado,
        try_cast(numero_de_medidas as integer) as numero_de_medidas,
        try_cast(numero_de_coletores as integer) as numero_de_coletores
    from {{ source('raw', 'indicadores_rqual') }}
    where servico = 'Telefonia Móvel'
      and tipo = 'Indicador IQS'
),
wide as (
    select
        cast(concat(cast(ano as varchar), lpad(cast(mes as varchar), 2, '0')) as integer) as mesdatper,
        ano,
        mes,
        replace(servico, 'Telefonia Móvel', 'SMP') as servico,
        prestadora,
        codigo_ibge,
        uf,
        municipio,
        max(case when indicador = 'IND1' then resultado end) as ind1,
        max(case when indicador = 'IND2' then resultado end) as ind2,
        max(case when indicador = 'IND3' then resultado end) as ind3,
        max(case when indicador = 'IND4' then resultado end) as ind4,
        max(case when indicador = 'IND5' then resultado end) as ind5,
        max(case when indicador = 'IND6' then resultado end) as ind6,
        max(case when indicador = 'IND7' then resultado end) as ind7,
        max(case when indicador = 'IND8' then resultado end) as ind8,
        max(case when indicador = 'IND4' then numero_de_medidas end) as ind4_medidas,
        max(case when indicador = 'IND5' then numero_de_medidas end) as ind5_medidas,
        max(case when indicador = 'IND6' then numero_de_medidas end) as ind6_medidas,
        max(case when indicador = 'IND7' then numero_de_medidas end) as ind7_medidas,
        max(case when indicador = 'IND4' then numero_de_coletores end) as ind4_coletores,
        max(case when indicador = 'IND5' then numero_de_coletores end) as ind5_coletores,
        max(case when indicador = 'IND6' then numero_de_coletores end) as ind6_coletores,
        max(case when indicador = 'IND7' then numero_de_coletores end) as ind7_coletores
    from source_data
    group by 1,2,3,4,5,6,7,8
)
select
    mesdatper,
    ano,
    mes,
    servico,
    prestadora,
    codigo_ibge,
    uf,
    municipio,
    ind1,
    ind2,
    ind3,
    ind4,
    ind5,
    ind6,
    ind7,
    ind8,
    least(ind4_medidas, ind5_medidas, ind6_medidas, ind7_medidas) as numero_medidas,
    least(ind4_coletores, ind5_coletores, ind6_coletores, ind7_coletores) as numero_coletores,
    case when least(ind4_medidas, ind5_medidas, ind6_medidas, ind7_medidas) >= 109 then 1 else 0 end as validade_estatistica
from wide
