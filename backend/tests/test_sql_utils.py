from scripts.sql_utils import quote_sql_identifier, replace_sql_placeholders, split_batches


def test_split_batches_only_splits_go_lines() -> None:
    script = "SELECT N'GO';\nGO\nSELECT 2; -- GO on a query line\nGO -- separador\nSELECT 3;"
    assert split_batches(script) == ["SELECT N'GO';", "SELECT 2; -- GO on a query line", "SELECT 3;"]


def test_quote_sql_identifier_escapes_closing_bracket() -> None:
    assert quote_sql_identifier("Store]Name") == "[Store]]Name]"


def test_placeholders_escape_values_and_identifier() -> None:
    rendered = replace_sql_placeholders(
        "CREATE DATABASE __DB_NAME__; SELECT N'__DB_NAME_TEXT__', N'__DB_APP_USER__', N'__DB_APP_PASSWORD__';",
        db_name="StoreDB",
        app_user="app'user",
        app_password="p'ass",
    )
    assert "CREATE DATABASE [StoreDB]" in rendered
    assert "N'StoreDB'" in rendered
    assert "N'app''user'" in rendered
    assert "N'p''ass'" in rendered
