# EcoBottle AR — Data warehouse y KPIs de negocio digital

Práctica de **Introducción al Marketing Online y los Negocios Digitales**.

Este repositorio transforma los datos de origen de EcoBottle AR (13 tablas CSV) en un **data warehouse con modelo estrella** usando **SQL en DuckDB**, y calcula los **KPI** del negocio dentro del propio código SQL. El tablero se alimenta de los CSV resultantes y no recalcula nada.

- **Consigna:** [Práctica](https://docs.google.com/document/d/15RNP3FVqLjO4jzh80AAkK6mUR5DOLqPxLjQxqvdzrYg/edit?usp=sharing)
- **Guía original de la cátedra:** [docs/README_consigna_original.md](docs/README_consigna_original.md)
- **Diagrama del modelo:** [dw/modelo_estrella.md](dw/modelo_estrella.md)

---

## 1. Contenido del repositorio

```
raw/               datos de origen (un CSV por tabla). No se modifican.
sql/
  01_dimensiones.sql   crea las 6 dimensiones
  02_hechos.sql        crea las 4 tablas de hechos
  03_consultas.sql     calcula los KPI (una tabla por KPI)
run_sql.py         ejecuta los SQL en orden y arma el data warehouse
dw/                salida: un CSV por tabla creada + modelo_estrella.md
docs/              copia de la guía original de la cátedra
```

## 2. Cómo ejecutarlo

Requisitos: Python 3.9 o superior y Git.

```bash
git clone https://github.com/manumenendez04/practica-imond.git
cd practica-imond
python -m venv .venv
```

Activar el entorno virtual:

- **Mac / Linux:** `source .venv/bin/activate`
- **Windows:** `.venv\Scripts\activate`

Instalar dependencias y generar el warehouse:

```bash
pip install -r requirements.txt
python run_sql.py
```

`run_sql.py` hace cuatro cosas:

1. Crea `warehouse.duckdb` desde cero.
2. Ejecuta los archivos de `sql/` en orden alfabético.
3. Exporta cada tabla creada a un CSV en `dw/` (dimensiones, hechos y KPI).
4. Dibuja el modelo estrella en `dw/modelo_estrella.md`.

Como todo se reconstruye desde cero, correrlo dos veces seguidas produce archivos idénticos (todas las consultas de KPI tienen `ORDER BY`).

## 3. Modelo de datos

Es un modelo en **constelación**: varias tablas de hechos que comparten dimensiones. Cada hecho guarda medidas numéricas y apunta a las dimensiones por clave sustituta (`*_key`).

### Dimensiones

| Dimensión | Una fila por... | Filas |
|---|---|---:|
| `dim_date` | día calendario (2024-01-01 a 2025-09-30) | 639 |
| `dim_channel` | canal de venta (ONLINE / OFFLINE) | 2 |
| `dim_store` | tienda física, más la fila `-1` "Sin tienda (online)" | 5 |
| `dim_location` | dirección (con su provincia), más la fila `-1` "Sin ubicación" | 3.830 |
| `dim_customer` | cliente, más la fila `-1` "Desconocido" | 3.472 |
| `dim_product` | producto (incluye categoría y familia) | 2 |

### Tablas de hechos y su grano

| Hecho | Grano (qué es una fila) | Filas |
|---|---|---:|
| `fact_sales_order` | **un pedido** | 11.969 |
| `fact_sales_order_item` | **una línea de pedido** (un producto dentro de un pedido) | 14.573 |
| `fact_web_session` | **una sesión web** | 100.363 |
| `fact_nps_response` | **una respuesta a la encuesta NPS** | 3.083 |

Cada hecho conserva **todas** las filas de su tabla de origen: no se filtra ni se pierde nada al cargarlo. Los filtros de negocio (por ejemplo, qué estados cuentan como venta) se aplican al calcular los KPI, no al cargar el hecho.

`fact_sales_order` y `fact_sales_order_item` tienen granos distintos a propósito: el primero responde preguntas por pedido (ventas, ticket promedio, provincia), el segundo por producto (ranking de productos). Por eso `SUM(line_total)` del detalle coincide con `SUM(subtotal)` del pedido.

### Transformaciones principales

- **Claves sustitutas:** cada dimensión genera su `*_key` con `ROW_NUMBER()`; la clave original se conserva como `*_id`.
- **Clave de fecha:** `date_key` es un entero `AAAAMMDD` calculado con `strftime`.
- **Valores desconocidos:** los `LEFT JOIN` con `COALESCE(key, -1)` asignan la fila `-1` cuando no hay dato (pedidos online sin tienda, sesiones y encuestas anónimas). Así ninguna fila se pierde en el cruce.
- **Aplanado de jerarquías:** categoría y familia quedan dentro de `dim_product`; provincia queda dentro de `dim_location`.
- **Tipos:** los montos se castean a `DECIMAL(12,2)` para evitar errores de redondeo de punto flotante.
- **Medidas derivadas:** `duration_seconds` (diferencia entre fin e inicio de la sesión) y `nps_category` (PROMOTER 9–10, PASSIVE 7–8, DETRACTOR 0–6).
- **Integridad:** todas las claves foráneas están declaradas con `REFERENCES`, y DuckDB las valida al cargar.

## 4. Supuestos y decisiones

- **Qué es una venta:** solo los pedidos `PAID` y `FULFILLED`. Se excluyen `CREATED` (no pagado), `CANCELLED` y `REFUNDED`, según la guía de la cátedra.
- **Ventas con y sin IVA:** la consigna define Ventas como `SUM(total_amount)` (incluye IVA y envío). Se calculan **ambas versiones** en columnas separadas (`ventas_con_iva_y_envio` y `ventas_sin_iva_ni_envio`, y lo mismo para el ticket promedio) porque no está definido cuál prefiere el cliente.
- **Usuarios activos:** la consigna indica contar `customer_id` distintos, o `session_id` si son anónimos. Se publican tres columnas: `usuarios_activos` (solo clientes identificados), `sesiones_anonimas` y `usuarios_activos_con_anonimos` (suma de ambas). Esta última es una aproximación: una misma persona anónima con varias sesiones cuenta varias veces.
- **Provincia de las ventas:** se toma de `shipping_address_id`. En compras en tienda esa dirección es la de la tienda.
- **Canal y tienda:** los pedidos online no tienen tienda y se asocian a la fila `-1` de `dim_store` (7.286 pedidos).
- **Moneda y fechas:** montos en pesos argentinos, fechas en hora de Argentina. Los precios de lista no incluyen IVA.
- **Foto de los datos:** corresponden al 30/09/2025 a las 23:59:59.
- **Medidas no aditivas:** NPS, ticket promedio y usuarios distintos no se pueden sumar ni promediar entre períodos. Por eso los KPI guardan también los conteos que los componen (promotores, detractores, pedidos, etc.) y los usuarios activos mensuales se calculan directamente sobre las sesiones del mes, no sumando los diarios.
- **Pagos y envíos:** las tablas `payment` y `shipment` están en `raw/` pero no se modelaron como hechos.

### Controles realizados

- La suma de `total_amount` de los pedidos PAID y FULFILLED en `fact_sales_order` coincide con la de la tabla de origen: **382.410.636,00**.
- `SUM(line_total)` del detalle coincide con `SUM(subtotal)` del pedido: **309.891.600,00**.
- `kpi_ventas` suma esos mismos totales y **10.998 pedidos**.
- No hay pedidos sin cliente ni sin ubicación en `fact_sales_order`.

## 5. KPI

Se calculan en `sql/03_consultas.sql` con `CREATE TABLE ... AS SELECT`, así que cada uno se exporta como CSV a `dw/`. El tablero solo los lee.

| Tabla KPI | Definición | Nivel de detalle | Filas |
|---|---|---|---:|
| `kpi_ventas` | Ventas = `SUM(total_amount)`; Ticket promedio = ventas / cantidad de pedidos (ambos también sin IVA ni envío). Solo PAID y FULFILLED | día, canal y provincia | 4.058 |
| `kpi_usuarios_activos_diario` | Clientes distintos con sesión, sesiones anónimas y su suma | día | 639 |
| `kpi_usuarios_activos_mensual` | Igual, calculado sobre el mes completo | mes | 21 |
| `kpi_nps` | NPS = (% promotores − % detractores) × 100 | mes y canal | 42 |
| `kpi_ranking_productos` | Unidades y ventas (`line_total`) por producto con `RANK()` | mes y canal | 84 |

## 6. Diccionario de datos

### Dimensiones

**dim_date**

| Columna | Descripción |
|---|---|
| `date_key` | Clave (entero `AAAAMMDD`) |
| `fecha` | Fecha |
| `anio`, `mes`, `dia` | Año, mes y día numéricos |
| `anio_mes` | Período `AAAA-MM` |
| `nombre_mes` | Nombre del mes |
| `dia_semana` | Nombre del día de la semana |

**dim_channel:** `channel_key` (clave), `channel_id` (id de origen), `code` (ONLINE / OFFLINE), `name`.

**dim_store:** `store_key` (clave), `store_id` (id de origen), `name`. La fila `-1` representa "Sin tienda (online)".

**dim_location:** `location_key` (clave), `address_id` (id de origen), `city`, `province`, `province_code`, `postal_code`. La fila `-1` representa "Sin ubicación".

**dim_customer:** `customer_key` (clave), `customer_id` (id de origen), `first_name`, `last_name`, `status` (`I` = dio de baja su cuenta). La fila `-1` representa "Desconocido" (anónimo).

**dim_product:** `product_key` (clave), `product_id` (id de origen), `name`, `category`, `family`, `list_price` (precio de lista sin IVA).

### Hechos

**fact_sales_order** (un pedido): `order_id` (PK), `date_key`, `customer_key`, `channel_key`, `store_key`, `location_key` (FK a las dimensiones), `status`, y las medidas `subtotal` (suma de líneas), `tax_amount` (IVA 21 %), `shipping_fee` (envío) y `total_amount` (subtotal + IVA + envío).

**fact_sales_order_item** (una línea de pedido): `order_item_id` (PK), `order_id` (FK al pedido), `date_key`, `product_key`, `channel_key`, `status`, y las medidas `quantity`, `unit_price`, `discount_amount` y `line_total` (cantidad × precio − descuento).

**fact_web_session** (una sesión): `session_id` (PK), `date_key`, `customer_key`, `source` (ads / direct / referral / organic), `device`, `duration_seconds`.

**fact_nps_response** (una respuesta): `nps_id` (PK), `date_key`, `customer_key`, `channel_key`, `score` (0 a 10), `nps_category` (PROMOTER / PASSIVE / DETRACTOR).

### Tablas de KPI

| Tabla | Columnas |
|---|---|
| `kpi_ventas` | `fecha`, `anio_mes`, `canal`, `provincia`, `pedidos`, `ventas_sin_iva_ni_envio`, `ventas_con_iva_y_envio`, `ticket_promedio_sin_iva`, `ticket_promedio_con_iva` |
| `kpi_usuarios_activos_diario` | `fecha`, `anio_mes`, `usuarios_activos`, `sesiones_anonimas`, `usuarios_activos_con_anonimos`, `sesiones` |
| `kpi_usuarios_activos_mensual` | `anio_mes`, `usuarios_activos`, `sesiones_anonimas`, `usuarios_activos_con_anonimos`, `sesiones` |
| `kpi_nps` | `anio_mes`, `canal`, `respuestas`, `promotores`, `pasivos`, `detractores`, `nps` |
| `kpi_ranking_productos` | `anio_mes`, `canal`, `producto`, `categoria`, `unidades`, `ventas`, `ranking` |

### Tablas de origen (`raw/`)

| Tabla | Qué guarda |
|---|---|
| `channel` | Los 2 canales de venta |
| `province` | Las 4 provincias donde opera la empresa |
| `product_category` | Categorías de producto |
| `product` | Los 2 productos |
| `store` | Las tiendas físicas |
| `customer` | Los clientes |
| `address` | Direcciones de clientes y tiendas |
| `sales_order` | Los pedidos |
| `sales_order_item` | Los productos de cada pedido |
| `payment` | El pago de cada pedido |
| `shipment` | Los envíos por correo |
| `web_session` | Las visitas a la web |
| `nps_response` | Respuestas a la encuesta de satisfacción |

## 7. Tablero

*Se completa al entregar el tablero (herramienta, enlace y captura).*
