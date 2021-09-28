from behave import fixture


@fixture
def eff_satellite_hashdiff(context):
    """
    Define the structures and metadata to load effectivity satellites
    """

    context.derived_columns = {
        "STG_CUSTOMER": {
            "STATUS": "'TRUE' ::BOOLEAN",
            "STATUS_FLAG_T": "1 ::INT",
            "STATUS_FLAG_F": "0 ::INT"
        },
    }

    context.hashed_columns = {
        "STG_CUSTOMER": {
            "CUSTOMER_ORDER_PK": ["CUSTOMER_ID", "ORDER_ID"],
            "CUSTOMER_PK": "CUSTOMER_ID",
            "ORDER_PK": "ORDER_ID",
            "HASHDIFF_T": "STATUS_FLAG_T",
            "HASHDIFF_F": "STATUS_FLAG_F"
        }
    }

    context.vault_structure_columns = {
        "EFF_SAT": {
            "src_pk": "CUSTOMER_ORDER_PK",
            "src_dfk": ["ORDER_PK"],
            "src_sfk": "CUSTOMER_PK",
            "status": "STATUS",
            "src_hashdiff": "HASHDIFF",
            "src_eff": "EFFECTIVE_FROM",
            "src_ldts": "LOAD_DATE",
            "src_source": "SOURCE"
        }
    }

    context.seed_config = {
        "RAW_STAGE": {
            "+column_types": {
                "CUSTOMER_ID": "NUMBER(38, 0)",
                "ORDER_ID": "VARCHAR",
                "LOAD_DATE": "DATE",
                "SOURCE": "VARCHAR"

            }
        },

        "EFF_SAT": {
            "+column_types": {
                "CUSTOMER_ORDER_PK": "BINARY(16)",
                "CUSTOMER_PK": "BINARY(16)",
                "ORDER_PK": "BINARY(16)",
                "STATUS": "BOOLEAN",
                "EFFECTIVE_FROM": "DATE",
                "HASHDIFF": "BINARY(16)",
                "LOAD_DATE": "DATE",
                "SOURCE": "VARCHAR"
            }
        }
    }


