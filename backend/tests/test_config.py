from app.core.config import Settings


def test_connection_string_uses_minimum_privilege_user_and_escapes_password() -> None:
    settings = Settings(
        _env_file=None,
        db_server="localhost",
        db_port=1433,
        db_app_user="tecnostock_app",
        db_app_password="abc}def;ghi",
    )
    connection_string = settings.database_connection_string()
    assert "SERVER=localhost,1433" in connection_string
    assert "UID=tecnostock_app" in connection_string
    assert "PWD={abc}}def;ghi}" in connection_string
    assert "sa" not in connection_string.split("UID=", 1)[1].split(";", 1)[0]
