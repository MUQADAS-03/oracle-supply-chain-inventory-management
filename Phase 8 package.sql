SET DEFINE OFF;
SET SERVEROUTPUT ON;

CREATE OR REPLACE PACKAGE HRDB.PKG_INVENTORY AS

    PROCEDURE RECEIVE_STOCK (
        P_PRODUCT_ID     IN NUMBER,
        P_WAREHOUSE_ID   IN NUMBER,
        P_QTY            IN NUMBER,
        P_UNIT_PRICE     IN NUMBER DEFAULT NULL,
        P_REFERENCE_TYPE IN VARCHAR2 DEFAULT 'MANUAL',
        P_REFERENCE_ID   IN NUMBER DEFAULT NULL
    );

    PROCEDURE ISSUE_STOCK (
        P_PRODUCT_ID     IN NUMBER,
        P_WAREHOUSE_ID   IN NUMBER,
        P_QTY            IN NUMBER,
        P_REFERENCE_TYPE IN VARCHAR2 DEFAULT 'MANUAL',
        P_REFERENCE_ID   IN NUMBER DEFAULT NULL
    );

    PROCEDURE TRANSFER_STOCK (
        P_PRODUCT_ID       IN NUMBER,
        P_FROM_WAREHOUSE   IN NUMBER,
        P_TO_WAREHOUSE     IN NUMBER,
        P_QTY              IN NUMBER
    );

    FUNCTION GET_STOCK_VALUE (
        P_PRODUCT_ID   IN NUMBER,
        P_WAREHOUSE_ID IN NUMBER
    ) RETURN NUMBER;

END PKG_INVENTORY;
/

CREATE OR REPLACE PACKAGE BODY HRDB.PKG_INVENTORY AS

    -- PRIVATE procedure - only visible inside this package body
    PROCEDURE VALIDATE_QTY(P_QTY IN NUMBER) IS
    BEGIN
        IF P_QTY <= 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Quantity must be positive.');
        END IF;
    END VALIDATE_QTY;


    PROCEDURE RECEIVE_STOCK (
        P_PRODUCT_ID     IN NUMBER,
        P_WAREHOUSE_ID   IN NUMBER,
        P_QTY            IN NUMBER,
        P_UNIT_PRICE     IN NUMBER DEFAULT NULL,
        P_REFERENCE_TYPE IN VARCHAR2 DEFAULT 'MANUAL',
        P_REFERENCE_ID   IN NUMBER DEFAULT NULL
    ) IS
        V_EXISTS NUMBER;
    BEGIN
        VALIDATE_QTY(P_QTY);

        SELECT COUNT(*) INTO V_EXISTS
        FROM HRDB.STOCK
        WHERE PRODUCT_ID = P_PRODUCT_ID AND WAREHOUSE_ID = P_WAREHOUSE_ID;

        IF V_EXISTS = 0 THEN
            INSERT INTO HRDB.STOCK (PRODUCT_ID, WAREHOUSE_ID, QUANTITY_ON_HAND, LAST_UPDATED)
            VALUES (P_PRODUCT_ID, P_WAREHOUSE_ID, P_QTY, SYSDATE);
        ELSE
            UPDATE HRDB.STOCK
            SET QUANTITY_ON_HAND = QUANTITY_ON_HAND + P_QTY, LAST_UPDATED = SYSDATE
            WHERE PRODUCT_ID = P_PRODUCT_ID AND WAREHOUSE_ID = P_WAREHOUSE_ID;
        END IF;

        INSERT INTO HRDB.STOCK_TRANSACTION (
            PRODUCT_ID, WAREHOUSE_ID, TRANSACTION_TYPE, QUANTITY,
            TRANSACTION_DATE, REFERENCE_TYPE, REFERENCE_ID, UNIT_PRICE
        ) VALUES (
            P_PRODUCT_ID, P_WAREHOUSE_ID, 'IN', P_QTY,
            SYSDATE, P_REFERENCE_TYPE, P_REFERENCE_ID, P_UNIT_PRICE
        );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END RECEIVE_STOCK;


    PROCEDURE ISSUE_STOCK (
        P_PRODUCT_ID     IN NUMBER,
        P_WAREHOUSE_ID   IN NUMBER,
        P_QTY            IN NUMBER,
        P_REFERENCE_TYPE IN VARCHAR2 DEFAULT 'MANUAL',
        P_REFERENCE_ID   IN NUMBER DEFAULT NULL
    ) IS
        V_CURRENT_QTY NUMBER;
    BEGIN
        VALIDATE_QTY(P_QTY);

        -- FOR UPDATE locks this row until COMMIT/ROLLBACK - this is the
        -- transaction-safety mechanism: if two sessions try to issue
        -- stock for the same product+warehouse at the same time, the
        -- second one WAITS until the first finishes, so both checks
        -- see accurate, up-to-date quantities. This is what prevents
        -- overselling (a classic data-conflict bug).
        SELECT QUANTITY_ON_HAND INTO V_CURRENT_QTY
        FROM HRDB.STOCK
        WHERE PRODUCT_ID = P_PRODUCT_ID AND WAREHOUSE_ID = P_WAREHOUSE_ID
        FOR UPDATE;

        IF V_CURRENT_QTY < P_QTY THEN
            RAISE_APPLICATION_ERROR(-20003,
                'Insufficient stock. Available: ' || V_CURRENT_QTY || ', Requested: ' || P_QTY);
        END IF;

        UPDATE HRDB.STOCK
        SET QUANTITY_ON_HAND = QUANTITY_ON_HAND - P_QTY, LAST_UPDATED = SYSDATE
        WHERE PRODUCT_ID = P_PRODUCT_ID AND WAREHOUSE_ID = P_WAREHOUSE_ID;

        INSERT INTO HRDB.STOCK_TRANSACTION (
            PRODUCT_ID, WAREHOUSE_ID, TRANSACTION_TYPE, QUANTITY,
            TRANSACTION_DATE, REFERENCE_TYPE, REFERENCE_ID
        ) VALUES (
            P_PRODUCT_ID, P_WAREHOUSE_ID, 'OUT', P_QTY,
            SYSDATE, P_REFERENCE_TYPE, P_REFERENCE_ID
        );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END ISSUE_STOCK;


    PROCEDURE TRANSFER_STOCK (
        P_PRODUCT_ID       IN NUMBER,
        P_FROM_WAREHOUSE   IN NUMBER,
        P_TO_WAREHOUSE     IN NUMBER,
        P_QTY              IN NUMBER
    ) IS
    BEGIN
        -- Reuses the two procedures above - moving stock is really just
        -- "issue from A" + "receive into B", done as ONE atomic operation
        ISSUE_STOCK(P_PRODUCT_ID, P_FROM_WAREHOUSE, P_QTY, 'TRANSFER');
        RECEIVE_STOCK(P_PRODUCT_ID, P_TO_WAREHOUSE, P_QTY, NULL, 'TRANSFER');

        DBMS_OUTPUT.PUT_LINE('Transferred ' || P_QTY || ' units of product ' || P_PRODUCT_ID ||
                              ' from warehouse ' || P_FROM_WAREHOUSE || ' to ' || P_TO_WAREHOUSE);
    END TRANSFER_STOCK;


    FUNCTION GET_STOCK_VALUE (
        P_PRODUCT_ID   IN NUMBER,
        P_WAREHOUSE_ID IN NUMBER
    ) RETURN NUMBER IS
        V_QTY   NUMBER;
        V_PRICE NUMBER;
    BEGIN
        SELECT QUANTITY_ON_HAND INTO V_QTY
        FROM HRDB.STOCK WHERE PRODUCT_ID = P_PRODUCT_ID AND WAREHOUSE_ID = P_WAREHOUSE_ID;

        SELECT UNIT_PRICE INTO V_PRICE
        FROM HRDB.PRODUCT WHERE PRODUCT_ID = P_PRODUCT_ID;

        RETURN ROUND(V_QTY * V_PRICE, 2);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END GET_STOCK_VALUE;

END PKG_INVENTORY;
/

--- TEST THE PACKAGE

SET SERVEROUTPUT ON;

-- Receive stock via the package
BEGIN
    HRDB.PKG_INVENTORY.RECEIVE_STOCK(P_PRODUCT_ID => 3, P_WAREHOUSE_ID => 1, P_QTY => 300);
END;
/

-- Issue stock via the package
BEGIN
    HRDB.PKG_INVENTORY.ISSUE_STOCK(P_PRODUCT_ID => 3, P_WAREHOUSE_ID => 1, P_QTY => 80);
END;
/

-- Transfer stock between warehouses via the package
BEGIN
    HRDB.PKG_INVENTORY.TRANSFER_STOCK(P_PRODUCT_ID => 3, P_FROM_WAREHOUSE => 1,
                                       P_TO_WAREHOUSE => 2, P_QTY => 50);
END;
/

-- Check the function
SELECT HRDB.PKG_INVENTORY.GET_STOCK_VALUE(3, 1) AS STOCK_VALUE FROM DUAL;

-- Confirm all the movements landed correctly
SELECT * FROM HRDB.STOCK WHERE PRODUCT_ID = 3 ORDER BY WAREHOUSE_ID;
SELECT * FROM HRDB.STOCK_TRANSACTION WHERE PRODUCT_ID = 3 ORDER BY TRANSACTION_ID DESC
FETCH FIRST 5 ROWS ONLY;

-- Try to break it - attempt to issue more than available
BEGIN
    HRDB.PKG_INVENTORY.ISSUE_STOCK(P_PRODUCT_ID => 3, P_WAREHOUSE_ID => 1, P_QTY => 999999);
END;
/