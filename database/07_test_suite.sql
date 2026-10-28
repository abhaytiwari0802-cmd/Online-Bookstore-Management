SET DEFINE OFF;
-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM
-- Script: 07_test_suite.sql
-- Description: Automated Unit and Integration Test Suite using DBMS_OUTPUT.
-- Target DB: Oracle Database 19c / 21c / 23c / XE
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    v_test_count    NUMBER := 0;
    v_pass_count    NUMBER := 0;
    v_fail_count    NUMBER := 0;

    v_test_user_id  NUMBER;
    v_user_id       NUMBER;
    v_book_id       NUMBER;
    v_order_id      NUMBER;
    v_total_amt     NUMBER;
    v_status        VARCHAR2(20);
    v_msg           VARCHAR2(500);

    v_username      VARCHAR2(60);
    v_fullname      VARCHAR2(120);
    v_role          VARCHAR2(30);

    v_stock_before  NUMBER;
    v_stock_after   NUMBER;
    v_cart_subtotal NUMBER;
    v_cart_items    NUMBER;

    v_rep_users     NUMBER;
    v_rep_books     NUMBER;
    v_rep_orders    NUMBER;
    v_rep_rev       NUMBER;
    v_rep_pending   NUMBER;

    PROCEDURE report_result(p_desc VARCHAR2, p_success BOOLEAN, p_info VARCHAR2 DEFAULT NULL) IS
    BEGIN
        v_test_count := v_test_count + 1;
        IF p_success THEN
            v_pass_count := v_pass_count + 1;
            DBMS_OUTPUT.PUT_LINE('  [PASS] Test ' || LPAD(v_test_count, 2, '0') || ': ' || p_desc);
        ELSE
            v_fail_count := v_fail_count + 1;
            DBMS_OUTPUT.PUT_LINE('  [FAIL] Test ' || LPAD(v_test_count, 2, '0') || ': ' || p_desc);
            IF p_info IS NOT NULL THEN
                DBMS_OUTPUT.PUT_LINE('         -> ' || p_info);
            END IF;
        END IF;
    END report_result;

BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('      ONLINE BOOKSTORE SYSTEM - PL/SQL TEST SUITE RUNNER       ');
    DBMS_OUTPUT.PUT_LINE('================================================================');

    -- ------------------------------------------------------------------------
    -- TEST 1: User Registration
    -- ------------------------------------------------------------------------
    PKG_USER_MGMT.register_user(
        'test_shopper_' || TO_CHAR(SYSTIMESTAMP, 'SSSSS'),
        'shopper_' || TO_CHAR(SYSTIMESTAMP, 'SSSSS') || '@test.com',
        'SecurePass123!',
        'Test Shopper',
        '+1-555-9999',
        '99 Test Street, Lab City',
        2,
        v_test_user_id,
        v_status,
        v_msg
    );
    report_result('User Registration with valid inputs', (v_status = 'SUCCESS' AND v_test_user_id IS NOT NULL), v_msg);

    -- ------------------------------------------------------------------------
    -- TEST 2: Duplicate Email Protection
    -- ------------------------------------------------------------------------
    DECLARE
        v_temp_id NUMBER;
    BEGIN
        PKG_USER_MGMT.register_user(
            'different_user',
            'admin@bookstore.com', -- Already exists in seed
            'Pass123456',
            'Another User',
            NULL, NULL, 2,
            v_temp_id,
            v_status,
            v_msg
        );
        report_result('Duplicate Email Prevention Constraint', (v_status = 'ERROR'), v_msg);
    END;

    -- ------------------------------------------------------------------------
    -- TEST 3: User Authentication - Correct Credentials
    -- ------------------------------------------------------------------------
    PKG_USER_MGMT.authenticate_user('admin', 'Admin@123', v_user_id, v_username, v_fullname, v_role, v_status, v_msg);
    report_result('User Authentication (Valid Credentials)', (v_status = 'SUCCESS' AND v_role = 'ADMIN'), v_msg);

    -- ------------------------------------------------------------------------
    -- TEST 4: User Authentication - Incorrect Credentials
    -- ------------------------------------------------------------------------
    PKG_USER_MGMT.authenticate_user('admin', 'WrongPassword!', v_user_id, v_username, v_fullname, v_role, v_status, v_msg);
    report_result('User Authentication (Invalid Password Rejected)', (v_status = 'ERROR' AND v_user_id IS NULL), v_msg);

    -- ------------------------------------------------------------------------
    -- TEST 5: Book Management - Add New Book
    -- ------------------------------------------------------------------------
    PKG_BOOK_MGMT.add_book(
        '978-TEST-' || TO_CHAR(SYSTIMESTAMP, 'SSSSS'),
        'Test PL/SQL Enterprise Patterns',
        'Senior Architect',
        102,
        64.99,
        15,
        'Tech Press',
        2024,
        'A comprehensive guide to high-performance PL/SQL.',
        'https://example.com/cover.jpg',
        v_book_id,
        v_status,
        v_msg
    );
    report_result('Add Book to Catalog via Admin Package', (v_status = 'SUCCESS' AND v_book_id IS NOT NULL), v_msg);

    -- ------------------------------------------------------------------------
    -- TEST 6: Shopping Cart - Add Item
    -- ------------------------------------------------------------------------
    PKG_CART_MGMT.add_to_cart(v_test_user_id, v_book_id, 2, v_status, v_msg);
    report_result('Add Book to Shopping Cart', (v_status = 'SUCCESS'), v_msg);

    -- ------------------------------------------------------------------------
    -- TEST 7: Shopping Cart - Verify Quantity and Subtotal
    -- ------------------------------------------------------------------------
    DECLARE
        v_dummy_cur SYS_REFCURSOR;
    BEGIN
        PKG_CART_MGMT.get_cart_items(v_test_user_id, v_dummy_cur, v_cart_subtotal, v_cart_items);
        CLOSE v_dummy_cur;
        report_result('Cart Subtotal Calculation', (v_cart_items >= 2 AND v_cart_subtotal > 0), 'Subtotal: ' || v_cart_subtotal);
    END;

    -- ------------------------------------------------------------------------
    -- TEST 8: Inventory Stock Lock and Order Placement
    -- ------------------------------------------------------------------------
    SELECT stock_quantity INTO v_stock_before FROM BOOKS WHERE book_id = v_book_id;

    PKG_ORDER_MGMT.place_order(
        v_test_user_id,
        '123 Delivery Road, Apt 4B, Metropolis',
        '+1-555-0199',
        'CARD',
        'Unit test automated order.',
        v_order_id,
        v_total_amt,
        v_status,
        v_msg
    );
    SELECT stock_quantity INTO v_stock_after FROM BOOKS WHERE book_id = v_book_id;

    report_result(
        'Place Order Transaction and Automatic Inventory Deduction',
        (v_status = 'SUCCESS' AND v_order_id IS NOT NULL AND v_stock_after = (v_stock_before - 2)),
        'Order ID: ' || v_order_id || ', Old Stock: ' || v_stock_before || ', New Stock: ' || v_stock_after
    );

    -- ------------------------------------------------------------------------
    -- TEST 9: Order Status Lifecycle & Cancellation Stock Reversal
    -- ------------------------------------------------------------------------
    PKG_ORDER_MGMT.cancel_order(v_order_id, v_test_user_id, 'Unit test cancellation', v_status, v_msg);
    SELECT stock_quantity INTO v_stock_after FROM BOOKS WHERE book_id = v_book_id;

    report_result(
        'Order Cancellation and Automatic Stock Inventory Rollback',
        (v_status = 'SUCCESS' AND v_stock_after = v_stock_before),
        'Stock successfully reverted to: ' || v_stock_after
    );

    -- ------------------------------------------------------------------------
    -- TEST 10: Reports Dashboard Summary KPI
    -- ------------------------------------------------------------------------
    PKG_REPORTS.get_dashboard_summary(v_rep_users, v_rep_books, v_rep_orders, v_rep_rev, v_rep_pending);
    report_result(
        'Executive Analytics and Dashboard KPI Retrieval',
        (v_rep_users > 0 AND v_rep_books > 0),
        'Users: ' || v_rep_users || ', Books: ' || v_rep_books || ', Orders: ' || v_rep_orders || ', Rev: $' || v_rep_rev
    );

    -- Clean up test book
    PKG_BOOK_MGMT.remove_book(v_book_id, 'Y', v_status, v_msg);

    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('TEST SUMMARY: ' || v_pass_count || '/' || v_test_count || ' Tests Passed (' || v_fail_count || ' Failed).');
    DBMS_OUTPUT.PUT_LINE('================================================================');
END;
/
