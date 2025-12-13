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


DROP SCHEMA IF EXISTS car_shop CASCADE;
CREATE SCHEMA car_shop;

-- Таблица брендов автомобилей
CREATE TABLE IF NOT EXISTS car_shop.brands
(
    brand_id       SERIAL PRIMARY KEY,
    -- Название бренда (например, "Tesla", "BMW")
    -- UNIQUE — важно: один бренд должен встречаться один раз
    -- NOT NULL — бренда без имени быть не может
    brand_name     VARCHAR(30) UNIQUE NOT NULL,
    -- Страна происхождения бренда (например, "Germany", "USA")
    -- Может быть NULL, если данные неизвестны
    origin_country VARCHAR(50)
);

-- Таблица моделей автомобилей
CREATE TABLE IF NOT EXISTS car_shop.models
(
    model_id             SERIAL PRIMARY KEY,
    -- Название модели (например, "Model S", "F80")
    -- NOT NULL — модель без имени не имеет смысла
    model_name           VARCHAR(50) NOT NULL,
    brand_id             INTEGER     NOT NULL,
    -- Расход топлива в л/100 км
    -- DOUBLE PRECISION — подходит для дробных значений (например, 8.3)
    -- Для электромобилей — NULL (что логично)
    gasoline_consumption DOUBLE PRECISION,
    FOREIGN KEY (brand_id) REFERENCES car_shop.brands (brand_id)
);

-- Таблица цветов автомобилей
CREATE TABLE IF NOT EXISTS car_shop.colors
(
    color_id   SERIAL PRIMARY KEY,
    -- Название цвета (например, "red", "silver")
    -- UNIQUE — один цвет может встречаться один раз
    color_name VARCHAR(20) UNIQUE NOT NULL
);

-- Таблица покупателей
CREATE TABLE IF NOT EXISTS car_shop.customers
(
    customer_id SERIAL PRIMARY KEY,
    -- Имя покупателя
    -- VARCHAR(50) — подходит для длинных имен (например, "John Doe")
    -- Может быть NULL, если данные неизвестны
    first_name  VARCHAR(50),
    -- Фамилия покупателя
    -- VARCHAR(50) — подходит для длинных фамилий (например, "Smith")
    -- Может быть NULL, если данные неизвестны
    last_name   VARCHAR(50),
    phone       VARCHAR(25) UNIQUE
);

-- Таблица продаж
CREATE TABLE IF NOT EXISTS car_shop.sales
(
    sale_id     SERIAL PRIMARY KEY,
    model_id    INTEGER,
    customer_id INTEGER,
    color_id    INTEGER,
    -- Цена продажи
    -- NUMERIC(10,2) — точное хранение денежных значений
    -- 10 цифр всего, 2 после запятой → диапазон: -9999999.99 до 9999999.99
    price       NUMERIC(10, 2),
    -- Размер скидки в процентах
    -- DOUBLE PRECISION — так как может быть 20.5%, 15% и т.п.
    -- Может быть 0, но не NULL (по умолчанию 0, если не указана)
    discount    DOUBLE PRECISION DEFAULT 0,
    sale_date   DATE,
    FOREIGN KEY (model_id) REFERENCES car_shop.models (model_id),
    FOREIGN KEY (customer_id) REFERENCES car_shop.customers (customer_id),
    FOREIGN KEY (color_id) REFERENCES car_shop.colors (color_id)
);

-- Таблица brands
ALTER TABLE car_shop.brands
    -- Ограничение: название бренда не может быть пустым
    ADD CONSTRAINT chk_brand_name_not_empty
        CHECK (TRIM(brand_name) != ''),

    -- Ограничение: страна происхождения бренда не может быть пустой
    ADD CONSTRAINT chk_origin_country_not_empty
        CHECK (TRIM(origin_country) != '');

-- Таблица models
ALTER TABLE car_shop.models
    -- Ограничение: название модели не может быть пустым
    ADD CONSTRAINT chk_model_name_not_empty
        CHECK (TRIM(model_name) != ''),

    -- Ограничение: расход топлива должен быть положительным (если не NULL)
    ADD CONSTRAINT chk_gasoline_positive
        CHECK (gasoline_consumption IS NULL OR gasoline_consumption > 0),

    -- Уникальность модели в рамках бренда
    ADD CONSTRAINT uq_model_brand UNIQUE (brand_id, model_name);

-- Таблица colors
ALTER TABLE car_shop.colors
    -- Ограничение: название цвета не может быть пустым и не должно содержать пробелов по краям
    ADD CONSTRAINT chk_color_name_trim
        CHECK (LENGTH(TRIM(color_name)) = LENGTH(color_name) AND TRIM(color_name) != '');

-- Таблица customers
ALTER TABLE car_shop.customers
    -- Ограничение: хотя бы одно из: имя или фамилия должно быть указано
    ADD CONSTRAINT chk_name_present
        CHECK (NOT (first_name IS NULL AND last_name IS NULL)),

    -- Ограничение: имя и фамилия не могут быть пустыми строками
    ADD CONSTRAINT chk_names_not_empty
        CHECK (
            (first_name IS NULL OR TRIM(first_name) != '') AND
            (last_name IS NULL OR TRIM(last_name) != '')
            ),

    -- Уникальность телефона
    ADD CONSTRAINT uq_phone UNIQUE (phone);

-- Таблица sales
ALTER TABLE car_shop.sales
    -- Ограничение: цена должна быть положительной
    ADD CONSTRAINT chk_price_positive
        CHECK (price > 0),

    -- Ограничение: скидка от 0 до 100%
    ADD CONSTRAINT chk_discount_range
        CHECK (discount >= 0 AND discount <= 100),

    -- Ограничение: дата продажи не может быть в будущем
    ADD CONSTRAINT chk_sale_date_not_future
        CHECK (sale_date <= CURRENT_DATE);

-- Очистка таблиц перед загрузкой
TRUNCATE TABLE car_shop.sales, car_shop.colors, car_shop.customers, car_shop.models, car_shop.brands RESTART IDENTITY CASCADE;

-- 1. Вставляем бренды
INSERT INTO car_shop.brands (brand_name, origin_country)
SELECT DISTINCT TRIM(SPLIT_PART(auto, ' ', 1)) AS brand_name,
                brand_origin
FROM raw_data.sales
WHERE TRIM(SPLIT_PART(auto, ' ', 1)) IS NOT NULL
  AND TRIM(SPLIT_PART(auto, ' ', 1)) != 'null'
  AND brand_origin IS NOT NULL;

-- 2. Вставляем модели с расходом топлива
INSERT INTO car_shop.models (model_name, brand_id, gasoline_consumption)
SELECT DISTINCT TRIM(SUBSTRING(SPLIT_PART(s.auto, ',', 1) FROM LENGTH(b.brand_name) + 2)) AS model_name,
                b.brand_id,
                CASE
                    WHEN LOWER(TRIM(s.gasoline_consumption)) IN ('null', '') THEN NULL
                    ELSE s.gasoline_consumption::DOUBLE PRECISION
                    END                                                                   AS gasoline_consumption
FROM raw_data.sales s
         JOIN car_shop.brands b ON b.brand_name = TRIM(SPLIT_PART(s.auto, ' ', 1))
WHERE TRIM(SUBSTRING(SPLIT_PART(s.auto, ',', 1) FROM LENGTH(b.brand_name) + 2)) != ''
  AND TRIM(SUBSTRING(SPLIT_PART(s.auto, ',', 1) FROM LENGTH(b.brand_name) + 2)) IS NOT NULL;

-- 3. Вставляем цвета
INSERT INTO car_shop.colors (color_name)
SELECT DISTINCT TRIM(SPLIT_PART(auto, ', ', 2)) AS color_name
FROM raw_data.sales
WHERE TRIM(SPLIT_PART(auto, ', ', 2)) IS NOT NULL
  AND TRIM(SPLIT_PART(auto, ', ', 2)) != ''
ORDER BY color_name;

-- 4. Вставляем покупателей
INSERT INTO car_shop.customers (first_name, last_name, phone)
SELECT DISTINCT SPLIT_PART(TRIM(s.person_name), ' ', 1)     AS first_name,
                TRIM(SUBSTRING(TRIM(s.person_name) FROM LENGTH(SPLIT_PART(TRIM(s.person_name), ' ', 1)) +
                                                        2)) AS last_name,
                NULLIF(TRIM(s.phone), '')                   AS phone
FROM raw_data.sales s
WHERE NULLIF(TRIM(s.phone), '') IS NOT NULL
  AND TRIM(s.phone) != 'null';

-- 5. Вставляем продажи
INSERT INTO car_shop.sales (model_id, customer_id, color_id, price, discount, sale_date)
SELECT DISTINCT m.model_id,
                cu.customer_id,
                co.color_id,
                s.price::NUMERIC(10, 2),
                COALESCE(NULLIF(TRIM(s.discount), '')::DOUBLE PRECISION, 0) AS discount,
                TO_DATE(s.date, 'YYYY-MM-DD')                               AS sale_date
FROM raw_data.sales s
         JOIN car_shop.brands b ON b.brand_name = TRIM(SPLIT_PART(s.auto, ' ', 1))
         JOIN car_shop.models m ON m.brand_id = b.brand_id
    AND m.model_name = TRIM(SUBSTRING(SPLIT_PART(s.auto, ',', 1) FROM LENGTH(b.brand_name) + 2))
    AND (m.gasoline_consumption IS NOT DISTINCT FROM CASE
                                                         WHEN LOWER(TRIM(s.gasoline_consumption)) IN ('null', '')
                                                             THEN NULL
                                                         ELSE s.gasoline_consumption::DOUBLE PRECISION
        END
                                       )
         JOIN car_shop.colors co ON co.color_name = TRIM(SPLIT_PART(s.auto, ', ', 2))
         JOIN car_shop.customers cu ON cu.phone = NULLIF(TRIM(s.phone), '');


-- Аналитические запросы

-- Задание 1
-- Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
SELECT ROUND(
               (COUNT(CASE WHEN gasoline_consumption IS NULL THEN 1 END) * 100.0) / COUNT(*),
               2
       ) AS nulls_percentage_gasoline_consumption
FROM car_shop.models;


-- Задание 2
-- Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
-- Итоговый результат отсортируйте по названию бренда и году в восходящем порядке.
-- Среднюю цену округлите до второго знака после запятой.
-- Запрос: название бренда, год и средняя цена автомобилей с учётом скидки
SELECT b.brand_name,
       EXTRACT(YEAR FROM s.sale_date) AS year,
       ROUND(
               AVG(s.price * (1 - s.discount / 100))::NUMERIC,
               2
       )                              AS price_avg
FROM car_shop.sales s
         JOIN car_shop.models m ON s.model_id = m.model_id
         JOIN car_shop.brands b ON m.brand_id = b.brand_id
GROUP BY b.brand_name, EXTRACT(YEAR FROM s.sale_date)
ORDER BY b.brand_name, year;


-- Задание 3
-- Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
-- Результат отсортируйте по месяцам в восходящем порядке. Среднюю цену округлите до второго знака после запятой.
SELECT EXTRACT(MONTH FROM s.sale_date) AS month,
       EXTRACT(YEAR FROM s.sale_date)  AS year,
       ROUND(
               AVG(s.price * (1 - s.discount / 100))::NUMERIC,
               2
       )
FROM car_shop.sales s
WHERE EXTRACT(YEAR FROM s.sale_date) = 2022
GROUP BY EXTRACT(MONTH FROM s.sale_date), EXTRACT(YEAR FROM s.sale_date)
ORDER BY year, month;


-- Задание 4
-- Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую.
-- Пользователь может купить две одинаковые машины — это нормально. Название машины покажите полное, с названием бренда — например:
-- Tesla Model 3. Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.
SELECT CONCAT_WS(' ', cu.first_name, cu.last_name)           AS person,
       STRING_AGG(b.brand_name || ' ' || m.model_name, ', ') AS cars
FROM car_shop.sales s
         JOIN car_shop.customers cu ON s.customer_id = cu.customer_id
         JOIN car_shop.models m ON s.model_id = m.model_id
         JOIN car_shop.brands b ON m.brand_id = b.brand_id
GROUP BY cu.customer_id, cu.first_name, cu.last_name
ORDER BY person;


-- Задание 5
-- Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки.
-- Цена в колонке price дана с учётом скидки.
SELECT b.origin_country                                         AS brand_origin,
       ROUND(MAX(s.price / (1 - s.discount / 100))::NUMERIC, 2) AS price_max,
       ROUND(MIN(s.price / (1 - s.discount / 100))::NUMERIC, 2) AS price_min
FROM car_shop.sales s
         JOIN car_shop.models m ON s.model_id = m.model_id
         JOIN car_shop.brands b ON m.brand_id = b.brand_id
GROUP BY b.origin_country
ORDER BY brand_origin;


-- Задание 6
-- Напишите запрос, который покажет количество всех пользователей из США.
-- Это пользователи, у которых номер телефона начинается на +1.
SELECT COUNT(*) AS persons_from_usa_count
FROM car_shop.customers
WHERE phone LIKE '+1%';