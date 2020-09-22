{%- macro link(src_pk, src_fk, src_ldts, src_source, source_model) -%}

    {{- adapter.dispatch('link', packages = ['dbtvault'])(src_pk=src_pk, src_fk=src_fk,
                                                          src_ldts=src_ldts, src_source=src_source,
                                                          source_model=source_model) -}}

{%- endmacro -%}

{%- macro snowflake__link(src_pk, src_fk, src_ldts, src_source, source_model) -%}

{%- set source_cols = dbtvault.expand_column_list(columns=[src_pk, src_fk, src_ldts, src_source]) -%}
{%- set fk_cols = dbtvault.expand_column_list([src_fk]) -%}

{{ dbtvault.prepend_generated_by() }}

{{ 'WITH ' -}}

{%- if not (source_model is iterable and source_model is not string) -%}
    {%- set source_model = [source_model] -%}
{%- endif -%}

{%- for src in source_model -%}

rank_{{ loop.index|string }} AS (
    SELECT {{ source_cols | join(', ') }},
           ROW_NUMBER() OVER(
               PARTITION BY {{ src_pk }}
               ORDER BY {{ src_ldts }} ASC
           ) AS row_number
    FROM {{ ref(src) }}
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
    WHERE {{ dbtvault.multikey(fk_cols, condition='IS NOT NULL') }}
),
stage AS (
    SELECT DISTINCT {{ source_cols | join(', ') }}
    FROM rank_union
    WHERE row_number = 1
),
records_to_insert AS (
    SELECT stage.* FROM stage
    {%- if is_incremental() %}
    LEFT JOIN {{ this }} AS d
    ON stage.{{ src_pk }} = d.{{ src_pk }}
    WHERE {{ dbtvault.prefix([src_pk], 'd') }} IS NULL
    {%- endif %}
)

SELECT * FROM records_to_insert

{%- endmacro -%}