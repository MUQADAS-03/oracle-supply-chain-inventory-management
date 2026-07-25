SET DEFINE OFF;
SET SERVEROUTPUT ON;

--- STEP 1: Add human-readable document number columns

ALTER TABLE HRDB.PURCHASE_ORDER ADD PO_NUMBER VARCHAR2(20);
ALTER TABLE HRDB.SALES_ORDER    ADD SO_NUMBER VARCHAR2(20);
 
ALTER TABLE HRDB.PURCHASE_ORDER ADD CONSTRAINT UK_PO_NUMBER UNIQUE (PO_NUMBER);
ALTER TABLE HRDB.SALES_ORDER    ADD CONSTRAINT UK_SO_NUMBER UNIQUE (SO_NUMBER);

--- STEP 2: Create the sequences
  
CREATE SEQUENCE HRDB.PO_NUMBER_SEQ
START WITH 1001
INCREMENT BY 1
NOCACHE;
 
CREATE SEQUENCE HRDB.SO_NUMBER_SEQ
START WITH 5001
INCREMENT BY 1
NOCACHE;

STEP 3: Generate 2000 Purchase Orders (with 1-4 line items each)
   
DECLARE
    TYPE t_num_tab IS TABLE OF NUMBER;
    v_suppliers  t_num_tab;
    v_warehouses t_num_tab;
    v_products   t_num_tab;
 
    v_supplier_pick  NUMBER;
    v_warehouse_pick NUMBER;
    v_product_pick   NUMBER;
    v_po_id          NUMBER;
    v_order_date     DATE;
    v_qty            NUMBER;
    v_price          NUMBER;
    v_num_items      NUMBER;
    v_total          NUMBER;
BEGIN
    SELECT SUPPLIER_ID  BULK COLLECT INTO v_suppliers  FROM HRDB.SUPPLIER;
    SELECT WAREHOUSE_ID BULK COLLECT INTO v_warehouses FROM HRDB.WAREHOUSE;
    SELECT PRODUCT_ID   BULK COLLECT INTO v_products   FROM HRDB.PRODUCT;
 
    FOR i IN 1..2000 LOOP
        v_supplier_pick  := v_suppliers(TRUNC(DBMS_RANDOM.VALUE(1, v_suppliers.COUNT+1)));
        v_warehouse_pick := v_warehouses(TRUNC(DBMS_RANDOM.VALUE(1, v_warehouses.COUNT+1)));
        v_order_date     := DATE '2021-01-01' + TRUNC(DBMS_RANDOM.VALUE(0, 1826));
        v_total          := 0;
 
        INSERT INTO HRDB.PURCHASE_ORDER (
            PO_NUMBER, SUPPLIER_ID, WAREHOUSE_ID, ORDER_DATE, EXPECTED_DATE,
            RECEIVED_DATE, STATUS, TOTAL_AMOUNT
        ) VALUES (
            'PO-' || HRDB.PO_NUMBER_SEQ.NEXTVAL,
            v_supplier_pick,
            v_warehouse_pick,
            v_order_date,
            v_order_date + 7,
            v_order_date + TRUNC(DBMS_RANDOM.VALUE(5, 10)),
            'RECEIVED',
            0
        ) RETURNING PO_ID INTO v_po_id;
 
        v_num_items := TRUNC(DBMS_RANDOM.VALUE(1, 5));  -- 1 to 4 line items
 
        FOR j IN 1..v_num_items LOOP
            v_product_pick := v_products(TRUNC(DBMS_RANDOM.VALUE(1, v_products.COUNT+1)));
            v_qty          := TRUNC(DBMS_RANDOM.VALUE(50, 1000));
            v_price        := ROUND(DBMS_RANDOM.VALUE(50, 5000), 2);
 
            INSERT INTO HRDB.PURCHASE_ORDER_DETAIL (
                PO_ID, PRODUCT_ID, ORDERED_QTY, RECEIVED_QTY, UNIT_PRICE
            ) VALUES (
                v_po_id, v_product_pick, v_qty, v_qty, v_price
            );
 
            v_total := v_total + (v_qty * v_price);
        END LOOP;
 
        UPDATE HRDB.PURCHASE_ORDER SET TOTAL_AMOUNT = v_total WHERE PO_ID = v_po_id;
 
        IF MOD(i, 500) = 0 THEN
            COMMIT;
        END IF;
    END LOOP;
 
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('2000 purchase orders inserted.');
END;
/

--- STEP 4: Generate 5000 Sales Orders (with 1-4 line items each)
   
DECLARE
    TYPE t_num_tab IS TABLE OF NUMBER;
    v_customers  t_num_tab;
    v_warehouses t_num_tab;
    v_products   t_num_tab;
 
    v_customer_pick  NUMBER;
    v_warehouse_pick NUMBER;
    v_product_pick   NUMBER;
    v_so_id          NUMBER;
    v_order_date     DATE;
    v_qty            NUMBER;
    v_price          NUMBER;
    v_num_items      NUMBER;
    v_total          NUMBER;
BEGIN
    SELECT CUSTOMER_ID  BULK COLLECT INTO v_customers  FROM HRDB.CUSTOMER;
    SELECT WAREHOUSE_ID BULK COLLECT INTO v_warehouses FROM HRDB.WAREHOUSE;
    SELECT PRODUCT_ID   BULK COLLECT INTO v_products   FROM HRDB.PRODUCT;
 
    FOR i IN 1..5000 LOOP
        v_customer_pick  := v_customers(TRUNC(DBMS_RANDOM.VALUE(1, v_customers.COUNT+1)));
        v_warehouse_pick := v_warehouses(TRUNC(DBMS_RANDOM.VALUE(1, v_warehouses.COUNT+1)));
        v_order_date     := DATE '2021-01-01' + TRUNC(DBMS_RANDOM.VALUE(0, 1826));
        v_total          := 0;
 
        INSERT INTO HRDB.SALES_ORDER (
            SO_NUMBER, CUSTOMER_ID, WAREHOUSE_ID, ORDER_DATE, DELIVERY_DATE,
            STATUS, TOTAL_AMOUNT
        ) VALUES (
            'SO-' || HRDB.SO_NUMBER_SEQ.NEXTVAL,
            v_customer_pick,
            v_warehouse_pick,
            v_order_date,
            v_order_date + TRUNC(DBMS_RANDOM.VALUE(1, 5)),
            'DELIVERED',
            0
        ) RETURNING SO_ID INTO v_so_id;
 
        v_num_items := TRUNC(DBMS_RANDOM.VALUE(1, 5));
 
        FOR j IN 1..v_num_items LOOP
            v_product_pick := v_products(TRUNC(DBMS_RANDOM.VALUE(1, v_products.COUNT+1)));
            v_qty          := TRUNC(DBMS_RANDOM.VALUE(1, 100));
            v_price        := ROUND(DBMS_RANDOM.VALUE(50, 5000), 2);
 
            INSERT INTO HRDB.SALES_ORDER_DETAIL (
                SO_ID, PRODUCT_ID, QUANTITY, UNIT_PRICE
            ) VALUES (
                v_so_id, v_product_pick, v_qty, v_price
            );
 
            v_total := v_total + (v_qty * v_price);
        END LOOP;
 
        UPDATE HRDB.SALES_ORDER SET TOTAL_AMOUNT = v_total WHERE SO_ID = v_so_id;
 
        IF MOD(i, 500) = 0 THEN
            COMMIT;
        END IF;
    END LOOP;
 
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('5000 sales orders inserted.');
END;
/
 
 --- VERIFICATION
   
SELECT COUNT(*) AS TOTAL_PURCHASE_ORDERS FROM HRDB.PURCHASE_ORDER;
SELECT COUNT(*) AS TOTAL_PO_DETAILS      FROM HRDB.PURCHASE_ORDER_DETAIL;
SELECT COUNT(*) AS TOTAL_SALES_ORDERS    FROM HRDB.SALES_ORDER;
SELECT COUNT(*) AS TOTAL_SO_DETAILS      FROM HRDB.SALES_ORDER_DETAIL;
 
-- Confirm PO_NUMBER / SO_NUMBER format
SELECT PO_ID, PO_NUMBER, SUPPLIER_ID, TOTAL_AMOUNT FROM HRDB.PURCHASE_ORDER
FETCH FIRST 5 ROWS ONLY;
 
SELECT SO_ID, SO_NUMBER, CUSTOMER_ID, TOTAL_AMOUNT FROM HRDB.SALES_ORDER
FETCH FIRST 5 ROWS ONLY;
 
-- Confirm sequence is actually being used (no duplicates, sequential-ish)
SELECT COUNT(DISTINCT PO_NUMBER) AS DISTINCT_PO_NUMBERS FROM HRDB.PURCHASE_ORDER;
SELECT COUNT(DISTINCT SO_NUMBER) AS DISTINCT_SO_NUMBERS FROM HRDB.SALES_ORDER;
 
-- Check current sequence value
SELECT HRDB.PO_NUMBER_SEQ.CURRVAL FROM DUAL;
SELECT HRDB.SO_NUMBER_SEQ.CURRVAL FROM DUAL;

