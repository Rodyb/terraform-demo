import base.RequestBuilder;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import org.junit.jupiter.api.*;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Map;

import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.*;

@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
public class integrationTest {

    private static final String BASE_URL = System.getenv().getOrDefault("BASE_URL", "http://fastapi_app:8000");
    private static final String DB_URL = System.getenv().getOrDefault("DB_URL", "jdbc:postgresql://db:5432/fastapidb");
    private static final String DB_USER = System.getenv().getOrDefault("DB_USER", "fastapi");
    private static final String DB_PASS = System.getenv().getOrDefault("DB_PASS", "fastapi");

    private static RequestBuilder request;
    private static int itemId;

    @BeforeAll
    static void setup() {
        request = new RequestBuilder(BASE_URL, Map.of("Accept", "application/json"));
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
    }

    @Test
    @Order(1)
    void testCreateAndGetItem() {
        String payload = "{\"name\": \"Test Item\", \"description\": \"Test Desc\"}";

        Response createResponse = request.buildRequest(payload)
                .when()
                .post("/items")
                .then()
                .statusCode(200)
                .contentType(ContentType.JSON)
                .extract()
                .response();

        itemId = createResponse.jsonPath().getInt("id");
        assertThat(itemId, greaterThan(0));

        request.buildRequest("")
                .when()
                .get("/items/" + itemId)
                .then()
                .statusCode(200)
                .body("name", equalTo("Test Item"));
    }

    @Test
    @Order(2)
    void testItemIsPersistedInDB() throws Exception {
        String payload = "{\"name\": \"DB Test\", \"description\": \"From test\"}";

        Response createResponse = request.buildRequest(payload)
                .when()
                .post("/items")
                .then()
                .statusCode(200)
                .extract()
                .response();

        int dbItemId = createResponse.jsonPath().getInt("id");

        try (Connection conn = getConnection()) {
            PreparedStatement stmt = conn.prepareStatement("SELECT name, description FROM items WHERE id = ?");
            stmt.setInt(1, dbItemId);
            ResultSet rs = stmt.executeQuery();

            Assertions.assertTrue(rs.next(), "Item must exist in DB");
            assertThat(rs.getString("name"), equalTo("DB Test"));
            assertThat(rs.getString("description"), equalTo("From test"));
        }
    }

    @Test
    @Order(3)
    void testDeleteItem() {
        String payload = "{\"name\": \"To Delete\", \"description\": \"Gone soon\"}";

        Response createResponse = request.buildRequest(payload)
                .when()
                .post("/items")
                .then()
                .statusCode(200)
                .extract()
                .response();

        int deleteId = createResponse.jsonPath().getInt("id");

        request.buildRequest("")
                .when()
                .delete("/items/" + deleteId)
                .then()
                .statusCode(200)
                .body("message", containsString("Item " + deleteId + " deleted"));
    }

    @Test
    @Order(4)
    void testItemIsRemovedFromDB() throws Exception {
        String payload = "{\"name\": \"To Be Deleted\", \"description\": \"Temporary\"}";

        Response createResponse = request.buildRequest(payload)
                .when()
                .post("/items")
                .then()
                .statusCode(200)
                .extract()
                .response();

        int tempId = createResponse.jsonPath().getInt("id");

        request.buildRequest("")
                .when()
                .delete("/items/" + tempId)
                .then()
                .statusCode(200);

        try (Connection conn = getConnection()) {
            PreparedStatement stmt = conn.prepareStatement("SELECT id FROM items WHERE id = ?");
            stmt.setInt(1, tempId);
            ResultSet rs = stmt.executeQuery();

            Assertions.assertFalse(rs.next(), "Item should no longer exist in DB");
        }
    }
}
