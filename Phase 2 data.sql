SET SERVEROUTPUT ON;

SET DEFINE OFF;

--- STEP 1: CATEGORIES (static list - small, doesn't need randomization)
   
INSERT INTO HRDB.CATEGORY (CATEGORY_NAME, DESCRIPTION) VALUES ('Raw Metals', 'Steel, aluminum, copper stock');
INSERT INTO HRDB.CATEGORY (CATEGORY_NAME, DESCRIPTION) VALUES ('Textiles', 'Cotton, yarn, fabric rolls');
INSERT INTO HRDB.CATEGORY (CATEGORY_NAME, DESCRIPTION) VALUES ('Packaging Materials', 'Boxes, wrapping, containers');
INSERT INTO HRDB.CATEGORY (CATEGORY_NAME, DESCRIPTION) VALUES ('Chemicals', 'Industrial and processing chemicals');
INSERT INTO HRDB.CATEGORY (CATEGORY_NAME, DESCRIPTION) VALUES ('Electronics Components', 'Circuit boards, sensors, wiring');
INSERT INTO HRDB.CATEGORY (CATEGORY_NAME, DESCRIPTION) VALUES ('Plastics', 'Resins, sheets, molded parts');
INSERT INTO HRDB.CATEGORY (CATEGORY_NAME, DESCRIPTION) VALUES ('Machinery Parts', 'Spare parts and tools');
INSERT INTO HRDB.CATEGORY (CATEGORY_NAME, DESCRIPTION) VALUES ('Food Grade Materials', 'Raw ingredients for food processing');
INSERT INTO HRDB.CATEGORY (CATEGORY_NAME, DESCRIPTION) VALUES ('Paper & Printing', 'Paper rolls, ink, printing supplies');
INSERT INTO HRDB.CATEGORY (CATEGORY_NAME, DESCRIPTION) VALUES ('Construction Materials', 'Cement, tiles, fittings');
COMMIT;

--- STEP 2: WAREHOUSES (static list - a handful of real locations)
   
INSERT INTO HRDB.WAREHOUSE (WAREHOUSE_NAME, LOCATION_ADDRESS, CITY, CAPACITY_UNITS, MANAGER_NAME, PHONE) VALUES
('Main Distribution Center', 'Industrial Estate Phase 1', 'Faisalabad', 500000, 'Tariq Mehmood', '03001234567');
INSERT INTO HRDB.WAREHOUSE (WAREHOUSE_NAME, LOCATION_ADDRESS, CITY, CAPACITY_UNITS, MANAGER_NAME, PHONE) VALUES
('Lahore Regional Warehouse', 'Sundar Industrial Estate', 'Lahore', 350000, 'Bilal Sheikh', '03011234567');
INSERT INTO HRDB.WAREHOUSE (WAREHOUSE_NAME, LOCATION_ADDRESS, CITY, CAPACITY_UNITS, MANAGER_NAME, PHONE) VALUES
('Karachi Port Warehouse', 'SITE Industrial Area', 'Karachi', 600000, 'Fahad Iqbal', '03021234567');
INSERT INTO HRDB.WAREHOUSE (WAREHOUSE_NAME, LOCATION_ADDRESS, CITY, CAPACITY_UNITS, MANAGER_NAME, PHONE) VALUES
('Islamabad Storage Hub', 'I-9 Industrial Sector', 'Islamabad', 200000, 'Ahmed Raza', '03031234567');
INSERT INTO HRDB.WAREHOUSE (WAREHOUSE_NAME, LOCATION_ADDRESS, CITY, CAPACITY_UNITS, MANAGER_NAME, PHONE) VALUES
('Multan Warehouse', 'Multan Industrial Zone', 'Multan', 150000, 'Kamran Butt', '03041234567');
COMMIT;

--- STEP 3: SUPPLIERS (80 rows, varied via random pick from name/city lists)

DECLARE
    TYPE t_list IS TABLE OF VARCHAR2(100);
    v_company_prefix t_list := t_list('Al-Noor','Metro','National','Continental','Star','Prime','United','Zenith','Crown','Horizon');
    v_company_suffix t_list := t_list('Traders','Industries','Enterprises','Suppliers Pvt Ltd','Corporation','Trading Co','International');
    v_cities         t_list := t_list('Faisalabad','Lahore','Karachi','Sialkot','Gujranwala','Multan','Islamabad');
    v_countries      t_list := t_list('Pakistan','China','UAE','Turkey','India');
 
    -- Scalar variables to hold picked values (collection .COUNT can't be
    -- used directly inside a SQL INSERT statement)
    v_prefix_pick   VARCHAR2(100);
    v_suffix_pick   VARCHAR2(100);
    v_city_pick     VARCHAR2(100);
    v_country_pick  VARCHAR2(100);
BEGIN
    FOR i IN 1..80 LOOP
        v_prefix_pick  := v_company_prefix(TRUNC(DBMS_RANDOM.VALUE(1, v_company_prefix.COUNT+1)));
        v_suffix_pick  := v_company_suffix(TRUNC(DBMS_RANDOM.VALUE(1, v_company_suffix.COUNT+1)));
        v_city_pick    := v_cities(TRUNC(DBMS_RANDOM.VALUE(1, v_cities.COUNT+1)));
        v_country_pick := v_countries(TRUNC(DBMS_RANDOM.VALUE(1, v_countries.COUNT+1)));
 
        INSERT INTO HRDB.SUPPLIER (
            SUPPLIER_NAME, CONTACT_PERSON, PHONE, EMAIL, ADDRESS, CITY, COUNTRY,
            SUPPLIER_RATING, PAYMENT_TERMS
        ) VALUES (
            v_prefix_pick || ' ' || v_suffix_pick,
            'Contact Person ' || i,
            '0300' || LPAD(i, 7, '0'),
            'supplier' || i || '@example.com',
            'Street ' || i || ', Industrial Area',
            v_city_pick,
            v_country_pick,
            ROUND(DBMS_RANDOM.VALUE(2.5, 5), 1),
            CASE MOD(i,3) WHEN 0 THEN 'Net 30' WHEN 1 THEN 'COD' ELSE 'Net 60' END
        );
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('80 suppliers inserted.');
END;
/

--- STEP 4: PRODUCTS (600 rows - references CATEGORY and SUPPLIER)
   
DECLARE
    TYPE t_num_tab IS TABLE OF NUMBER;
    v_categories t_num_tab;
    v_suppliers  t_num_tab;
 
    TYPE t_list IS TABLE OF VARCHAR2(50);
    v_material_names t_list := t_list('Steel Sheet','Cotton Roll','Cardboard Box','Industrial Adhesive',
        'Circuit Board','Plastic Resin','Ball Bearing','Sugar (Raw)','Paper Roll','Cement Bag',
        'Copper Wire','Aluminum Rod','Yarn Spool','Packaging Tape','Sensor Module');
    TYPE t_uom_list IS TABLE OF VARCHAR2(20);
    v_uom t_uom_list := t_uom_list('KG','LITER','PIECE','BOX','METER','ROLL','BAG');
 
    -- Scalar variables to hold picked values
    v_category_pick NUMBER;
    v_supplier_pick NUMBER;
    v_name_pick     VARCHAR2(50);
    v_uom_pick      VARCHAR2(20);
BEGIN
    SELECT CATEGORY_ID BULK COLLECT INTO v_categories FROM HRDB.CATEGORY;
    SELECT SUPPLIER_ID BULK COLLECT INTO v_suppliers  FROM HRDB.SUPPLIER;
 
    FOR i IN 1..600 LOOP
        v_category_pick := v_categories(TRUNC(DBMS_RANDOM.VALUE(1, v_categories.COUNT+1)));
        v_supplier_pick := v_suppliers(TRUNC(DBMS_RANDOM.VALUE(1, v_suppliers.COUNT+1)));
        v_name_pick      := v_material_names(TRUNC(DBMS_RANDOM.VALUE(1, v_material_names.COUNT+1)));
        v_uom_pick       := v_uom(TRUNC(DBMS_RANDOM.VALUE(1, v_uom.COUNT+1)));
 
        INSERT INTO HRDB.PRODUCT (
            PRODUCT_CODE, PRODUCT_NAME, CATEGORY_ID, DEFAULT_SUPPLIER_ID,
            UNIT_OF_MEASURE, UNIT_PRICE, REORDER_LEVEL, REORDER_QTY
        ) VALUES (
            'SKU-' || LPAD(i, 6, '0'),
            v_name_pick || ' - Type ' || i,
            v_category_pick,
            v_supplier_pick,
            v_uom_pick,
            ROUND(DBMS_RANDOM.VALUE(50, 5000), 2),
            TRUNC(DBMS_RANDOM.VALUE(20, 200)),
            TRUNC(DBMS_RANDOM.VALUE(100, 1000))
        );
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('600 products inserted.');
END;
/

--- STEP 5: CUSTOMERS (300 rows - distributors/retailers)
   
DECLARE
    TYPE t_list IS TABLE OF VARCHAR2(100);
    v_prefix t_list := t_list('City','Metro','Fast','Elite','Prime','Royal','Grand','United','National','Modern');
    v_suffix t_list := t_list('Distributors','Traders','Retail Store','Wholesale Mart','Enterprises','Mart','Agencies');
    v_cities t_list := t_list('Faisalabad','Lahore','Karachi','Sialkot','Multan','Peshawar','Quetta','Islamabad');
    v_types  t_list := t_list('DISTRIBUTOR','RETAILER','WHOLESALER');
 
    -- Scalar variables to hold picked values
    v_prefix_pick VARCHAR2(100);
    v_suffix_pick VARCHAR2(100);
    v_city_pick   VARCHAR2(100);
    v_type_pick   VARCHAR2(100);
BEGIN
    FOR i IN 1..300 LOOP
        v_prefix_pick := v_prefix(TRUNC(DBMS_RANDOM.VALUE(1, v_prefix.COUNT+1)));
        v_suffix_pick := v_suffix(TRUNC(DBMS_RANDOM.VALUE(1, v_suffix.COUNT+1)));
        v_city_pick   := v_cities(TRUNC(DBMS_RANDOM.VALUE(1, v_cities.COUNT+1)));
        v_type_pick   := v_types(TRUNC(DBMS_RANDOM.VALUE(1, v_types.COUNT+1)));
 
        INSERT INTO HRDB.CUSTOMER (
            CUSTOMER_NAME, CUSTOMER_TYPE, CONTACT_PERSON, PHONE, CITY, CREDIT_LIMIT
        ) VALUES (
            v_prefix_pick || ' ' || v_suffix_pick,
            v_type_pick,
            'Manager ' || i,
            '0333' || LPAD(i, 7, '0'),
            v_city_pick,
            ROUND(DBMS_RANDOM.VALUE(50000, 2000000), 2)
        );
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('300 customers inserted.');
END;
/

--- STEP 6: STOCK - one row per Product x Warehouse combination
   -- (600 products x 5 warehouses = 3000 rows)
   
INSERT INTO HRDB.STOCK (PRODUCT_ID, WAREHOUSE_ID, QUANTITY_ON_HAND, LAST_UPDATED)
SELECT
    p.PRODUCT_ID,
    w.WAREHOUSE_ID,
    TRUNC(DBMS_RANDOM.VALUE(0, 1000)),
    SYSDATE
FROM HRDB.PRODUCT p
CROSS JOIN HRDB.WAREHOUSE w;
 
COMMIT;

--- STEP 7: STOCK_TRANSACTION - 1,000,000 rows (the big history table)
   
DECLARE
    v_max_product   NUMBER;
    v_max_warehouse NUMBER;
BEGIN
    SELECT MAX(PRODUCT_ID)   INTO v_max_product   FROM HRDB.PRODUCT;
    SELECT MAX(WAREHOUSE_ID) INTO v_max_warehouse FROM HRDB.WAREHOUSE;
 
    INSERT INTO HRDB.STOCK_TRANSACTION (
        PRODUCT_ID, WAREHOUSE_ID, TRANSACTION_TYPE, QUANTITY,
        TRANSACTION_DATE, REFERENCE_TYPE, UNIT_PRICE
    )
    SELECT
        TRUNC(DBMS_RANDOM.VALUE(1, v_max_product + 1)),
        TRUNC(DBMS_RANDOM.VALUE(1, v_max_warehouse + 1)),
        CASE
            WHEN DBMS_RANDOM.VALUE < 0.50 THEN 'IN'
            WHEN DBMS_RANDOM.VALUE < 0.90 THEN 'OUT'
            ELSE 'ADJUST'
        END,
        TRUNC(DBMS_RANDOM.VALUE(5, 500)),
        DATE '2021-01-01' + TRUNC(DBMS_RANDOM.VALUE(0, 1826)),   -- spread across ~5 years
        CASE WHEN MOD(TRUNC(DBMS_RANDOM.VALUE(1,3)),2)=0 THEN 'PURCHASE_ORDER' ELSE 'SALES_ORDER' END,
        ROUND(DBMS_RANDOM.VALUE(50, 5000), 2)
    FROM (SELECT LEVEL AS n FROM DUAL CONNECT BY LEVEL <= 1000) g1
    CROSS JOIN (SELECT LEVEL AS n FROM DUAL CONNECT BY LEVEL <= 1000) g2;
 
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('1,000,000 stock transactions inserted.');
END;
/
 
 --- VERIFICATION

SELECT COUNT(*) AS TOTAL_CATEGORIES FROM HRDB.CATEGORY;
SELECT COUNT(*) AS TOTAL_WAREHOUSES FROM HRDB.WAREHOUSE;
SELECT COUNT(*) AS TOTAL_SUPPLIERS  FROM HRDB.SUPPLIER;
SELECT COUNT(*) AS TOTAL_PRODUCTS   FROM HRDB.PRODUCT;
SELECT COUNT(*) AS TOTAL_CUSTOMERS  FROM HRDB.CUSTOMER;
SELECT COUNT(*) AS TOTAL_STOCK_ROWS FROM HRDB.STOCK;
SELECT COUNT(*) AS TOTAL_TRANSACTIONS FROM HRDB.STOCK_TRANSACTION;
 
SELECT TRANSACTION_TYPE, COUNT(*) FROM HRDB.STOCK_TRANSACTION GROUP BY TRANSACTION_TYPE;
SELECT MIN(TRANSACTION_DATE), MAX(TRANSACTION_DATE) FROM HRDB.STOCK_TRANSACTION;
 
-- Confirm data variety (no identical repeated records)
SELECT PRODUCT_ID, WAREHOUSE_ID, QUANTITY, TRANSACTION_DATE, COUNT(*)
FROM HRDB.STOCK_TRANSACTION
GROUP BY PRODUCT_ID, WAREHOUSE_ID, QUANTITY, TRANSACTION_DATE
HAVING COUNT(*) > 5
FETCH FIRST 10 ROWS ONLY;
 


