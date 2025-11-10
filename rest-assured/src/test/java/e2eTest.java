import base.RequestBuilder;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import org.junit.jupiter.api.*;

import java.util.Map;

import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.*;

@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
public class e2eTest {

    private static final String BASE_URL = System.getenv().getOrDefault("BASE_URL", "http://fastapi_app:8000");
    private static RequestBuilder request;
    private static int itemId;

    @BeforeAll
    static void setup() {
        request = new RequestBuilder(BASE_URL, Map.of("Accept", "application/json"));
    }

    @Test
    @Order(1)
    @DisplayName("Create new item")
    void testCreateItem() {
        String payload = "{\"name\": \"E2E Item\", \"description\": \"End-to-end test\"}";

        Response response = request.buildRequest(payload)
                .when()
                .post("/items")
                .then()
                .statusCode(200)
                .contentType(ContentType.JSON)
                .extract()
                .response();

        itemId = response.jsonPath().getInt("id");
        assertThat(itemId, greaterThan(0));
    }

    @Test
    @Order(2)
    @DisplayName("Retrieve created item")
    void testGetItem() {
        request.buildRequest("")
                .when()
                .get("/items/" + itemId)
                .then()
                .statusCode(200)
                .body("name", equalTo("E2E Item"))
                .body("description", equalTo("End-to-end test"));
    }

    @Test
    @Order(3)
    @DisplayName("Delete item")
    void testDeleteItem() {
        request.buildRequest("")
                .when()
                .delete("/items/" + itemId)
                .then()
                .statusCode(200)
                .body("message", containsString("Item " + itemId + " deleted"));
    }

    @Test
    @Order(4)
    @DisplayName("Verify item is gone")
    void testGetAfterDelete() {
        request.buildRequest("")
                .when()
                .get("/items/" + itemId)
                .then()
                .statusCode(404);
    }
}
