--- PHASE 5: TRIGGER 

SET DEFINE OFF;
SET SERVEROUTPUT ON;

CREATE OR REPLACE TRIGGER HRDB.TRG_LOW_STOCK_ALERT
AFTER UPDATE OF QUANTITY_ON_HAND ON HRDB.STOCK
FOR EACH ROW
DECLARE
    v_reorder_level  NUMBER;
    v_open_count     NUMBER;
BEGIN
    -- Get this product's reorder threshold
    SELECT REORDER_LEVEL INTO v_reorder_level
    FROM HRDB.PRODUCT
    WHERE PRODUCT_ID = :NEW.PRODUCT_ID;

    IF :NEW.QUANTITY_ON_HAND < v_reorder_level THEN
        -- Stock fell below threshold - check if an OPEN alert already
        -- exists for this product/warehouse (avoid duplicate alerts)
        SELECT COUNT(*) INTO v_open_count
        FROM HRDB.LOW_STOCK_ALERT
        WHERE PRODUCT_ID = :NEW.PRODUCT_ID
          AND WAREHOUSE_ID = :NEW.WAREHOUSE_ID
          AND STATUS = 'OPEN';

        IF v_open_count = 0 THEN
            INSERT INTO HRDB.LOW_STOCK_ALERT (
                PRODUCT_ID, WAREHOUSE_ID, CURRENT_QTY, REORDER_LEVEL, STATUS
            ) VALUES (
                :NEW.PRODUCT_ID, :NEW.WAREHOUSE_ID, :NEW.QUANTITY_ON_HAND, v_reorder_level, 'OPEN'
            );
        ELSE
            -- Alert already open - just refresh the current quantity shown
            UPDATE HRDB.LOW_STOCK_ALERT
            SET CURRENT_QTY = :NEW.QUANTITY_ON_HAND
            WHERE PRODUCT_ID = :NEW.PRODUCT_ID
              AND WAREHOUSE_ID = :NEW.WAREHOUSE_ID
              AND STATUS = 'OPEN';
        END IF;

    ELSIF :NEW.QUANTITY_ON_HAND >= v_reorder_level THEN
        -- Stock replenished back above threshold - auto-resolve open alerts
        UPDATE HRDB.LOW_STOCK_ALERT
        SET STATUS = 'RESOLVED'
        WHERE PRODUCT_ID = :NEW.PRODUCT_ID
          AND WAREHOUSE_ID = :NEW.WAREHOUSE_ID
          AND STATUS = 'OPEN';
    END IF;
END;
/

--- TEST THE TRIGGER
  
-- Pick one product/warehouse and check its current state
SELECT s.PRODUCT_ID, s.WAREHOUSE_ID, s.QUANTITY_ON_HAND, p.REORDER_LEVEL
FROM HRDB.STOCK s JOIN HRDB.PRODUCT p ON p.PRODUCT_ID = s.PRODUCT_ID
WHERE s.PRODUCT_ID = 1 AND s.WAREHOUSE_ID = 1;

-- Manually drop the quantity below reorder level to trigger the alert
UPDATE HRDB.STOCK
SET QUANTITY_ON_HAND = 5
WHERE PRODUCT_ID = 1 AND WAREHOUSE_ID = 1;
COMMIT;

-- Check that an alert was auto-created
SELECT * FROM HRDB.LOW_STOCK_ALERT
WHERE PRODUCT_ID = 1 AND WAREHOUSE_ID = 1;

-- Now replenish stock above threshold - alert should auto-resolve
UPDATE HRDB.STOCK
SET QUANTITY_ON_HAND = 500
WHERE PRODUCT_ID = 1 AND WAREHOUSE_ID = 1;
COMMIT;

-- Confirm it's now RESOLVED
SELECT * FROM HRDB.LOW_STOCK_ALERT
WHERE PRODUCT_ID = 1 AND WAREHOUSE_ID = 1;

-- Overall count of currently open alerts (real dashboard-style check)
SELECT COUNT(*) AS OPEN_ALERTS FROM HRDB.LOW_STOCK_ALERT WHERE STATUS = 'OPEN';