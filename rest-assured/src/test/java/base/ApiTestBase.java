package base;

import io.restassured.RestAssured;
import org.junit.jupiter.api.BeforeAll;

public abstract class ApiTestBase {
    protected static final String BASE_URL = System.getenv().getOrDefault("BASE_URL", "http://fastapi_app:8000");

    @BeforeAll
    static void setupApi() {
        RestAssured.baseURI = BASE_URL;
    }
}
