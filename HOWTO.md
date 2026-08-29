# HOWTO: executar e operar o projeto Anatel SMP

## Fluxo operacional recomendado

### 1) Instalar dependências

```bash
make install
```

### 2) Preparar o profile local

```bash
make init-profile
```

Esse passo cria `profiles.yml` apontando para o DuckDB local.

### 3) Baixar e carregar os dados oficiais

```bash
make collect
```

O que acontece:

- baixa os ZIPs/ODS/CSVs oficiais nas URLs do MVP original
- normaliza os nomes das colunas
- cria ou atualiza as tabelas brutas no schema `raw` do DuckDB
- grava o banco local `warehouse.duckdb`

### 4) Validar a conexão do dbt

```bash
make debug
```

O que observar:

- profile encontrado
- projeto dbt válido
- conexão com DuckDB OK

### 5) Rodar toda a transformação

```bash
make build
```

`make build` executa a coleta antes do build do dbt.

## Execução sem `make`

Se você quiser rodar tudo manualmente, use os comandos abaixo a partir da raiz do projeto.

### 1) Instalar dependências

```bash
pip install -r requirements.txt
```

### 2) Criar o profile local

```bash
cp profiles.yml.example profiles.yml
```

Se preferir, ajuste o `profiles.yml` manualmente para apontar para `warehouse.duckdb`.

### 3) Baixar e carregar os dados oficiais

```bash
python scripts/collect_anatel_mvp.py
```

### 4) Validar o dbt

```bash
DBT_PROFILES_DIR=. dbt debug --project-dir .
```

### 5) Construir os modelos

```bash
DBT_PROFILES_DIR=. dbt build --project-dir .
```

### 6) Gerar e servir a documentação

```bash
DBT_PROFILES_DIR=. dbt docs generate --project-dir .
DBT_PROFILES_DIR=. dbt docs serve --project-dir .
```

### 7) Abrir o DuckDB local

```bash
duckdb warehouse.duckdb
```

## Rotina diária


### Atualizar dados oficiais

Se as bases da Anatel ou do IBGE mudarem, rode:

```bash
make collect
make build
```

### Limpar ambiente local

Se você quiser recomeçar do zero, rode:

```bash
make clean
make init-profile
```

`make clean` apaga o `profiles.yml`, então ele precisa ser recriado antes da próxima execução.

## Ver o resultado

### Documentação dbt

```bash
make docs-generate
make docs-serve
```

### Shell do DuckDB

```bash
make duckdb-shell
```

Consultas úteis:

```sql
show schemas;
show tables from raw;
show tables from analytics;
select * from analytics.vw_erbs_br;
select * from analytics.vw_erbs_uf;
select * from analytics.vw_erbs_cid;
select * from analytics.vw_indicadores;
```

## O que cada modelo replica do MVP original

### `stg_indicadores_rqual`

Replica a etapa DuckDB que transforma o RQUAL em formato largo por indicador, calcula `MESDATPER`, `NUMERO_MEDIDAS`, `NUMERO_COLETORES` e `VALIDADE_ESTATISTICA`.

### `vw_erbs_br`

Replica a visão nacional do total de ERBs por prestadora e tecnologia.

### `vw_erbs_uf`

Replica a agregação por UF, código da UF e código de área.

### `vw_erbs_cid`

Replica a agregação por município e o flag de capital.

### `vw_indicadores`

Replica a visão final dos indicadores, cobrindo de `202407` até a última competência disponível no arquivo de dados (`202607`, julho de 2026).


## Evidências esperadas

No terminal, o fluxo saudável mostra mensagens como:

- `OK connection ok`
- `Downloaded ...`
- `Loaded raw table ...`
- `PASS ...`
- `Completed successfully`

## Como adaptar depois para dados novos

Se alguma coluna oficial mudar no futuro:

- mantenha a mesma estrutura de `raw`
- ajuste somente o script de coleta
- preserve os contratos dos modelos dbt, porque a camada analítica já está isolada
