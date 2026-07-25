--- PHASE 9: CURSORS + LOOPS
  
SET DEFINE OFF;
SET SERVEROUTPUT ON;

--- EXAMPLE 1: Basic explicit cursor - print all currently low-stock items
  
DECLARE
    CURSOR C_LOW_STOCK IS
        SELECT s.PRODUCT_ID, s.WAREHOUSE_ID, s.QUANTITY_ON_HAND,
               p.PRODUCT_NAME, p.REORDER_LEVEL, p.REORDER_QTY
        FROM HRDB.STOCK s
        JOIN HRDB.PRODUCT p ON p.PRODUCT_ID = s.PRODUCT_ID
        WHERE s.QUANTITY_ON_HAND < p.REORDER_LEVEL;

    V_REC C_LOW_STOCK%ROWTYPE;
    V_COUNT NUMBER := 0;
BEGIN
    OPEN C_LOW_STOCK;
    LOOP
        FETCH C_LOW_STOCK INTO V_REC;
        EXIT WHEN C_LOW_STOCK%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE('LOW STOCK: ' || V_REC.PRODUCT_NAME ||
                              ' | Warehouse ' || V_REC.WAREHOUSE_ID ||
                              ' | On hand: ' || V_REC.QUANTITY_ON_HAND ||
                              ' | Reorder level: ' || V_REC.REORDER_LEVEL ||
                              ' | Suggested reorder qty: ' || V_REC.REORDER_QTY);
        V_COUNT := V_COUNT + 1;
    END LOOP;
    CLOSE C_LOW_STOCK;

    DBMS_OUTPUT.PUT_LINE('Total low-stock items: ' || V_COUNT);
END;
/

--- EXAMPLE 2: Cursor FOR LOOP (implicit open/fetch/close 
BEGIN
    FOR REC IN (
        SELECT p.PRODUCT_NAME, s.WAREHOUSE_ID, s.QUANTITY_ON_HAND
        FROM HRDB.STOCK s JOIN HRDB.PRODUCT p ON p.PRODUCT_ID = s.PRODUCT_ID
        WHERE s.QUANTITY_ON_HAND < p.REORDER_LEVEL
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(REC.PRODUCT_NAME || ' - Warehouse ' || REC.WAREHOUSE_ID ||
                              ' - Qty: ' || REC.QUANTITY_ON_HAND);
    END LOOP;
END;
/

--- EXAMPLE 3: Parameterized cursor - reusable for any supplier
   
DECLARE
    CURSOR C_SUPPLIER_PRODUCTS (P_SUPPLIER_ID NUMBER) IS
        SELECT PRODUCT_NAME, UNIT_PRICE
        FROM HRDB.PRODUCT
        WHERE DEFAULT_SUPPLIER_ID = P_SUPPLIER_ID;
BEGIN
    FOR REC IN C_SUPPLIER_PRODUCTS(1) LOOP   -- change 1 to any SUPPLIER_ID
        DBMS_OUTPUT.PUT_LINE(REC.PRODUCT_NAME || ' - Rs.' || REC.UNIT_PRICE);
    END LOOP;
END;
/

--- MAIN DELIVERABLE: PROC_AUTO_GENERATE_REORDERS
---  Loops through every OPEN low-stock alert and automatically creates
   
CREATE OR REPLACE PROCEDURE HRDB.PROC_AUTO_GENERATE_REORDERS
AS
    CURSOR C_ALERTS IS
        SELECT a.ALERT_ID, a.PRODUCT_ID, a.WAREHOUSE_ID,
               p.DEFAULT_SUPPLIER_ID, p.REORDER_QTY, p.UNIT_PRICE
        FROM HRDB.LOW_STOCK_ALERT a
        JOIN HRDB.PRODUCT p ON p.PRODUCT_ID = a.PRODUCT_ID
        WHERE a.STATUS = 'OPEN';

    V_PO_ID       NUMBER;
    V_LAST_SUPPLIER NUMBER := -1;
    V_ORDERS_CREATED NUMBER := 0;
BEGIN
    FOR REC IN C_ALERTS LOOP
        -- Create one PO per alert (simple version - one product each)
        HRDB.PROC_CREATE_PURCHASE_ORDER(
            P_SUPPLIER_ID  => REC.DEFAULT_SUPPLIER_ID,
            P_WAREHOUSE_ID => REC.WAREHOUSE_ID,
            P_PO_ID        => V_PO_ID
        );

        HRDB.PROC_ADD_PO_DETAIL(
            P_PO_ID      => V_PO_ID,
            P_PRODUCT_ID => REC.PRODUCT_ID,
            P_QTY        => REC.REORDER_QTY,
            P_UNIT_PRICE => REC.UNIT_PRICE
        );

        -- Mark the alert as acknowledged since a PO now exists for it
        HRDB.PROC_UPDATE_ALERT_STATUS(REC.ALERT_ID, 'ACKNOWLEDGED');

        V_ORDERS_CREATED := V_ORDERS_CREATED + 1;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(V_ORDERS_CREATED || ' auto-reorder purchase orders created.');
END PROC_AUTO_GENERATE_REORDERS;
/

--- TEST IT
   
SET SERVEROUTPUT ON;

-- Check how many alerts are open before
SELECT COUNT(*) AS OPEN_ALERTS FROM HRDB.LOW_STOCK_ALERT WHERE STATUS = 'OPEN';

BEGIN
    HRDB.PROC_AUTO_GENERATE_REORDERS;
END;
/

-- Confirm alerts are now acknowledged, and new POs were created
SELECT STATUS, COUNT(*) FROM HRDB.LOW_STOCK_ALERT GROUP BY STATUS;
SELECT * FROM HRDB.PURCHASE_ORDER ORDER BY PO_ID DESC FETCH FIRST 5 ROWS ONLY;