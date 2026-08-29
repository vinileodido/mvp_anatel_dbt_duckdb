select *
from {{ ref('vw_indicadores') }}
where mesdatper < 202407
