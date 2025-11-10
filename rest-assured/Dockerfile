FROM maven:3.9.9-eclipse-temurin-17

WORKDIR /tests

COPY pom.xml .
COPY src ./src

RUN mvn -B dependency:go-offline

ENV BASE_URL=http://fastapi_app:8000 \
    DB_URL=jdbc:postgresql://db:5432/fastapidb \
    DB_USER=fastapi \
    DB_PASS=fastapi

CMD [""]
