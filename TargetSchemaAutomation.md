# Target Schema Automation

## Objective

Analyze `[superstore].[dbo].[sales]` using only the source table data, derive a normalized target model under the `store` schema, create the tables, and validate the result.

## Source-Only Analysis Summary

The source table was analyzed directly with SQL Server queries against `[superstore].[dbo].[sales]`.

### Cardinality Findings

| Metric | Value |
| --- | ---: |
| Source rows | 9,800 |
| Distinct orders | 4,922 |
| Distinct customers | 793 |
| Distinct source product IDs | 1,861 |
| Distinct product variants by `(Product_ID, Product_Name, Category, Sub_Category)` | 1,893 |
| Distinct postal codes | 627 |
| Distinct locations by `(Country, Region, State, City, Postal_Code)` | 628 |

### Functional Dependency Checks

| Dependency tested | Violations | Result |
| --- | ---: | --- |
| `Customer_ID -> Customer_Name, Segment` | 0 | Safe customer natural key |
| `Order_ID -> Order_Date, Ship_Date, Ship_Mode, Customer_ID` | 0 | Safe order header natural key |
| `Postal_Code -> City, State, Country, Region` | 1 | Not safe as a standalone location key |
| `Product_ID -> Product_Name, Category, Sub_Category` | 32 | Not safe as a standalone product key |

### Exceptions That Drove the Design

1. `Postal_Code = 92024` maps to both `Encinitas, California` and `San Diego, California`, so postal code alone cannot identify a location.
2. `Product_ID` is not stable enough to identify a single product description. Example: `FUR-BO-10002213` maps to both `DMI Eclipse Executive Suite Bookcases` and `Sauder Forest Hills Library, Woodland Oak Finish`.
3. `Order_ID` behaves like a clean order header key, while `Row_ID` is unique at the line-item level.

## Target Model Chosen

Based on those findings, the source table was decomposed into five tables:

### `store.customer`

One row per customer.

Columns:

- `customer_key` as surrogate primary key
- `source_customer_id` as unique business key
- `customer_name`
- `segment`

### `store.location`

One row per distinct `(country, region, state, city, postal_code)` combination.

Columns:

- `location_key` as surrogate primary key
- `country`
- `region`
- `state`
- `city`
- `postal_code`

Reason: postal code alone was not unique in the source.

### `store.product`

One row per distinct `(source_product_id, product_name, category, sub_category)` combination.

Columns:

- `product_key` as surrogate primary key
- `source_product_id`
- `product_name`
- `category`
- `sub_category`

Reason: source product ID alone was not stable in the source data, so the target preserves product variants instead of forcing a guessed canonical product.

### `store.order_header`

One row per order.

Columns:

- `order_id` as primary key
- `order_date`
- `ship_date`
- `ship_mode`
- `customer_key` as foreign key to `store.customer`
- `location_key` as foreign key to `store.location`

### `store.order_line`

One row per source sale row.

Columns:

- `source_row_id` as primary key
- `order_id` as foreign key to `store.order_header`
- `product_key` as foreign key to `store.product`
- `sales_amount`

## Relationships Identified

1. `store.customer (1) -> (many) store.order_header`
2. `store.location (1) -> (many) store.order_header`
3. `store.order_header (1) -> (many) store.order_line`
4. `store.product (1) -> (many) store.order_line`

This produces a normalized structure where order-level attributes live once in `store.order_header` and product/customer/location attributes are separated into their own entities.

## Implementation Steps Executed

### 1. Verified the source table and measured source dependencies

The source was inspected with aggregate queries to test whether candidate business keys were stable.

### 2. Reused the existing `store` schema

The database already contained a `store` schema, but it did not contain any `store.*` tables. The new tables were created there.

### 3. Created the target tables

The following tables were created:

- `store.customer`
- `store.location`
- `store.product`
- `store.order_header`
- `store.order_line`

Primary keys, unique constraints, foreign keys, and supporting indexes were added as part of creation.

### 4. Loaded the target tables from `dbo.sales`

Load logic used only distinct source rows and verified dependencies:

- customers loaded from grouped `Customer_ID`
- locations loaded from distinct location attribute combinations
- products loaded from distinct product attribute combinations
- order headers loaded from distinct order-level combinations
- order lines loaded one-for-one from source `Row_ID`

### 5. Validated the result

Final row counts matched the expected grains.

| Target table | Row count |
| --- | ---: |
| `store.customer` | 793 |
| `store.location` | 628 |
| `store.product` | 1,893 |
| `store.order_header` | 4,922 |
| `store.order_line` | 9,800 |

## Source Analysis SQL Used Before the Build Script

```sql
SET NOCOUNT ON;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT Order_ID) AS distinct_orders,
    COUNT(DISTINCT Customer_ID) AS distinct_customers,
    COUNT(DISTINCT Product_ID) AS distinct_products,
    COUNT(DISTINCT Postal_Code) AS distinct_postal_codes
FROM dbo.sales;

SELECT COUNT(*) AS violating_customer_ids
FROM (
    SELECT Customer_ID
    FROM dbo.sales
    GROUP BY Customer_ID
    HAVING COUNT(DISTINCT Customer_Name) > 1
        OR COUNT(DISTINCT Segment) > 1
) AS customer_fd;

SELECT COUNT(*) AS violating_product_ids
FROM (
    SELECT Product_ID
    FROM dbo.sales
    GROUP BY Product_ID
    HAVING COUNT(DISTINCT Product_Name) > 1
        OR COUNT(DISTINCT Category) > 1
        OR COUNT(DISTINCT Sub_Category) > 1
) AS product_fd;

SELECT COUNT(*) AS violating_orders
FROM (
    SELECT Order_ID
    FROM dbo.sales
    GROUP BY Order_ID
    HAVING COUNT(DISTINCT Order_Date) > 1
        OR COUNT(DISTINCT Ship_Date) > 1
        OR COUNT(DISTINCT Ship_Mode) > 1
        OR COUNT(DISTINCT Customer_ID) > 1
) AS order_fd;

SELECT COUNT(*) AS violating_postal_codes
FROM (
    SELECT Postal_Code
    FROM dbo.sales
    GROUP BY Postal_Code
    HAVING COUNT(DISTINCT City) > 1
        OR COUNT(DISTINCT State) > 1
        OR COUNT(DISTINCT Country) > 1
        OR COUNT(DISTINCT Region) > 1
) AS postal_fd;

SELECT
    COUNT(*) AS distinct_locations
FROM (
    SELECT DISTINCT Country, Region, State, City, Postal_Code
    FROM dbo.sales
) AS location_grain;

SELECT
    COUNT(*) AS distinct_products_composite
FROM (
    SELECT DISTINCT Product_ID, Product_Name, Category, Sub_Category
    FROM dbo.sales
) AS product_grain;

SELECT
    COUNT(*) AS distinct_order_headers
FROM (
    SELECT DISTINCT Order_ID, Order_Date, Ship_Date, Ship_Mode, Customer_ID, Country, Region, State, City, Postal_Code
    FROM dbo.sales
) AS order_header_grain;

SELECT Postal_Code, City, State, Country, Region
FROM dbo.sales
WHERE Postal_Code = 92024
GROUP BY Postal_Code, City, State, Country, Region
ORDER BY City;

SELECT Product_ID, Product_Name, COUNT(*) AS row_count
FROM dbo.sales
WHERE Product_ID IN (
    SELECT Product_ID
    FROM dbo.sales
    GROUP BY Product_ID
    HAVING COUNT(DISTINCT Product_Name) > 1
)
GROUP BY Product_ID, Product_Name
ORDER BY Product_ID, row_count DESC;
```

## DDL Shape Applied

```sql
CREATE TABLE store.customer (
    customer_key INT IDENTITY(1,1) PRIMARY KEY,
    source_customer_id NVARCHAR(50) NOT NULL UNIQUE,
    customer_name NVARCHAR(50) NOT NULL,
    segment NVARCHAR(50) NOT NULL
);

CREATE TABLE store.location (
    location_key INT IDENTITY(1,1) PRIMARY KEY,
    country NVARCHAR(50) NOT NULL,
    region NVARCHAR(50) NOT NULL,
    state NVARCHAR(50) NOT NULL,
    city NVARCHAR(50) NOT NULL,
    postal_code INT NULL,
    UNIQUE (country, region, state, city, postal_code)
);

CREATE TABLE store.product (
    product_key INT IDENTITY(1,1) PRIMARY KEY,
    source_product_id NVARCHAR(50) NOT NULL,
    product_name NVARCHAR(150) NOT NULL,
    category NVARCHAR(50) NOT NULL,
    sub_category NVARCHAR(50) NOT NULL,
    UNIQUE (source_product_id, product_name, category, sub_category)
);

CREATE TABLE store.order_header (
    order_id NVARCHAR(50) PRIMARY KEY,
    order_date DATE NOT NULL,
    ship_date DATE NOT NULL,
    ship_mode NVARCHAR(50) NOT NULL,
    customer_key INT NOT NULL REFERENCES store.customer(customer_key),
    location_key INT NOT NULL REFERENCES store.location(location_key)
);

CREATE TABLE store.order_line (
    source_row_id SMALLINT PRIMARY KEY,
    order_id NVARCHAR(50) NOT NULL REFERENCES store.order_header(order_id),
    product_key INT NOT NULL REFERENCES store.product(product_key),
    sales_amount DECIMAL(19,2) NOT NULL
);
```

## Outcome

The `dbo.sales` source table was analyzed directly and decomposed into a normalized `store` target schema with enforced relationships and loaded data. The design intentionally preserves source data anomalies instead of inventing undocumented cleanup rules.