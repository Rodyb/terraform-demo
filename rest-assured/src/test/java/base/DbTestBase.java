package base;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public abstract class DbTestBase extends ApiTestBase {
    protected static final String DB_URL = System.getenv().getOrDefault("DB_URL", "jdbc:postgresql://db:5432/fastapidb");
    protected static final String DB_USER = System.getenv().getOrDefault("DB_USER", "fastapi");
    protected static final String DB_PASS = System.getenv().getOrDefault("DB_PASS", "fastapi");

    protected Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
    }
}
