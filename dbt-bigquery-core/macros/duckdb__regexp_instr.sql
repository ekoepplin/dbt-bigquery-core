{# DuckDB has no regexp_instr function; dbt_expectations' default__regexp_instr
   emits one anyway, so we override the dispatch for the duckdb dev target here.
   Only the ">0" match check from expect_column_values_to_match_regex relies on
   this, so a boolean-derived 1/0 is sufficient. #}
{% macro duckdb__regexp_instr(source_value, regexp, position, occurrence, is_raw, flags) %}
{% if flags %}{{ dbt_expectations._validate_flags(flags, 'ismxg') }}{% endif %}
case when regexp_matches({{ source_value }}, '{{ regexp }}'{% if flags %}, '{{ flags }}'{% endif %}) then 1 else 0 end
{% endmacro %}
