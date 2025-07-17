# Используем официальный образ OpenJDK
FROM eclipse-temurin:21-jdk

# Рабочая директория
WORKDIR /app

# Копируем JAR-файл
COPY consumer/target/demo-0.0.1-SNAPSHOT.jar app.jar

# Порт приложения
EXPOSE 8089

# Команда для запуска
ENTRYPOINT ["java", "-jar", "app.jar"]