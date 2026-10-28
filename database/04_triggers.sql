SET DEFINE OFF;
-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM
-- Script: 04_triggers.sql
-- Description: Business rules, security audit trails and integrity triggers.
-- Target DB: Oracle Database 19c / 21c / 23c / XE
-- ============================================================================

-- ============================================================================
-- Trigger: TRG_PREVENT_NEGATIVE_STOCK
-- Description: Enforces stock non-negativity constraint at the trigger level.
-- ============================================================================
CREATE OR REPLACE TRIGGER TRG_PREVENT_NEGATIVE_STOCK
BEFORE INSERT OR UPDATE OF stock_quantity ON BOOKS
FOR EACH ROW
BEGIN
    IF :NEW.stock_quantity < 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Book inventory stock cannot fall below zero. Attempted value: ' || :NEW.stock_quantity);
    END IF;
END;
/

-- ============================================================================
-- Trigger: TRG_ORDER_ITEMS_CALC_TOTAL
-- Description: Guarantees line_total computation consistency.
-- ============================================================================
CREATE OR REPLACE TRIGGER TRG_ORDER_ITEMS_CALC_TOTAL
BEFORE INSERT OR UPDATE OF quantity, unit_price ON ORDER_ITEMS
FOR EACH ROW
BEGIN
    :NEW.line_total := ROUND(:NEW.quantity * :NEW.unit_price, 2);
END;
/

-- ============================================================================
-- Trigger: TRG_USERS_UPDATE_TIMESTAMP
-- Description: Automatically synchronizes updated_at timestamp on row change.
-- ============================================================================
CREATE OR REPLACE TRIGGER TRG_USERS_UPDATE_TIMESTAMP
BEFORE UPDATE ON USERS
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

-- ============================================================================
-- Trigger: TRG_BOOKS_UPDATE_TIMESTAMP
-- Description: Automatically synchronizes updated_at timestamp on row change.
-- ============================================================================
CREATE OR REPLACE TRIGGER TRG_BOOKS_UPDATE_TIMESTAMP
BEFORE UPDATE ON BOOKS
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

-- ============================================================================
-- Trigger: TRG_AUDIT_USERS
-- Description: Audit trail for user registrations, role changes, or deactivations.
-- ============================================================================
CREATE OR REPLACE TRIGGER TRG_AUDIT_USERS
AFTER INSERT OR UPDATE OR DELETE ON USERS
FOR EACH ROW
DECLARE
    v_action VARCHAR2(10);
    v_old    VARCHAR2(4000);
    v_new    VARCHAR2(4000);
    v_rec_id VARCHAR2(50);
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
        v_rec_id := TO_CHAR(:NEW.user_id);
        v_new    := 'Username: ' || :NEW.username || ', Email: ' || :NEW.email || ', Role: ' || :NEW.role_id || ', Active: ' || :NEW.is_active;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_rec_id := TO_CHAR(:NEW.user_id);
        v_old    := 'Role: ' || :OLD.role_id || ', Active: ' || :OLD.is_active || ', Phone: ' || :OLD.phone;
        v_new    := 'Role: ' || :NEW.role_id || ', Active: ' || :NEW.is_active || ', Phone: ' || :NEW.phone;
    ELSIF DELETING THEN
        v_action := 'DELETE';
        v_rec_id := TO_CHAR(:OLD.user_id);
        v_old    := 'Username: ' || :OLD.username || ', Email: ' || :OLD.email;
    END IF;

    INSERT INTO AUDIT_LOGS (
        log_id, table_name, action_type, record_id,
        changed_by, old_values, new_values, log_timestamp
    ) VALUES (
        SEQ_AUDIT.NEXTVAL, 'USERS', v_action, v_rec_id,
        USER, v_old, v_new, SYSTIMESTAMP
    );
END;
/

-- ============================================================================
-- Trigger: TRG_AUDIT_ORDERS
-- Description: Compliance tracking of customer order status and financial values.
-- ============================================================================
CREATE OR REPLACE TRIGGER TRG_AUDIT_ORDERS
AFTER INSERT OR UPDATE OF order_status, total_amount ON ORDERS
FOR EACH ROW
DECLARE
    v_action VARCHAR2(10);
    v_old    VARCHAR2(4000);
    v_new    VARCHAR2(4000);
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
        v_new    := 'User: ' || :NEW.user_id || ', Status: ' || :NEW.order_status || ', Total: ' || :NEW.total_amount;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_old    := 'Status: ' || :OLD.order_status || ', Total: ' || :OLD.total_amount;
        v_new    := 'Status: ' || :NEW.order_status || ', Total: ' || :NEW.total_amount;
    END IF;

    INSERT INTO AUDIT_LOGS (
        log_id, table_name, action_type, record_id,
        changed_by, old_values, new_values, log_timestamp
    ) VALUES (
        SEQ_AUDIT.NEXTVAL, 'ORDERS', v_action, TO_CHAR(NVL(:NEW.order_id, :OLD.order_id)),
        USER, v_old, v_new, SYSTIMESTAMP
    );
END;
/
