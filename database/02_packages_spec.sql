SET DEFINE OFF;
-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM
-- Script: 02_packages_spec.sql
-- Description: Package Specifications for Bookstore Modules.
-- Target DB: Oracle Database 19c / 21c / 23c / XE
-- ============================================================================

-- ============================================================================
-- Package: PKG_USER_MGMT
-- Description: Handles user authentication, registration, profiles and security.
-- ============================================================================
CREATE OR REPLACE PACKAGE PKG_USER_MGMT AS
    -- Hash password with salt using standard SHA-256
    FUNCTION hash_password(
        p_password IN VARCHAR2,
        p_salt     IN VARCHAR2
    ) RETURN VARCHAR2;

    -- Generate random cryptographic salt
    FUNCTION generate_salt RETURN VARCHAR2;

    -- User registration procedure
    PROCEDURE register_user(
        p_username      IN  VARCHAR2,
        p_email         IN  VARCHAR2,
        p_password      IN  VARCHAR2,
        p_full_name     IN  VARCHAR2,
        p_phone         IN  VARCHAR2 DEFAULT NULL,
        p_address       IN  VARCHAR2 DEFAULT NULL,
        p_role_id       IN  NUMBER DEFAULT 2, -- 2: Customer, 1: Admin
        o_user_id       OUT NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- User login authentication
    PROCEDURE authenticate_user(
        p_username_or_email IN  VARCHAR2,
        p_password          IN  VARCHAR2,
        o_user_id           OUT NUMBER,
        o_username          OUT VARCHAR2,
        o_full_name         OUT VARCHAR2,
        o_role_name         OUT VARCHAR2,
        o_status            OUT VARCHAR2,
        o_message           OUT VARCHAR2
    );

    -- Retrieve user profile details via REF CURSOR
    PROCEDURE get_user_profile(
        p_user_id           IN  NUMBER,
        o_profile_cursor    OUT SYS_REFCURSOR
    );

    -- Update user profile info
    PROCEDURE update_profile(
        p_user_id       IN  NUMBER,
        p_full_name     IN  VARCHAR2,
        p_phone         IN  VARCHAR2,
        p_address       IN  VARCHAR2,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- Update user password
    PROCEDURE change_password(
        p_user_id       IN  NUMBER,
        p_old_password  IN  VARCHAR2,
        p_new_password  IN  VARCHAR2,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );
END PKG_USER_MGMT;
/

-- ============================================================================
-- Package: PKG_BOOK_MGMT
-- Description: Inventory management, book catalog CRUD and search filtering.
-- ============================================================================
CREATE OR REPLACE PACKAGE PKG_BOOK_MGMT AS
    -- Add a new book to the catalog
    PROCEDURE add_book(
        p_isbn              IN  VARCHAR2,
        p_title             IN  VARCHAR2,
        p_author            IN  VARCHAR2,
        p_category_id       IN  NUMBER,
        p_price             IN  NUMBER,
        p_stock_quantity    IN  NUMBER,
        p_publisher         IN  VARCHAR2 DEFAULT NULL,
        p_publication_year  IN  NUMBER DEFAULT NULL,
        p_description       IN  VARCHAR2 DEFAULT NULL,
        p_cover_image_url   IN  VARCHAR2 DEFAULT NULL,
        o_book_id           OUT NUMBER,
        o_status            OUT VARCHAR2,
        o_message           OUT VARCHAR2
    );

    -- Update an existing book's details
    PROCEDURE update_book(
        p_book_id           IN  NUMBER,
        p_title             IN  VARCHAR2,
        p_author            IN  VARCHAR2,
        p_category_id       IN  NUMBER,
        p_price             IN  NUMBER,
        p_stock_quantity    IN  NUMBER,
        p_publisher         IN  VARCHAR2 DEFAULT NULL,
        p_publication_year  IN  NUMBER DEFAULT NULL,
        p_description       IN  VARCHAR2 DEFAULT NULL,
        p_cover_image_url   IN  VARCHAR2 DEFAULT NULL,
        o_status            OUT VARCHAR2,
        o_message           OUT VARCHAR2
    );

    -- Remove or deactivate a book
    PROCEDURE remove_book(
        p_book_id       IN  NUMBER,
        p_hard_delete   IN  CHAR DEFAULT 'N',
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- Dynamic search and filtering of books
    PROCEDURE search_books(
        p_query         IN  VARCHAR2 DEFAULT NULL,
        p_category_id   IN  NUMBER DEFAULT NULL,
        p_min_price     IN  NUMBER DEFAULT NULL,
        p_max_price     IN  NUMBER DEFAULT NULL,
        p_sort_by       IN  VARCHAR2 DEFAULT 'TITLE_ASC', -- TITLE_ASC, TITLE_DESC, PRICE_ASC, PRICE_DESC, NEWEST
        o_cursor        OUT SYS_REFCURSOR
    );

    -- Get single book details
    PROCEDURE get_book_details(
        p_book_id       IN  NUMBER,
        o_cursor        OUT SYS_REFCURSOR
    );

    -- Modify stock level directly
    PROCEDURE adjust_stock(
        p_book_id       IN  NUMBER,
        p_delta_quantity IN NUMBER,
        o_new_stock     OUT NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );
END PKG_BOOK_MGMT;
/

-- ============================================================================
-- Package: PKG_CART_MGMT
-- Description: Shopping cart lifecycle, item quantities and subtotal calculations.
-- ============================================================================
CREATE OR REPLACE PACKAGE PKG_CART_MGMT AS
    -- Add item to cart or increment quantity if already present
    PROCEDURE add_to_cart(
        p_user_id       IN  NUMBER,
        p_book_id       IN  NUMBER,
        p_quantity      IN  NUMBER DEFAULT 1,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- Update exact quantity of a cart item
    PROCEDURE update_cart_quantity(
        p_user_id       IN  NUMBER,
        p_book_id       IN  NUMBER,
        p_quantity      IN  NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- Remove an item from the cart
    PROCEDURE remove_from_cart(
        p_user_id       IN  NUMBER,
        p_book_id       IN  NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- Empty user's shopping cart
    PROCEDURE clear_cart(
        p_user_id       IN  NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- Fetch user cart with joined book details and subtotal
    PROCEDURE get_cart_items(
        p_user_id       IN  NUMBER,
        o_cart_cursor   OUT SYS_REFCURSOR,
        o_subtotal      OUT NUMBER,
        o_item_count    OUT NUMBER
    );
END PKG_CART_MGMT;
/

-- ============================================================================
-- Package: PKG_ORDER_MGMT
-- Description: Atomic order checkout, stock checks, state transitions and history.
-- ============================================================================
CREATE OR REPLACE PACKAGE PKG_ORDER_MGMT AS
    -- Process checkout and place order atomically from cart
    PROCEDURE place_order(
        p_user_id           IN  NUMBER,
        p_shipping_address  IN  VARCHAR2,
        p_contact_phone     IN  VARCHAR2,
        p_payment_method    IN  VARCHAR2 DEFAULT 'CARD',
        p_customer_notes    IN  VARCHAR2 DEFAULT NULL,
        o_order_id          OUT NUMBER,
        o_total_amount      OUT NUMBER,
        o_status            OUT VARCHAR2,
        o_message           OUT VARCHAR2
    );

    -- Retrieve all orders for a specific user
    PROCEDURE get_user_orders(
        p_user_id           IN  NUMBER,
        o_orders_cursor     OUT SYS_REFCURSOR
    );

    -- Retrieve comprehensive order header and item details
    PROCEDURE get_order_details(
        p_order_id          IN  NUMBER,
        o_order_cursor      OUT SYS_REFCURSOR,
        o_items_cursor      OUT SYS_REFCURSOR
    );

    -- Transition order status (PENDING -> PROCESSING -> SHIPPED -> DELIVERED)
    PROCEDURE update_order_status(
        p_order_id          IN  NUMBER,
        p_new_status        IN  VARCHAR2,
        p_changed_by        IN  VARCHAR2,
        o_status            OUT VARCHAR2,
        o_message           OUT VARCHAR2
    );

    -- Cancel an order and restore inventory if not yet shipped
    PROCEDURE cancel_order(
        p_order_id          IN  NUMBER,
        p_user_id           IN  NUMBER,
        p_reason            IN  VARCHAR2 DEFAULT 'Customer Request',
        o_status            OUT VARCHAR2,
        o_message           OUT VARCHAR2
    );
END PKG_ORDER_MGMT;
/

-- ============================================================================
-- Package: PKG_REPORTS
-- Description: Business analytics, best-seller rankings, sales trends and inventory.
-- ============================================================================
CREATE OR REPLACE PACKAGE PKG_REPORTS AS
    -- Best selling books ranked by units sold and revenue
    PROCEDURE get_best_selling_books(
        p_limit             IN  NUMBER DEFAULT 10,
        o_report_cursor     OUT SYS_REFCURSOR
    );

    -- Sales trends aggregated by month/year
    PROCEDURE get_sales_trends(
        p_months_back       IN  NUMBER DEFAULT 6,
        o_report_cursor     OUT SYS_REFCURSOR
    );

    -- Sales breakdown and performance by genre/category
    PROCEDURE get_category_performance(
        o_report_cursor     OUT SYS_REFCURSOR
    );

    -- Inventory alerts for books below replenishment threshold
    PROCEDURE get_low_stock_alert(
        p_threshold         IN  NUMBER DEFAULT 10,
        o_report_cursor     OUT SYS_REFCURSOR
    );

    -- Executive KPI summary for bookstore administration
    PROCEDURE get_dashboard_summary(
        o_total_users       OUT NUMBER,
        o_total_books       OUT NUMBER,
        o_total_orders      OUT NUMBER,
        o_total_revenue     OUT NUMBER,
        o_pending_orders    OUT NUMBER
    );
END PKG_REPORTS;
/
