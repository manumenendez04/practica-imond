-- =====================================================================
-- 03_consultas.sql — Consultas para revisar el modelo y calcular KPIs
-- =====================================================================
-- Cada SELECT de este archivo se muestra en la terminal al ejecutar
-- run_sql.py. Usalo para:
--   * comprobar que las tablas se cargaron bien (cantidad de filas, nulos...)
--   * escribir las consultas clave de los KPIs que pide la consigna
--     (ventas, usuarios activos, ticket promedio, NPS, ventas por provincia,
--     ranking mensual por producto) usando las tablas del modelo estrella.
-- =====================================================================


-- Ejemplo: revisar la dimensión producto
SELECT product_key, name, category, family, list_price
FROM dim_product
ORDER BY product_key;




-- KPI: Ventas y Ticket Promedio, por dia, canal y provincia
CREATE TABLE kpi_ventas AS
SELECT
    d.fecha,
    d.anio_mes,
    ch.name     AS canal,
    l.province  AS provincia,
    COUNT(*)    AS pedidos,
    SUM(f.subtotal)     AS ventas_sin_iva_ni_envio,
    SUM(f.total_amount) AS ventas_con_iva_y_envio,
    ROUND(SUM(f.subtotal)     / COUNT(*), 2) AS ticket_promedio_sin_iva,
    ROUND(SUM(f.total_amount) / COUNT(*), 2) AS ticket_promedio_con_iva
FROM fact_sales_order AS f
JOIN dim_date     AS d  ON d.date_key     = f.date_key
JOIN dim_channel  AS ch ON ch.channel_key = f.channel_key
JOIN dim_location AS l  ON l.location_key = f.location_key
WHERE f.status IN ('PAID', 'FULFILLED')
GROUP BY d.fecha, d.anio_mes, ch.name, l.province
ORDER BY d.fecha, ch.name, l.province;


-- KPI: Usuarios Activos por dia
CREATE TABLE kpi_usuarios_activos_diario AS
SELECT
    d.fecha,
    d.anio_mes,
    COUNT(DISTINCT CASE WHEN w.customer_key <> -1 THEN w.customer_key END) AS usuarios_activos,
    COUNT(*) FILTER (WHERE w.customer_key = -1)                            AS sesiones_anonimas,
    COUNT(DISTINCT CASE WHEN w.customer_key <> -1 THEN w.customer_key END)
      + COUNT(*) FILTER (WHERE w.customer_key = -1)                        AS usuarios_activos_con_anonimos,
    COUNT(*)                                                               AS sesiones
FROM fact_web_session w
JOIN dim_date d ON d.date_key = w.date_key
GROUP BY d.fecha, d.anio_mes
ORDER BY d.fecha;


-- KPI: Usuarios Activos por mes
CREATE TABLE kpi_usuarios_activos_mensual AS
SELECT
    d.anio_mes,
    COUNT(DISTINCT CASE WHEN w.customer_key <> -1 THEN w.customer_key END) AS usuarios_activos,
    COUNT(*) FILTER (WHERE w.customer_key = -1)                            AS sesiones_anonimas,
    COUNT(DISTINCT CASE WHEN w.customer_key <> -1 THEN w.customer_key END)
      + COUNT(*) FILTER (WHERE w.customer_key = -1)                        AS usuarios_activos_con_anonimos,
    COUNT(*)                                                               AS sesiones
FROM fact_web_session w
JOIN dim_date d ON d.date_key = w.date_key
GROUP BY d.anio_mes
ORDER BY d.anio_mes;


-- KPI: NPS por mes y canal
CREATE TABLE kpi_nps AS
SELECT
    d.anio_mes,
    ch.name AS canal,
    COUNT(*) AS respuestas,
    COUNT(*) FILTER (WHERE n.nps_category = 'PROMOTER')  AS promotores,
    COUNT(*) FILTER (WHERE n.nps_category = 'PASSIVE')   AS pasivos,
    COUNT(*) FILTER (WHERE n.nps_category = 'DETRACTOR') AS detractores,
    ROUND(100.0 * (
        COUNT(*) FILTER (WHERE n.nps_category = 'PROMOTER')
      - COUNT(*) FILTER (WHERE n.nps_category = 'DETRACTOR')
    ) / COUNT(*), 1) AS nps
FROM fact_nps_response AS n
JOIN dim_date    AS d  ON d.date_key     = n.date_key
JOIN dim_channel AS ch ON ch.channel_key = n.channel_key
GROUP BY d.anio_mes, ch.name
ORDER BY d.anio_mes, ch.name;


-- KPI: Ranking mensual de productos, por canal
CREATE TABLE kpi_ranking_productos AS
SELECT
    d.anio_mes,
    ch.name     AS canal,
    p.name      AS producto,
    p.category  AS categoria,
    SUM(i.quantity)   AS unidades,
    SUM(i.line_total) AS ventas,
    RANK() OVER (
        PARTITION BY d.anio_mes, ch.name
        ORDER BY SUM(i.line_total) DESC
    ) AS ranking
FROM fact_sales_order_item AS i
JOIN dim_date    AS d  ON d.date_key     = i.date_key
JOIN dim_product AS p  ON p.product_key  = i.product_key
JOIN dim_channel AS ch ON ch.channel_key = i.channel_key
WHERE i.status IN ('PAID', 'FULFILLED')
GROUP BY d.anio_mes, ch.name, p.name, p.category
ORDER BY d.anio_mes, ch.name, ranking, p.name;


-- KPI: Ventas y Ticket Promedio, por mes y canal
CREATE TABLE kpi_ventas_mensual AS
SELECT
    d.anio_mes,
    ch.name     AS canal,
    COUNT(*)    AS pedidos,
    SUM(f.subtotal)     AS ventas_sin_iva_ni_envio,
    SUM(f.total_amount) AS ventas_con_iva_y_envio,
    ROUND(SUM(f.subtotal)     / COUNT(*), 2) AS ticket_promedio_sin_iva,
    ROUND(SUM(f.total_amount) / COUNT(*), 2) AS ticket_promedio_con_iva
FROM fact_sales_order AS f
JOIN dim_date    AS d  ON d.date_key     = f.date_key
JOIN dim_channel AS ch ON ch.channel_key = f.channel_key
WHERE f.status IN ('PAID', 'FULFILLED')
GROUP BY d.anio_mes, ch.name
ORDER BY d.anio_mes, ch.name;


-- KPI: Ventas y Ticket Promedio, por provincia (todo el período)
CREATE TABLE kpi_ventas_provincia AS
SELECT
    l.province  AS provincia,
    COUNT(*)    AS pedidos,
    SUM(f.subtotal)     AS ventas_sin_iva_ni_envio,
    SUM(f.total_amount) AS ventas_con_iva_y_envio,
    ROUND(SUM(f.subtotal)     / COUNT(*), 2) AS ticket_promedio_sin_iva,
    ROUND(SUM(f.total_amount) / COUNT(*), 2) AS ticket_promedio_con_iva
FROM fact_sales_order AS f
JOIN dim_location AS l ON l.location_key = f.location_key
WHERE f.status IN ('PAID', 'FULFILLED')
GROUP BY l.province
ORDER BY l.province;




-- KPI: Ventas y Ticket Promedio, total general
CREATE TABLE kpi_ventas_total AS
SELECT
    COUNT(*)    AS pedidos,
    SUM(f.subtotal)     AS ventas_sin_iva_ni_envio,
    SUM(f.total_amount) AS ventas_con_iva_y_envio,
    ROUND(SUM(f.subtotal)     / COUNT(*), 2) AS ticket_promedio_sin_iva,
    ROUND(SUM(f.total_amount) / COUNT(*), 2) AS ticket_promedio_con_iva
FROM fact_sales_order AS f
WHERE f.status IN ('PAID', 'FULFILLED');