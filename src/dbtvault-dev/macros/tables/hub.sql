{%- macro hub(src_pk, src_nk, src_ldts, src_source, source_model) -%}

    {{- adapter.dispatch('hub', packages = ['dbtvault'])(src_pk=src_pk, src_nk=src_nk,
                                                         src_ldts=src_ldts, src_source=src_source,
                                                         source_model=source_model) -}}

{%- endmacro -%}

{%- macro snowflake__hub(src_pk, src_nk, src_ldts, src_source, source_model) -%}

{%- set source_cols = dbtvault.expand_column_list(columns=[src_pk, src_nk, src_ldts, src_source]) -%}

{{ dbtvault.prepend_generated_by() }}

{{ 'WITH ' -}}

{%- if not (source_model is iterable and source_model is not string) -%}
    {%- set source_model = [source_model] -%}
{%- endif -%}

{%- for src in source_model -%}
source_data_{{ loop.index|string }} AS (
    SELECT *
    FROM {{ ref(src) }}
    {%- if dbtvault.is_vault_insert_by_period() or model.config.materialized == 'vault_insert_by_period' %}
    WHERE __PERIOD_FILTER__
    {%- endif %}
),
rank_{{ loop.index|string }} AS (
    SELECT {{ source_cols | join(', ') }},
           ROW_NUMBER() OVER(
               PARTITION BY {{ src_pk }}
               ORDER BY {{ src_ldts }} ASC
           ) AS row_number
    FROM source_data_{{ loop.index|string }}
),
stage_{{ loop.index|string }} AS (
    SELECT DISTINCT {{ source_cols | join(', ') }}
    FROM rank_{{ loop.index|string }}
    WHERE row_number = 1
),
{% endfor -%}

stage_union AS (
    {%- for src in source_model %}
    SELECT * FROM stage_{{ loop.index|string }}
    {%- if not loop.last %}
    UNION ALL
    {%- endif %}
    {%- endfor %}
),
rank_union AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY {{ src_pk }}
               ORDER BY {{ src_ldts }}, {{ src_source }} ASC
           ) AS row_number
    FROM stage_union
    WHERE {{ src_pk }} IS NOT NULL
),
stage AS (
    SELECT DISTINCT {{ source_cols | join(', ') }}
    FROM rank_union
    WHERE row_number = 1
),
records_to_insert AS (
    SELECT stage.* FROM stage
    {%- if dbtvault.is_vault_insert_by_period() or is_incremental() %}
    LEFT JOIN {{ this }} AS d
    ON stage.{{ src_pk }} = d.{{ src_pk }}
    WHERE {{ dbtvault.prefix([src_pk], 'd') }} IS NULL
    {%- endif %}
)

SELECT * FROM records_to_insert

{%- endmacro -%}