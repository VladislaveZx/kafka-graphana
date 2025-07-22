-- Удаляем существующий PRIMARY KEY
ALTER TABLE sensor_data DROP CONSTRAINT IF EXISTS sensor_data_pkey;

-- Создаем новый составной PRIMARY KEY с timestamp (иначе не создадим гипертаблицу)
ALTER TABLE sensor_data ADD PRIMARY KEY (id, timestamp);

-- Затем создаем гибертаблицу
SELECT create_hypertable(
               'sensor_data',
               'timestamp',
               chunk_time_interval => INTERVAL '1 MIN',
               if_not_exists => TRUE,
               migrate_data => TRUE
       );


CREATE INDEX IF NOT EXISTS sensor_data_timestamp_type_idx ON sensor_data (timestamp, type);
CREATE INDEX IF NOT EXISTS sensor_data_room_timestamp_idx ON sensor_data (room, timestamp);


-- Температура по часам
SELECT
    time_bucket('1 hour', timestamp) AS hour,
    room,
    ROUND(AVG(value::numeric), 2) AS avg_temp,
    MIN(value::numeric) AS min_temp,
    MAX(value::numeric) AS max_temp,
    COUNT(*) AS readings_count
FROM sensor_data
WHERE type = 'temperature'
GROUP BY hour, room
ORDER BY hour, room;


-- Температура по минутам для конкретной комнаты
SELECT
    time_bucket('1 minute', timestamp) AS minute,
    room,
    ROUND(AVG(value::numeric), 2) AS avg_temp
FROM sensor_data
WHERE type = 'temperature' AND room = 'living_room'
GROUP BY minute, room
ORDER BY minute;


-- Включаем сжатие для гипертаблицы
ALTER TABLE sensor_data SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'timestamp DESC, id',
    timescaledb.compress_segmentby = 'room, type'
    );


-- Создаем отдельную таблицу для звуковых данных
CREATE TABLE sensor_data_sound (LIKE sensor_data INCLUDING DEFAULTS INCLUDING CONSTRAINTS);


-- Преобразуем в гипертаблицу
SELECT create_hypertable('sensor_data_sound', 'timestamp', chunk_time_interval => INTERVAL '1 day');


-- Переносим звуковые данные
INSERT INTO sensor_data_sound
SELECT * FROM sensor_data WHERE type = 'sound';


-- Устанавливаем политику сжатия для новой таблицы
ALTER TABLE sensor_data_sound SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'timestamp DESC, id',
    timescaledb.compress_segmentby = 'room'
    );

-- Устанавливаем политику сжатия для звуковых данных
SELECT add_compression_policy('sensor_data_sound', INTERVAL '5 minutes');


-- Устанавливаем политику удаления для звуковых данных
SELECT add_retention_policy('sensor_data_sound', INTERVAL '10 minutes', if_not_exists => TRUE);
