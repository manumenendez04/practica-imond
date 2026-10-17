-- =====================================================================
-- 02_hechos.sql — Tablas de HECHOS del modelo estrella
-- =====================================================================
-- Este archivo se ejecuta después de 01_dimensiones.sql porque los hechos
-- apuntan a las dimensiones con FOREIGN KEY (REFERENCES).
--
-- Para cada tabla de hechos:
--   1. Definí el GRANO: ¿qué representa UNA fila?
--      (ej.: un producto dentro de un pedido, una sesión web, una respuesta NPS)
--   2. CREATE TABLE con:
--        - PRIMARY KEY
--        - una FOREIGN KEY por cada dimensión:  product_key INTEGER REFERENCES dim_product (product_key)
--        - las métricas (cantidades, importes, puntajes...)
--   3. INSERT INTO ... SELECT uniendo las tablas de origen (raw.) con las dimensiones
--      para obtener las claves.
--
-- Patrón para obtener la clave de una dimensión:
--
--   SELECT i.order_item_id, p.product_key, i.quantity, i.line_total
--   FROM raw.sales_order_item AS i
--   JOIN dim_product AS p ON p.product_id = i.product_id
--
-- Si una FOREIGN KEY apunta a una clave que no existe en la dimensión,
-- DuckDB rechaza la carga y run_sql.py te muestra el error.
-- =====================================================================


-- TU TURNO: creá acá las tablas de hechos.


-- fact_sales_order: grano = un pedido
CREATE TABLE fact_sales_order (
    order_id     BIGINT PRIMARY KEY,
    date_key     INTEGER NOT NULL REFERENCES dim_date(date_key),
    customer_key INTEGER NOT NULL REFERENCES dim_customer(customer_key),
    channel_key  INTEGER NOT NULL REFERENCES dim_channel(channel_key),
    store_key    INTEGER NOT NULL REFERENCES dim_store(store_key),
    location_key INTEGER NOT NULL REFERENCES dim_location(location_key),
    status       VARCHAR NOT NULL,
    subtotal     DECIMAL(12, 2),
    tax_amount   DECIMAL(12, 2),
    shipping_fee DECIMAL(12, 2),
    total_amount DECIMAL(12, 2)
);


INSERT INTO fact_sales_order
SELECT
    o.order_id,
    CAST(strftime(o.order_date, '%Y%m%d') AS INTEGER) AS date_key,
    COALESCE(c.customer_key, -1)                       AS customer_key,
    ch.channel_key,
    COALESCE(s.store_key, -1)                          AS store_key,
    COALESCE(l.location_key, -1)                       AS location_key,
    o.status,
    CAST(o.subtotal     AS DECIMAL(12, 2)),
    CAST(o.tax_amount   AS DECIMAL(12, 2)),
    CAST(o.shipping_fee AS DECIMAL(12, 2)),
    CAST(o.total_amount AS DECIMAL(12, 2))
FROM raw.sales_order AS o
LEFT JOIN dim_customer AS c  ON c.customer_id  = o.customer_id
LEFT JOIN dim_channel  AS ch ON ch.channel_id  = o.channel_id
LEFT JOIN dim_store    AS s  ON s.store_id     = o.store_id
LEFT JOIN dim_location AS l  ON l.address_id   = o.shipping_address_id;


-- fact_sales_order_item: grano = una línea de pedido 
CREATE TABLE fact_sales_order_item (
    order_item_id   BIGINT PRIMARY KEY,
    order_id        BIGINT NOT NULL REFERENCES fact_sales_order(order_id),
    date_key        INTEGER NOT NULL REFERENCES dim_date(date_key),
    product_key     INTEGER NOT NULL REFERENCES dim_product(product_key),
    channel_key     INTEGER NOT NULL REFERENCES dim_channel(channel_key),
    status          VARCHAR NOT NULL,
    quantity        INTEGER NOT NULL,
    unit_price      DECIMAL(12, 2),
    discount_amount DECIMAL(12, 2),
    line_total      DECIMAL(12, 2)
);




INSERT INTO fact_sales_order_item
SELECT
    i.order_item_id,
    i.order_id,
    CAST(strftime(o.order_date, '%Y%m%d') AS INTEGER) AS date_key,
    p.product_key,
    ch.channel_key,
    o.status,
    i.quantity,
    CAST(i.unit_price      AS DECIMAL(12, 2)),
    CAST(i.discount_amount AS DECIMAL(12, 2)),
    CAST(i.line_total      AS DECIMAL(12, 2))
FROM raw.sales_order_item AS i
LEFT JOIN raw.sales_order  AS o  ON o.order_id    = i.order_id
LEFT JOIN dim_product      AS p  ON p.product_id  = i.product_id
LEFT JOIN dim_channel      AS ch ON ch.channel_id = o.channel_id;



-- fact_web_session: grano = una visita a la web
CREATE TABLE fact_web_session (
    session_id       BIGINT PRIMARY KEY,
    date_key         INTEGER NOT NULL REFERENCES dim_date(date_key),
    customer_key     INTEGER NOT NULL REFERENCES dim_customer(customer_key),
    source           VARCHAR,
    device           VARCHAR,
    duration_seconds BIGINT
);



INSERT INTO fact_web_session
SELECT
    w.session_id,
    CAST(strftime(w.started_at, '%Y%m%d') AS INTEGER)  AS date_key,
    COALESCE(c.customer_key, -1)                       AS customer_key,
    w.source,
    w.device,
    date_diff('second', w.started_at, w.ended_at)      AS duration_seconds
FROM raw.web_session AS w
LEFT JOIN dim_customer AS c ON c.customer_id = w.customer_id;


-- fact_nps_response: grano = una respuesta a la encuesta NPS
CREATE TABLE fact_nps_response (
    nps_id       BIGINT PRIMARY KEY,
    date_key     INTEGER NOT NULL REFERENCES dim_date(date_key),
    customer_key INTEGER NOT NULL REFERENCES dim_customer(customer_key),
    channel_key  INTEGER NOT NULL REFERENCES dim_channel(channel_key),
    score        INTEGER NOT NULL,
    nps_category VARCHAR NOT NULL
);



INSERT INTO fact_nps_response
SELECT
    n.nps_id,
    CAST(strftime(n.responded_at, '%Y%m%d') AS INTEGER) AS date_key,
    COALESCE(c.customer_key, -1)                        AS customer_key,
    ch.channel_key,
    n.score,
    CASE
        WHEN n.score >= 9 THEN 'PROMOTER'
        WHEN n.score >= 7 THEN 'PASSIVE'
        ELSE 'DETRACTOR'
    END AS nps_category
FROM raw.nps_response AS n
LEFT JOIN dim_customer AS c  ON c.customer_id = n.customer_id
LEFT JOIN dim_channel  AS ch ON ch.channel_id = n.channel_id;