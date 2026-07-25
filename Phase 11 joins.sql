--- PHASE 11: COMPLEX JOINS & ANALYTICS
  
SET DEFINE OFF;

--- QUERY 1: Top 10 best-selling customers, by total spend
--   (joins CUSTOMER -> SALES_ORDER -> SALES_ORDER_DETAIL, 3 tables)
   
SELECT
    c.CUSTOMER_NAME,
    c.CUSTOMER_TYPE,
    COUNT(DISTINCT so.SO_ID) AS TOTAL_ORDERS,
    ROUND(SUM(sod.QUANTITY * sod.UNIT_PRICE), 2) AS TOTAL_SPEND
FROM HRDB.CUSTOMER c
JOIN HRDB.SALES_ORDER so ON so.CUSTOMER_ID = c.CUSTOMER_ID
JOIN HRDB.SALES_ORDER_DETAIL sod ON sod.SO_ID = so.SO_ID
GROUP BY c.CUSTOMER_NAME, c.CUSTOMER_TYPE
ORDER BY TOTAL_SPEND DESC
FETCH FIRST 10 ROWS ONLY;

--- QUERY 2: Category-wise stock value distribution
--   (CATEGORY -> PRODUCT -> STOCK, with percentage of total)
   
SELECT
    cat.CATEGORY_NAME,
    COUNT(DISTINCT p.PRODUCT_ID) AS PRODUCT_COUNT,
    ROUND(SUM(s.QUANTITY_ON_HAND * p.UNIT_PRICE), 2) AS CATEGORY_STOCK_VALUE,
    ROUND(
        SUM(s.QUANTITY_ON_HAND * p.UNIT_PRICE) * 100.0 /
        SUM(SUM(s.QUANTITY_ON_HAND * p.UNIT_PRICE)) OVER (), 2
    ) AS PCT_OF_TOTAL_VALUE
FROM HRDB.CATEGORY cat
JOIN HRDB.PRODUCT p ON p.CATEGORY_ID = cat.CATEGORY_ID
JOIN HRDB.STOCK s ON s.PRODUCT_ID = p.PRODUCT_ID
GROUP BY cat.CATEGORY_NAME
ORDER BY CATEGORY_STOCK_VALUE DESC;


--- QUERY 3: Rank products by movement WITHIN their category
--   (window function - RANK() PARTITION BY, on top of a join)
   
SELECT
    cat.CATEGORY_NAME,
    p.PRODUCT_NAME,
    v.TOTAL_ISSUED,
    RANK() OVER (PARTITION BY cat.CATEGORY_NAME ORDER BY v.TOTAL_ISSUED DESC) AS RANK_IN_CATEGORY
FROM HRDB.V_PRODUCT_MOVEMENT v
JOIN HRDB.PRODUCT p ON p.PRODUCT_ID = v.PRODUCT_ID
JOIN HRDB.CATEGORY cat ON cat.CATEGORY_ID = p.CATEGORY_ID
ORDER BY cat.CATEGORY_NAME, RANK_IN_CATEGORY;


--- QUERY 4: Suppliers who are ALSO the default supplier for a product
--   that currently has an OPEN low-stock alert (correlated subquery +
--   multi-table join - "which suppliers do I need to call today")

SELECT DISTINCT
    sup.SUPPLIER_NAME,
    sup.PHONE,
    sup.CITY,
    (SELECT COUNT(*) FROM HRDB.LOW_STOCK_ALERT a
     JOIN HRDB.PRODUCT p2 ON p2.PRODUCT_ID = a.PRODUCT_ID
     WHERE p2.DEFAULT_SUPPLIER_ID = sup.SUPPLIER_ID AND a.STATUS = 'OPEN') AS URGENT_PRODUCTS
FROM HRDB.SUPPLIER sup
WHERE EXISTS (
    SELECT 1
    FROM HRDB.PRODUCT p
    JOIN HRDB.LOW_STOCK_ALERT a ON a.PRODUCT_ID = p.PRODUCT_ID
    WHERE p.DEFAULT_SUPPLIER_ID = sup.SUPPLIER_ID
    AND a.STATUS = 'OPEN'
)
ORDER BY URGENT_PRODUCTS DESC;


--- QUERY 5: Warehouse-to-warehouse comparison - sales value vs stock
--   value (are we holding stock where the demand actually is?)
   
SELECT
    w.WAREHOUSE_NAME,
    NVL(stock_data.STOCK_VALUE, 0) AS CURRENT_STOCK_VALUE,
    NVL(sales_data.SALES_VALUE, 0) AS TOTAL_SALES_VALUE,
    CASE WHEN NVL(sales_data.SALES_VALUE,0) = 0 THEN NULL
         ELSE ROUND(NVL(stock_data.STOCK_VALUE,0) / sales_data.SALES_VALUE, 2)
    END AS STOCK_TO_SALES_RATIO
FROM HRDB.WAREHOUSE w
LEFT JOIN (
    SELECT WAREHOUSE_ID, SUM(TOTAL_AMOUNT) AS SALES_VALUE
    FROM HRDB.SALES_ORDER
    WHERE STATUS != 'CANCELLED'
    GROUP BY WAREHOUSE_ID
) sales_data ON sales_data.WAREHOUSE_ID = w.WAREHOUSE_ID
LEFT JOIN (
    SELECT s.WAREHOUSE_ID, SUM(s.QUANTITY_ON_HAND * p.UNIT_PRICE) AS STOCK_VALUE
    FROM HRDB.STOCK s JOIN HRDB.PRODUCT p ON p.PRODUCT_ID = s.PRODUCT_ID
    GROUP BY s.WAREHOUSE_ID
) stock_data ON stock_data.WAREHOUSE_ID = w.WAREHOUSE_ID
ORDER BY TOTAL_SALES_VALUE DESC;


--- QUERY 6: Monthly purchase vs sales trend (any year - EXTRACT-based,/* ============================================================================
   PHASE 11: COMPLEX JOINS & ANALYTICS
   ============================================================================ */

SET DEFINE OFF;


/* ----------------------------------------------------------------------
   QUERY 1: Top 10 best-selling customers, by total spend
   (joins CUSTOMER -> SALES_ORDER -> SALES_ORDER_DETAIL, 3 tables)
   ---------------------------------------------------------------------- */
SELECT
    c.CUSTOMER_NAME,
    c.CUSTOMER_TYPE,
    COUNT(DISTINCT so.SO_ID) AS TOTAL_ORDERS,
    ROUND(SUM(sod.QUANTITY * sod.UNIT_PRICE), 2) AS TOTAL_SPEND
FROM HRDB.CUSTOMER c
JOIN HRDB.SALES_ORDER so ON so.CUSTOMER_ID = c.CUSTOMER_ID
JOIN HRDB.SALES_ORDER_DETAIL sod ON sod.SO_ID = so.SO_ID
GROUP BY c.CUSTOMER_NAME, c.CUSTOMER_TYPE
ORDER BY TOTAL_SPEND DESC
FETCH FIRST 10 ROWS ONLY;


/* ----------------------------------------------------------------------
   QUERY 2: Category-wise stock value distribution
   (CATEGORY -> PRODUCT -> STOCK, with percentage of total)
   ---------------------------------------------------------------------- */
SELECT
    cat.CATEGORY_NAME,
    COUNT(DISTINCT p.PRODUCT_ID) AS PRODUCT_COUNT,
    ROUND(SUM(s.QUANTITY_ON_HAND * p.UNIT_PRICE), 2) AS CATEGORY_STOCK_VALUE,
    ROUND(
        SUM(s.QUANTITY_ON_HAND * p.UNIT_PRICE) * 100.0 /
        SUM(SUM(s.QUANTITY_ON_HAND * p.UNIT_PRICE)) OVER (), 2
    ) AS PCT_OF_TOTAL_VALUE
FROM HRDB.CATEGORY cat
JOIN HRDB.PRODUCT p ON p.CATEGORY_ID = cat.CATEGORY_ID
JOIN HRDB.STOCK s ON s.PRODUCT_ID = p.PRODUCT_ID
GROUP BY cat.CATEGORY_NAME
ORDER BY CATEGORY_STOCK_VALUE DESC;


/* ----------------------------------------------------------------------
   QUERY 3: Rank products by movement WITHIN their category
   (window function - RANK() PARTITION BY, on top of a join)
   ---------------------------------------------------------------------- */
SELECT
    cat.CATEGORY_NAME,
    p.PRODUCT_NAME,
    v.TOTAL_ISSUED,
    RANK() OVER (PARTITION BY cat.CATEGORY_NAME ORDER BY v.TOTAL_ISSUED DESC) AS RANK_IN_CATEGORY
FROM HRDB.V_PRODUCT_MOVEMENT v
JOIN HRDB.PRODUCT p ON p.PRODUCT_ID = v.PRODUCT_ID
JOIN HRDB.CATEGORY cat ON cat.CATEGORY_ID = p.CATEGORY_ID
ORDER BY cat.CATEGORY_NAME, RANK_IN_CATEGORY;


/* ----------------------------------------------------------------------
   QUERY 4: Suppliers who are ALSO the default supplier for a product
   that currently has an OPEN low-stock alert (correlated subquery +
   multi-table join - "which suppliers do I need to call today")
   ---------------------------------------------------------------------- */
SELECT DISTINCT
    sup.SUPPLIER_NAME,
    sup.PHONE,
    sup.CITY,
    (SELECT COUNT(*) FROM HRDB.LOW_STOCK_ALERT a
     JOIN HRDB.PRODUCT p2 ON p2.PRODUCT_ID = a.PRODUCT_ID
     WHERE p2.DEFAULT_SUPPLIER_ID = sup.SUPPLIER_ID AND a.STATUS = 'OPEN') AS URGENT_PRODUCTS
FROM HRDB.SUPPLIER sup
WHERE EXISTS (
    SELECT 1
    FROM HRDB.PRODUCT p
    JOIN HRDB.LOW_STOCK_ALERT a ON a.PRODUCT_ID = p.PRODUCT_ID
    WHERE p.DEFAULT_SUPPLIER_ID = sup.SUPPLIER_ID
    AND a.STATUS = 'OPEN'
)
ORDER BY URGENT_PRODUCTS DESC;


/* ----------------------------------------------------------------------
   QUERY 5: Warehouse-to-warehouse comparison - sales value vs stock
   value (are we holding stock where the demand actually is?)
   ---------------------------------------------------------------------- */
SELECT
    w.WAREHOUSE_NAME,
    NVL(stock_data.STOCK_VALUE, 0) AS CURRENT_STOCK_VALUE,
    NVL(sales_data.SALES_VALUE, 0) AS TOTAL_SALES_VALUE,
    CASE WHEN NVL(sales_data.SALES_VALUE,0) = 0 THEN NULL
         ELSE ROUND(NVL(stock_data.STOCK_VALUE,0) / sales_data.SALES_VALUE, 2)
    END AS STOCK_TO_SALES_RATIO
FROM HRDB.WAREHOUSE w
LEFT JOIN (
    SELECT WAREHOUSE_ID, SUM(TOTAL_AMOUNT) AS SALES_VALUE
    FROM HRDB.SALES_ORDER
    WHERE STATUS != 'CANCELLED'
    GROUP BY WAREHOUSE_ID
) sales_data ON sales_data.WAREHOUSE_ID = w.WAREHOUSE_ID
LEFT JOIN (
    SELECT s.WAREHOUSE_ID, SUM(s.QUANTITY_ON_HAND * p.UNIT_PRICE) AS STOCK_VALUE
    FROM HRDB.STOCK s JOIN HRDB.PRODUCT p ON p.PRODUCT_ID = s.PRODUCT_ID
    GROUP BY s.WAREHOUSE_ID
) stock_data ON stock_data.WAREHOUSE_ID = w.WAREHOUSE_ID
ORDER BY TOTAL_SALES_VALUE DESC;


/* ----------------------------------------------------------------------
   QUERY 6: Monthly purchase vs sales trend (any year - EXTRACT-based,
   no SYSDATE dependency, reusable for any historical month)
   ---------------------------------------------------------------------- */
SELECT
    EXTRACT(YEAR FROM po.ORDER_DATE)  AS YR,
    EXTRACT(MONTH FROM po.ORDER_DATE) AS MON,
    SUM(po.TOTAL_AMOUNT) AS TOTAL_PURCHASES,
    (SELECT SUM(so.TOTAL_AMOUNT) FROM HRDB.SALES_ORDER so
     WHERE EXTRACT(YEAR FROM so.ORDER_DATE) = EXTRACT(YEAR FROM po.ORDER_DATE)
     AND EXTRACT(MONTH FROM so.ORDER_DATE) = EXTRACT(MONTH FROM po.ORDER_DATE)) AS TOTAL_SALES
FROM HRDB.PURCHASE_ORDER po
WHERE po.STATUS != 'CANCELLED'
GROUP BY EXTRACT(YEAR FROM po.ORDER_DATE), EXTRACT(MONTH FROM po.ORDER_DATE)
ORDER BY YR, MON;
--   no SYSDATE dependency, reusable for any historical month)
   