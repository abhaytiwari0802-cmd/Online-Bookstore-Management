SET DEFINE OFF;
-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM
-- Script: 05_views_and_functions.sql
-- Description: Business reporting views and helper functions.
-- Target DB: Oracle Database 19c / 21c / 23c / XE
-- ============================================================================

-- ============================================================================
-- Function: FN_CHECK_BOOK_AVAILABILITY
-- Description: Returns availability status code for a given quantity.
-- ============================================================================
CREATE OR REPLACE FUNCTION FN_CHECK_BOOK_AVAILABILITY(
    p_book_id      IN NUMBER,
    p_required_qty IN NUMBER DEFAULT 1
) RETURN VARCHAR2 IS
    v_stock NUMBER;
BEGIN
    SELECT stock_quantity INTO v_stock
      FROM BOOKS
     WHERE book_id = p_book_id AND is_active = 'Y';

    IF v_stock = 0 THEN
        RETURN 'OUT_OF_STOCK';
    ELSIF v_stock < p_required_qty THEN
        RETURN 'INSUFFICIENT_STOCK';
    ELSIF v_stock <= 5 THEN
        RETURN 'LOW_STOCK';
    ELSE
        RETURN 'AVAILABLE';
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'NOT_FOUND';
END;
/

-- ============================================================================
-- Function: FN_CALCULATE_DISCOUNT
-- Description: Applies promotional coupon rules to compute discount amount.
-- ============================================================================
CREATE OR REPLACE FUNCTION FN_CALCULATE_DISCOUNT(
    p_subtotal     IN NUMBER,
    p_promo_code   IN VARCHAR2
) RETURN NUMBER IS
    v_discount NUMBER(10,2) := 0;
BEGIN
    IF p_promo_code IS NULL THEN
        RETURN 0;
    END IF;

    CASE UPPER(TRIM(p_promo_code))
        WHEN 'BOOKWORM10' THEN
            v_discount := ROUND(p_subtotal * 0.10, 2); -- 10% off
        WHEN 'READ20' THEN
            IF p_subtotal >= 40.00 THEN
                v_discount := ROUND(p_subtotal * 0.20, 2); -- 20% off over $40
            END IF;
        WHEN 'FREESHIP' THEN
            v_discount := 5.00; -- Covers standard shipping
        WHEN 'WELCOME5' THEN
            v_discount := 5.00; -- Flat $5 welcome discount
        ELSE
            v_discount := 0;
    END CASE;

    -- Ensure discount doesn't exceed subtotal
    IF v_discount > p_subtotal THEN
        v_discount := p_subtotal;
    END IF;

    RETURN v_discount;
END;
/

-- ============================================================================
-- View: VW_ACTIVE_CATALOG
-- Description: User-facing view of all books with category names and status.
-- ============================================================================
CREATE OR REPLACE VIEW VW_ACTIVE_CATALOG AS
SELECT b.book_id,
       b.isbn,
       b.title,
       b.author,
       b.category_id,
       c.category_name,
       b.price,
       b.stock_quantity,
       b.publisher,
       b.publication_year,
       b.description,
       b.cover_image_url,
       b.rating,
       CASE 
           WHEN b.stock_quantity = 0 THEN 'Out of Stock'
           WHEN b.stock_quantity <= 5 THEN 'Low Stock'
           ELSE 'In Stock'
       END AS stock_status,
       b.created_at
  FROM BOOKS b
  JOIN CATEGORIES c ON b.category_id = c.category_id
 WHERE b.is_active = 'Y'
   AND c.is_active = 'Y';

-- ============================================================================
-- View: VW_USER_ORDERS_SUMMARY
-- Description: Flattened view of orders with customer contact and metrics.
-- ============================================================================
CREATE OR REPLACE VIEW VW_USER_ORDERS_SUMMARY AS
SELECT o.order_id,
       o.user_id,
       u.username,
       u.full_name AS customer_name,
       u.email,
       o.order_date,
       o.order_status,
       o.subtotal,
       o.tax_amount,
       o.shipping_fee,
       o.discount_amount,
       o.total_amount,
       o.payment_method,
       o.payment_status,
       o.shipping_address,
       (SELECT COUNT(*) FROM ORDER_ITEMS oi WHERE oi.order_id = o.order_id) AS total_items,
       (SELECT NVL(SUM(quantity), 0) FROM ORDER_ITEMS oi WHERE oi.order_id = o.order_id) AS total_book_units
  FROM ORDERS o
  JOIN USERS u ON o.user_id = u.user_id;

-- ============================================================================
-- View: VW_SALES_BY_CATEGORY
-- Description: Aggregate sales figures grouped by book genre.
-- ============================================================================
CREATE OR REPLACE VIEW VW_SALES_BY_CATEGORY AS
SELECT c.category_id,
       c.category_name,
       COUNT(DISTINCT b.book_id) AS active_titles,
       NVL(SUM(oi.quantity), 0) AS total_units_sold,
       NVL(SUM(oi.line_total), 0) AS total_revenue
  FROM CATEGORIES c
  LEFT JOIN BOOKS b ON c.category_id = b.category_id AND b.is_active = 'Y'
  LEFT JOIN ORDER_ITEMS oi ON b.book_id = oi.book_id
  LEFT JOIN ORDERS o ON oi.order_id = o.order_id AND o.order_status <> 'CANCELLED'
 GROUP BY c.category_id, c.category_name;

-- ============================================================================
-- View: VW_SYSTEM_AUDIT_TRAIL
-- Description: Clean presentation of audit logs with relative timestamps.
-- ============================================================================
CREATE OR REPLACE VIEW VW_SYSTEM_AUDIT_TRAIL AS
SELECT log_id,
       table_name,
       action_type,
       record_id,
       changed_by,
       old_values,
       new_values,
       log_timestamp
  FROM AUDIT_LOGS
 ORDER BY log_timestamp DESC;
