# Modelo estrella

Generado por `run_sql.py` a partir de las tablas de `warehouse.duckdb`.

```mermaid
erDiagram
    dim_channel ||--o{ fact_nps_response : "channel_key"
    dim_channel ||--o{ fact_sales_order : "channel_key"
    dim_channel ||--o{ fact_sales_order_item : "channel_key"
    dim_customer ||--o{ fact_nps_response : "customer_key"
    dim_customer ||--o{ fact_sales_order : "customer_key"
    dim_customer ||--o{ fact_web_session : "customer_key"
    dim_date ||--o{ fact_nps_response : "date_key"
    dim_date ||--o{ fact_sales_order : "date_key"
    dim_date ||--o{ fact_sales_order_item : "date_key"
    dim_date ||--o{ fact_web_session : "date_key"
    dim_location ||--o{ fact_sales_order : "location_key"
    dim_product ||--o{ fact_sales_order_item : "product_key"
    dim_store ||--o{ fact_sales_order : "store_key"
    fact_sales_order ||--o{ fact_sales_order_item : "order_id"
    dim_channel {
        INTEGER channel_key PK
        INTEGER channel_id
        VARCHAR code
        VARCHAR name
    }
    dim_customer {
        INTEGER customer_key PK
        INTEGER customer_id
        VARCHAR first_name
        VARCHAR last_name
        VARCHAR status
    }
    dim_date {
        INTEGER date_key PK
        DATE fecha
        INTEGER anio
        INTEGER mes
        VARCHAR anio_mes
        VARCHAR nombre_mes
        INTEGER dia
        VARCHAR dia_semana
    }
    dim_location {
        INTEGER location_key PK
        INTEGER address_id
        VARCHAR city
        VARCHAR province
        VARCHAR province_code
        VARCHAR postal_code
    }
    dim_product {
        INTEGER product_key PK
        INTEGER product_id
        VARCHAR sku
        VARCHAR name
        VARCHAR category
        VARCHAR family
        DECIMAL list_price
    }
    dim_store {
        INTEGER store_key PK
        INTEGER store_id
        VARCHAR name
    }
    fact_nps_response {
        BIGINT nps_id PK
        INTEGER date_key FK
        INTEGER customer_key FK
        INTEGER channel_key FK
        INTEGER score
        VARCHAR nps_category
    }
    fact_sales_order {
        BIGINT order_id PK
        INTEGER date_key FK
        INTEGER customer_key FK
        INTEGER channel_key FK
        INTEGER store_key FK
        INTEGER location_key FK
        VARCHAR status
        DECIMAL subtotal
        DECIMAL tax_amount
        DECIMAL shipping_fee
        DECIMAL total_amount
    }
    fact_sales_order_item {
        BIGINT order_item_id PK
        BIGINT order_id FK
        INTEGER date_key FK
        INTEGER product_key FK
        INTEGER channel_key FK
        VARCHAR status
        INTEGER quantity
        DECIMAL unit_price
        DECIMAL discount_amount
        DECIMAL line_total
    }
    fact_web_session {
        BIGINT session_id PK
        INTEGER date_key FK
        INTEGER customer_key FK
        VARCHAR source
        VARCHAR device
        BIGINT duration_seconds
    }
    kpi_nps {
        VARCHAR anio_mes
        VARCHAR canal
        BIGINT respuestas
        BIGINT promotores
        BIGINT pasivos
        BIGINT detractores
        DOUBLE nps
    }
    kpi_ranking_productos {
        VARCHAR anio_mes
        VARCHAR canal
        VARCHAR producto
        VARCHAR categoria
        HUGEINT unidades
        DECIMAL ventas
        BIGINT ranking
    }
    kpi_usuarios_activos_diario {
        DATE fecha
        VARCHAR anio_mes
        BIGINT usuarios_activos
        BIGINT sesiones_anonimas
        BIGINT usuarios_activos_con_anonimos
        BIGINT sesiones
    }
    kpi_usuarios_activos_mensual {
        VARCHAR anio_mes
        BIGINT usuarios_activos
        BIGINT sesiones_anonimas
        BIGINT usuarios_activos_con_anonimos
        BIGINT sesiones
    }
    kpi_ventas {
        DATE fecha
        VARCHAR anio_mes
        VARCHAR canal
        VARCHAR provincia
        BIGINT pedidos
        DECIMAL ventas_sin_iva_ni_envio
        DECIMAL ventas_con_iva_y_envio
        DOUBLE ticket_promedio_sin_iva
        DOUBLE ticket_promedio_con_iva
    }
    kpi_ventas_mensual {
        VARCHAR anio_mes
        VARCHAR canal
        BIGINT pedidos
        DECIMAL ventas_sin_iva_ni_envio
        DECIMAL ventas_con_iva_y_envio
        DOUBLE ticket_promedio_sin_iva
        DOUBLE ticket_promedio_con_iva
    }
    kpi_ventas_provincia {
        VARCHAR provincia
        BIGINT pedidos
        DECIMAL ventas_sin_iva_ni_envio
        DECIMAL ventas_con_iva_y_envio
        DOUBLE ticket_promedio_sin_iva
        DOUBLE ticket_promedio_con_iva
    }
    kpi_ventas_total {
        BIGINT pedidos
        DECIMAL ventas_sin_iva_ni_envio
        DECIMAL ventas_con_iva_y_envio
        DOUBLE ticket_promedio_sin_iva
        DOUBLE ticket_promedio_con_iva
    }
```
