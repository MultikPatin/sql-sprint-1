CREATE SCHEMA IF NOT EXISTS raw_data;

CREATE TABLE IF NOT EXISTS raw_data.sales
(
    id                   INTEGER PRIMARY KEY,
    auto                 TEXT,
    gasoline_consumption TEXT,
    price                DOUBLE PRECISION,
    date                 TEXT,
    person_name          TEXT,
    phone                TEXT,
    discount             TEXT,
    brand_origin         TEXT
);

CREATE SCHEMA IF NOT EXISTS car_shop;

DROP TABLE IF EXISTS car_shop.brands;
DROP TABLE IF EXISTS car_shop.models;
DROP TABLE IF EXISTS car_shop.cars;
DROP TABLE IF EXISTS car_shop.customers;
DROP TABLE IF EXISTS car_shop.sales;

-- Таблица брендов автомобилей
CREATE TABLE IF NOT EXISTS car_shop.brands
(
    brand_id       SERIAL PRIMARY KEY,
    -- Название бренда (например, "Tesla", "BMW")
    -- TEXT — безопасный выбор, так как имена могут быть разной длины и содержать спецсимволы (например, "Škoda")
    -- UNIQUE — важно: один бренд должен встречаться один раз
    -- NOT NULL — бренда без имени быть не может
    brand_name     TEXT UNIQUE NOT NULL,
    -- Страна происхождения бренда (например, "Germany", "USA")
    -- TEXT — подходит, так как названия стран имеют разную длину
    -- Может быть NULL, если данные неизвестны
    origin_country TEXT
);

-- Таблица моделей автомобилей
CREATE TABLE IF NOT EXISTS car_shop.models
(
    model_id   SERIAL PRIMARY KEY,
    -- Название модели (например, "Model S", "F80")
    -- TEXT — так как названия могут быть сложными ("911 GT3 RS")
    -- NOT NULL — модель без имени не имеет смысла
    model_name TEXT NOT NULL,
    brand_id   INTEGER NOT NULL,
    FOREIGN KEY (brand_id) REFERENCES car_shop.brands (brand_id)
);

-- Таблица автомобилей
CREATE TABLE IF NOT EXISTS car_shop.cars
(
    car_id                 SERIAL PRIMARY KEY,
    model_id               INTEGER,
    -- Цвет автомобиля (например, "red", "silver")
    -- TEXT — цвета могут быть составными ("midnight black"), но не требуют числовых операций
    -- Может быть NULL, если цвет не указан
    color                  TEXT,
    -- Расход топлива в л/100 км
    -- DOUBLE PRECISION — подходит для дробных значений (например, 8.3)
    -- Для электромобилей — NULL (что логично)
    gasoline_consumption   DOUBLE PRECISION,
    FOREIGN KEY (model_id) REFERENCES car_shop.models (model_id)
);

-- Таблица покупателей
CREATE TABLE IF NOT EXISTS car_shop.customers
(
    customer_id SERIAL PRIMARY KEY,
    first_name  TEXT,
    last_name   TEXT,
    phone       TEXT UNIQUE,
    CONSTRAINT uq_phone UNIQUE (phone)
);

-- Таблица продаж
CREATE TABLE IF NOT EXISTS car_shop.sales
(
    sale_id       SERIAL PRIMARY KEY,
    car_id        INTEGER,
    customer_id   INTEGER,
    -- Цена продажи
    -- DOUBLE PRECISION — подходит для цен, где важна дробная часть
    -- Хотя в строгих финансовых системах используют DECIMAL(10,2),
    -- здесь DOUBLE достаточно, чтобы не усложнять
    price         DOUBLE PRECISION,
    -- Размер скидки в процентах
    -- DOUBLE PRECISION — так как может быть 20.5%, 15% и т.п.
    -- Может быть 0, но не NULL (по умолчанию 0, если не указана)
    discount      DOUBLE PRECISION DEFAULT 0,
    -- Дата продажи
    -- DATE — специальный тип для хранения даты (без времени)
    sale_date     DATE,
    FOREIGN KEY (car_id) REFERENCES car_shop.cars (car_id),
    FOREIGN KEY (customer_id) REFERENCES car_shop.customers (customer_id)
);