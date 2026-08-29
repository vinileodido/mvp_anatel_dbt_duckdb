# MVP Anatel SMP em dbt + DuckDB

Refatoração do MVP original para uma execução local, versionável e reproduzível com **dbt Core** + **DuckDB**.

Este projeto replica o fluxo do notebook original, mas sem Databricks e sem Streamlit:

- coleta dos dados oficiais por URL
- normalização e carga em DuckDB
- transformação analítica em dbt
- visões finais por Brasil, UF, município e indicadores RQUAL

## Fontes oficiais usadas no MVP original

- Indicadores RQUAL: https://www.anatel.gov.br/dadosabertos/paineis_de_dados/qualidade/indicadores_rqual.zip
- Estações SMP: https://www.anatel.gov.br/dadosabertos/paineis_de_dados/outorga_e_licenciamento/estacoes_smp.zip
- Municípios IBGE: https://geoftp.ibge.gov.br/organizacao_do_territorio/estrutura_territorial/divisao_territorial/2023/DTB_2023.zip
- Áreas locais Anatel: https://www.anatel.gov.br/dadosabertos/paineis_de_dados/areastarifarias/areaslocais.zip

## O que este projeto faz

1. baixa os arquivos ZIP/ODS/CSV nas URLs oficiais
2. normaliza e carrega os dados brutos em um DuckDB local
3. executa o staging em dbt
4. replica as agregações do DuckDB original em modelos dbt
5. deixa o resultado pronto para consulta SQL e documentação dbt

## Changelog: do MVP original para esta versão

### No notebook original

- downloads manuais e leitura direta das bases no Databricks
- transformação analítica concentrada no notebook
- entrega acoplada a uma interface Streamlit

### Nesta versão

- coleta automatizada via URLs oficiais da Anatel e do IBGE
- carga bruta em `raw` dentro de um DuckDB local
- staging dbt com as mesmas regras centrais do notebook
- marts dbt para Brasil, UF, município e indicadores RQUAL
- consumo por SQL local e documentação dbt

### Mapeamento principal

- `databricks_mvp_anatel_smp.ipynb` -> `scripts/collect_anatel_mvp.py` + `models/`
- pivot RQUAL, `NUMERO_MEDIDAS`, `NUMERO_COLETORES` e `VALIDADE_ESTATISTICA` -> `models/staging/stg_indicadores_rqual.sql`
- agregações de ERB por país, UF e município -> `models/marts/vw_erbs_br.sql`, `models/marts/vw_erbs_uf.sql`, `models/marts/vw_erbs_cid.sql`
- visão final de indicadores -> `models/marts/vw_indicadores.sql`

## Release notes

- troca o notebook e a interface Streamlit por um fluxo local com dbt + DuckDB
- coleta as bases oficiais diretamente das URLs públicas da Anatel e do IBGE
- grava os dados brutos no schema `raw` e aplica a modelagem analítica em `models/staging` e `models/marts`
- replica os principais resultados do MVP original:
  - indicadores RQUAL em formato largo
  - ERBs por Brasil, UF e município
  - flag de capital por município
- operação principal:
  - `make collect` para atualizar a carga bruta
  - `make debug` para validar o profile/conexão
  - `make build` para executar coleta + dbt


## Stack

- dbt Core
- dbt-duckdb
- DuckDB local em arquivo
- Python para coleta/normalização inicial
- `Makefile` para comandos curtos

## Estrutura

```text
.
├── Makefile
├── README.md
├── HOWTO.md
├── dbt_project.yml
├── profiles.yml.example
├── requirements.txt
├── .gitignore
├── scripts/
│   └── collect_anatel_mvp.py
└── models/
    ├── sources.yml
    ├── schema.yml
    ├── staging/
    │   ├── stg_areas_locais.sql
    │   ├── stg_estacoes_smp.sql
    │   ├── stg_ibge_municipios.sql
    │   └── stg_indicadores_rqual.sql
    └── marts/
        ├── vw_erbs_br.sql
        ├── vw_erbs_cid.sql
        ├── vw_erbs_uf.sql
        └── vw_indicadores.sql
```

## Modelagem portada

### Camada raw

O script de coleta carrega as tabelas brutas no schema `raw` do DuckDB:

- `raw.ibge_municipios`
- `raw.areas_locais`
- `raw.estacoes_smp`
- `raw.indicadores_rqual`

### Staging

- `stg_ibge_municipios`: dimensão municipal normalizada
- `stg_areas_locais`: código de área por município
- `stg_estacoes_smp`: base de ERBs preparada para agregação
- `stg_indicadores_rqual`: transformação do formato longo dos indicadores em formato analítico largo

### Marts

- `vw_erbs_br`: agregação nacional por prestadora e tecnologia
- `vw_erbs_uf`: agregação por UF
- `vw_erbs_cid`: agregação por município, com flag de capital
- `vw_indicadores`: visão final de indicadores RQUAL enriquecida com a dimensão geográfica

## Requisitos

- Python 3.12+
- `pip`
- `make`

## Instalação

```bash
make install
```

## Profile local

O projeto usa um `profiles.yml` local e não versiona esse arquivo.

Crie com:

```bash
make init-profile
```

O arquivo de exemplo aponta para o banco local:

```yaml
path: "warehouse.duckdb"
```

## Operação recomendada

Fluxo normal:

1. `make init-profile`
2. `make collect`
3. `make debug`
4. `make build`

Regras úteis:

- `make build` executa a coleta antes do build do dbt
- `make collect` pode ser usado sozinho quando só os dados oficiais mudarem
- `make clean` remove `profiles.yml`, `warehouse.duckdb`, `data/`, `target/`, `logs/` e `dbt_packages/`
- após `make clean`, rode `make init-profile` novamente antes de executar o projeto

## Com `make` vs sem `make`

| Etapa | Com `make` | Sem `make` |
|---|---|---|
| Instalar dependências | `make install` | `pip install -r requirements.txt` |
| Criar o profile | `make init-profile` | `cp profiles.yml.example profiles.yml` |
| Coletar e carregar dados | `make collect` | `python scripts/collect_anatel_mvp.py` |
| Validar dbt | `make debug` | `DBT_PROFILES_DIR=. dbt debug --project-dir .` |
| Construir modelos | `make build` | `DBT_PROFILES_DIR=. dbt build --project-dir .` |
| Gerar docs | `make docs-generate` | `DBT_PROFILES_DIR=. dbt docs generate --project-dir .` |
| Servir docs | `make docs-serve` | `DBT_PROFILES_DIR=. dbt docs serve --project-dir .` |
| Abrir DuckDB | `make duckdb-shell` | `duckdb warehouse.duckdb` |

Observação:

- `make build` já executa a coleta antes do build
- `make clean` remove os artefatos locais e exige recriar o `profiles.yml`



## Visualização

Depois do build, você pode consultar os modelos diretamente no DuckDB local:

```sql
select * from analytics.vw_erbs_br;
select * from analytics.vw_erbs_uf;
select * from analytics.vw_erbs_cid;
select * from analytics.vw_indicadores;
```


## GitHub-ready

Arquivos versionáveis:

- modelos dbt
- script de coleta
- `Makefile`
- `README.md`
- `HOWTO.md`
- `dbt_project.yml`
- `profiles.yml.example`
- `requirements.txt`
- `.gitignore`

Arquivos locais e ignorados:

- `profiles.yml`
- `warehouse.duckdb`
- `data/`
- `target/`
- `logs/`
- `dbt_packages/`
