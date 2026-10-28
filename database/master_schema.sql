SET DEFINE OFF;
-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM
-- Master All-In-One Script: master_schema.sql
-- ============================================================================


-- >>> START: 01_schema_ddl.sql <<<
-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM
-- Script: 01_schema_ddl.sql
-- Description: DDL script to create tables, sequences, constraints, and indexes.
-- Target DB: Oracle Database 19c / 21c / 23c / XE
-- ============================================================================

-- Clean up existing tables if present
BEGIN
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN (
        'PAYMENTS', 'ORDER_ITEMS', 'ORDERS', 'CART_ITEMS', 'REVIEWS', 
        'BOOKS', 'CATEGORIES', 'AUDIT_LOGS', 'USERS', 'ROLES'
    )) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
END;
/

-- Clean up existing sequences if present
BEGIN
    FOR seq IN (SELECT sequence_name FROM user_sequences WHERE sequence_name IN (
        'SEQ_USERS', 'SEQ_CATEGORIES', 'SEQ_BOOKS', 'SEQ_CART', 
        'SEQ_ORDERS', 'SEQ_ORDER_ITEMS', 'SEQ_REVIEWS', 'SEQ_AUDIT', 'SEQ_PAYMENTS'
    )) LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || seq.sequence_name;
    END LOOP;
END;
/

-- Sequences for primary keys (starting above seed IDs to avoid collision)
CREATE SEQUENCE SEQ_USERS START WITH 2001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_CATEGORIES START WITH 201 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_BOOKS START WITH 6001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_CART START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_ORDERS START WITH 8001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_ORDER_ITEMS START WITH 100 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_REVIEWS START WITH 100 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_AUDIT START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_PAYMENTS START WITH 9100 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================================
-- Table: ROLES
-- Description: Stores user authorization roles (e.g., ADMIN, CUSTOMER).
-- ============================================================================
CREATE TABLE ROLES (
    role_id         NUMBER(5)           NOT NULL,
    role_name       VARCHAR2(50)        NOT NULL,
    description     VARCHAR2(255),
    created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_ROLES PRIMARY KEY (role_id),
    CONSTRAINT UQ_ROLE_NAME UNIQUE (role_name)
);

-- ============================================================================
-- Table: USERS
-- Description: Stores registered user credentials, profiles, and role linkage.
-- ============================================================================
CREATE TABLE USERS (
    user_id         NUMBER(10)          NOT NULL,
    username        VARCHAR2(60)        NOT NULL,
    email           VARCHAR2(120)       NOT NULL,
    password_hash   VARCHAR2(256)       NOT NULL,
    salt            VARCHAR2(64)        NOT NULL,
    full_name       VARCHAR2(120)       NOT NULL,
    phone           VARCHAR2(20),
    address         VARCHAR2(500),
    role_id         NUMBER(5) DEFAULT 2 NOT NULL, -- Default: Customer (2)
    is_active       CHAR(1) DEFAULT 'Y' NOT NULL,
    created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    last_login      TIMESTAMP,
    CONSTRAINT PK_USERS PRIMARY KEY (user_id),
    CONSTRAINT UQ_USER_USERNAME UNIQUE (username),
    CONSTRAINT UQ_USER_EMAIL UNIQUE (email),
    CONSTRAINT FK_USER_ROLE FOREIGN KEY (role_id) REFERENCES ROLES(role_id),
    CONSTRAINT CK_USER_ACTIVE CHECK (is_active IN ('Y', 'N'))
);

-- ============================================================================
-- Table: CATEGORIES
-- Description: Genre classification for books (e.g., Fiction, Science, etc.).
-- ============================================================================
CREATE TABLE CATEGORIES (
    category_id     NUMBER(5)           NOT NULL,
    category_name   VARCHAR2(100)       NOT NULL,
    description     VARCHAR2(500),
    is_active       CHAR(1) DEFAULT 'Y' NOT NULL,
    created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_CATEGORIES PRIMARY KEY (category_id),
    CONSTRAINT UQ_CATEGORY_NAME UNIQUE (category_name),
    CONSTRAINT CK_CATEGORY_ACTIVE CHECK (is_active IN ('Y', 'N'))
);

-- ============================================================================
-- Table: BOOKS
-- Description: Inventory catalog of books available in the online bookstore.
-- ============================================================================
CREATE TABLE BOOKS (
    book_id             NUMBER(10)          NOT NULL,
    isbn                VARCHAR2(20)        NOT NULL,
    title               VARCHAR2(255)       NOT NULL,
    author              VARCHAR2(200)       NOT NULL,
    category_id         NUMBER(5)           NOT NULL,
    price               NUMBER(10,2)        NOT NULL,
    stock_quantity      NUMBER(6) DEFAULT 0 NOT NULL,
    publisher           VARCHAR2(150),
    publication_year    NUMBER(4),
    description         VARCHAR2(4000),
    cover_image_url     VARCHAR2(1000),
    rating              NUMBER(3,2) DEFAULT 0.0,
    is_active           CHAR(1) DEFAULT 'Y' NOT NULL,
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_BOOKS PRIMARY KEY (book_id),
    CONSTRAINT UQ_BOOK_ISBN UNIQUE (isbn),
    CONSTRAINT FK_BOOK_CATEGORY FOREIGN KEY (category_id) REFERENCES CATEGORIES(category_id),
    CONSTRAINT CK_BOOK_PRICE CHECK (price >= 0),
    CONSTRAINT CK_BOOK_STOCK CHECK (stock_quantity >= 0),
    CONSTRAINT CK_BOOK_ACTIVE CHECK (is_active IN ('Y', 'N'))
);

-- ============================================================================
-- Table: CART_ITEMS
-- Description: Holds pending book items added by a user prior to checkout.
-- ============================================================================
CREATE TABLE CART_ITEMS (
    cart_item_id    NUMBER(10)          NOT NULL,
    user_id         NUMBER(10)          NOT NULL,
    book_id         NUMBER(10)          NOT NULL,
    quantity        NUMBER(4) DEFAULT 1 NOT NULL,
    added_at        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_CART_ITEMS PRIMARY KEY (cart_item_id),
    CONSTRAINT FK_CART_USER FOREIGN KEY (user_id) REFERENCES USERS(user_id) ON DELETE CASCADE,
    CONSTRAINT FK_CART_BOOK FOREIGN KEY (book_id) REFERENCES BOOKS(book_id) ON DELETE CASCADE,
    CONSTRAINT UQ_USER_BOOK_CART UNIQUE (user_id, book_id),
    CONSTRAINT CK_CART_QTY CHECK (quantity > 0)
);

-- ============================================================================
-- Table: ORDERS
-- Description: Master header record for customer book purchases.
-- ============================================================================
CREATE TABLE ORDERS (
    order_id            NUMBER(10)          NOT NULL,
    user_id             NUMBER(10)          NOT NULL,
    order_date          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    order_status        VARCHAR2(20) DEFAULT 'PENDING' NOT NULL,
    subtotal            NUMBER(10,2)        NOT NULL,
    tax_amount          NUMBER(10,2) DEFAULT 0.00 NOT NULL,
    shipping_fee        NUMBER(10,2) DEFAULT 0.00 NOT NULL,
    discount_amount     NUMBER(10,2) DEFAULT 0.00 NOT NULL,
    total_amount        NUMBER(10,2)        NOT NULL,
    shipping_address    VARCHAR2(500)       NOT NULL,
    contact_phone       VARCHAR2(20)        NOT NULL,
    payment_method      VARCHAR2(30) DEFAULT 'CARD' NOT NULL,
    payment_status      VARCHAR2(20) DEFAULT 'PAID' NOT NULL,
    customer_notes      VARCHAR2(500),
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_ORDERS PRIMARY KEY (order_id),
    CONSTRAINT FK_ORDER_USER FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT CK_ORDER_STATUS CHECK (order_status IN ('PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED')),
    CONSTRAINT CK_PAYMENT_STATUS CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED')),
    CONSTRAINT CK_ORDER_TOTAL CHECK (total_amount >= 0)
);

-- ============================================================================
-- Table: ORDER_ITEMS
-- Description: Detail line items associating books with specific orders.
-- ============================================================================
CREATE TABLE ORDER_ITEMS (
    order_item_id       NUMBER(10)          NOT NULL,
    order_id            NUMBER(10)          NOT NULL,
    book_id             NUMBER(10)          NOT NULL,
    quantity            NUMBER(4)           NOT NULL,
    unit_price          NUMBER(10,2)        NOT NULL,
    line_total          NUMBER(10,2)        NOT NULL,
    CONSTRAINT PK_ORDER_ITEMS PRIMARY KEY (order_item_id),
    CONSTRAINT FK_ITEM_ORDER FOREIGN KEY (order_id) REFERENCES ORDERS(order_id) ON DELETE CASCADE,
    CONSTRAINT FK_ITEM_BOOK FOREIGN KEY (book_id) REFERENCES BOOKS(book_id),
    CONSTRAINT CK_ITEM_QTY CHECK (quantity > 0),
    CONSTRAINT CK_ITEM_PRICE CHECK (unit_price >= 0),
    CONSTRAINT CK_ITEM_TOTAL CHECK (line_total >= 0)
);

-- ============================================================================
-- Table: PAYMENTS
-- Description: Financial payment records linked to orders.
-- ============================================================================
CREATE TABLE PAYMENTS (
    payment_id          NUMBER(10)          NOT NULL,
    order_id            NUMBER(10)          NOT NULL,
    payment_date        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    amount              NUMBER(10,2)        NOT NULL,
    payment_method      VARCHAR2(30) DEFAULT 'CARD' NOT NULL,
    transaction_ref     VARCHAR2(100),
    payment_status      VARCHAR2(20) DEFAULT 'PAID' NOT NULL,
    CONSTRAINT PK_PAYMENTS PRIMARY KEY (payment_id),
    CONSTRAINT FK_PAYMENT_ORDER FOREIGN KEY (order_id) REFERENCES ORDERS(order_id) ON DELETE CASCADE,
    CONSTRAINT CK_PAYMENT_AMT CHECK (amount >= 0)
);

-- ============================================================================
-- Table: REVIEWS
-- Description: Customer feedback and star ratings on books.
-- ============================================================================
CREATE TABLE REVIEWS (
    review_id           NUMBER(10)          NOT NULL,
    book_id             NUMBER(10)          NOT NULL,
    user_id             NUMBER(10)          NOT NULL,
    rating              NUMBER(1)           NOT NULL,
    review_text         VARCHAR2(1000),
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_REVIEWS PRIMARY KEY (review_id),
    CONSTRAINT FK_REV_BOOK FOREIGN KEY (book_id) REFERENCES BOOKS(book_id) ON DELETE CASCADE,
    CONSTRAINT FK_REV_USER FOREIGN KEY (user_id) REFERENCES USERS(user_id) ON DELETE CASCADE,
    CONSTRAINT CK_REV_RATING CHECK (rating BETWEEN 1 AND 5)
);

-- ============================================================================
-- Table: AUDIT_LOGS
-- Description: Security and compliance tracking for changes across tables.
-- ============================================================================
CREATE TABLE AUDIT_LOGS (
    log_id              NUMBER(12)          NOT NULL,
    table_name          VARCHAR2(50)        NOT NULL,
    action_type         VARCHAR2(10)        NOT NULL, -- INSERT, UPDATE, DELETE
    record_id           VARCHAR2(50),
    changed_by          VARCHAR2(60),
    old_values          VARCHAR2(4000),
    new_values          VARCHAR2(4000),
    log_timestamp       TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    ip_address          VARCHAR2(50),
    CONSTRAINT PK_AUDIT_LOGS PRIMARY KEY (log_id)
);

-- ============================================================================
-- Performance Indexes (Note: email has unique constraint index automatically)
-- ============================================================================
CREATE INDEX IDX_USERS_ROLE ON USERS(role_id);
CREATE INDEX IDX_BOOKS_CAT ON BOOKS(category_id);
CREATE INDEX IDX_BOOKS_TITLE ON BOOKS(UPPER(title));
CREATE INDEX IDX_BOOKS_AUTHOR ON BOOKS(UPPER(author));
CREATE INDEX IDX_BOOKS_PRICE ON BOOKS(price);
CREATE INDEX IDX_ORDERS_USER ON ORDERS(user_id);
CREATE INDEX IDX_ORDERS_STATUS ON ORDERS(order_status);
CREATE INDEX IDX_ORDERS_DATE ON ORDERS(order_date);
CREATE INDEX IDX_ORDER_ITEMS_ORDER ON ORDER_ITEMS(order_id);
CREATE INDEX IDX_ORDER_ITEMS_BOOK ON ORDER_ITEMS(book_id);
CREATE INDEX IDX_CART_USER ON CART_ITEMS(user_id);
CREATE INDEX IDX_PAYMENTS_ORDER ON PAYMENTS(order_id);
CREATE INDEX IDX_AUDIT_TABLE ON AUDIT_LOGS(table_name, log_timestamp);

COMMENT ON TABLE USERS IS 'User accounts with security credentials and role assignment';
COMMENT ON TABLE BOOKS IS 'Master catalog of books including pricing, stock, and metadata';
COMMENT ON TABLE ORDERS IS 'Customer purchase orders with financial totals and delivery status';
COMMENT ON TABLE AUDIT_LOGS IS 'System audit trail tracking DML operations for security and compliance';

COMMIT;

-- >>> END: 01_schema_ddl.sql <<<


-- >>> START: 02_packages_spec.sql <<<
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

-- >>> END: 02_packages_spec.sql <<<


-- >>> START: 03_packages_body.sql <<<
-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM
-- Script: 03_packages_body.sql
-- Description: Package Bodies containing complete business logic.
-- Target DB: Oracle Database 19c / 21c / 23c / XE
-- ============================================================================

-- ============================================================================
-- Package Body: PKG_USER_MGMT
-- ============================================================================
CREATE OR REPLACE PACKAGE BODY PKG_USER_MGMT AS

    FUNCTION hash_password(
        p_password IN VARCHAR2,
        p_salt     IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_hash VARCHAR2(256);
    BEGIN
        SELECT LOWER(RAWTOHEX(STANDARD_HASH(p_salt || p_password, 'SHA256')))
          INTO v_hash
          FROM DUAL;
        RETURN v_hash;
    END hash_password;

    FUNCTION generate_salt RETURN VARCHAR2 IS
        v_salt VARCHAR2(64);
    BEGIN
        SELECT LOWER(RAWTOHEX(SYS_GUID()))
          INTO v_salt
          FROM DUAL;
        RETURN v_salt;
    END generate_salt;

    PROCEDURE register_user(
        p_username      IN  VARCHAR2,
        p_email         IN  VARCHAR2,
        p_password      IN  VARCHAR2,
        p_full_name     IN  VARCHAR2,
        p_phone         IN  VARCHAR2 DEFAULT NULL,
        p_address       IN  VARCHAR2 DEFAULT NULL,
        p_role_id       IN  NUMBER DEFAULT 2,
        o_user_id       OUT NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
        v_salt          VARCHAR2(64);
        v_hash          VARCHAR2(256);
        v_count         NUMBER;
    BEGIN
        -- Validation
        IF p_username IS NULL OR LENGTH(TRIM(p_username)) < 3 THEN
            o_status := 'ERROR';
            o_message := 'Username must be at least 3 characters long.';
            RETURN;
        END IF;

        IF p_email IS NULL OR INSTR(p_email, '@') = 0 OR INSTR(p_email, '.') = 0 THEN
            o_status := 'ERROR';
            o_message := 'Please provide a valid email address.';
            RETURN;
        END IF;

        IF p_password IS NULL OR LENGTH(p_password) < 6 THEN
            o_status := 'ERROR';
            o_message := 'Password must be at least 6 characters long.';
            RETURN;
        END IF;

        -- Check duplicate username
        SELECT COUNT(*) INTO v_count FROM USERS WHERE LOWER(username) = LOWER(TRIM(p_username));
        IF v_count > 0 THEN
            o_status := 'ERROR';
            o_message := 'Username already taken. Please choose another.';
            RETURN;
        END IF;

        -- Check duplicate email
        SELECT COUNT(*) INTO v_count FROM USERS WHERE LOWER(email) = LOWER(TRIM(p_email));
        IF v_count > 0 THEN
            o_status := 'ERROR';
            o_message := 'An account with this email address already exists.';
            RETURN;
        END IF;

        -- Cryptographic security
        v_salt := generate_salt();
        v_hash := hash_password(p_password, v_salt);
        o_user_id := SEQ_USERS.NEXTVAL;

        INSERT INTO USERS (
            user_id, username, email, password_hash, salt,
            full_name, phone, address, role_id, is_active,
            created_at, updated_at
        ) VALUES (
            o_user_id, TRIM(p_username), LOWER(TRIM(p_email)), v_hash, v_salt,
            TRIM(p_full_name), TRIM(p_phone), TRIM(p_address), NVL(p_role_id, 2), 'Y',
            SYSTIMESTAMP, SYSTIMESTAMP
        );

        COMMIT;

        o_status := 'SUCCESS';
        o_message := 'User registered successfully.';
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            o_status := 'ERROR';
            o_message := 'Duplicate username or email encountered.';
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Registration failed: ' || SQLERRM;
    END register_user;

    PROCEDURE authenticate_user(
        p_username_or_email IN  VARCHAR2,
        p_password          IN  VARCHAR2,
        o_user_id           OUT NUMBER,
        o_username          OUT VARCHAR2,
        o_full_name         OUT VARCHAR2,
        o_role_name         OUT VARCHAR2,
        o_status            OUT VARCHAR2,
        o_message           OUT VARCHAR2
    ) IS
        v_hash          VARCHAR2(256);
        v_salt          VARCHAR2(64);
        v_stored_hash   VARCHAR2(256);
        v_active        CHAR(1);
        v_role_id       NUMBER;
    BEGIN
        SELECT u.user_id, u.username, u.full_name, u.password_hash, u.salt, u.is_active, r.role_name
          INTO o_user_id, o_username, o_full_name, v_stored_hash, v_salt, v_active, o_role_name
          FROM USERS u
          JOIN ROLES r ON u.role_id = r.role_id
         WHERE LOWER(u.username) = LOWER(TRIM(p_username_or_email))
            OR LOWER(u.email)    = LOWER(TRIM(p_username_or_email));

        IF v_active <> 'Y' THEN
            o_status := 'ERROR';
            o_message := 'Account is inactive or suspended. Contact administrator.';
            o_user_id := NULL;
            RETURN;
        END IF;

        v_hash := hash_password(p_password, v_salt);

        IF v_hash = v_stored_hash THEN
            UPDATE USERS
               SET last_login = SYSTIMESTAMP
             WHERE user_id = o_user_id;

            o_status := 'SUCCESS';
            o_message := 'Login successful.';
        ELSE
            o_status := 'ERROR';
            o_message := 'Invalid username or password.';
            o_user_id := NULL;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'Invalid username or password.';
            o_user_id := NULL;
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Authentication error: ' || SQLERRM;
            o_user_id := NULL;
    END authenticate_user;

    PROCEDURE get_user_profile(
        p_user_id           IN  NUMBER,
        o_profile_cursor    OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_profile_cursor FOR
            SELECT u.user_id, u.username, u.email, u.full_name, u.phone,
                   u.address, u.role_id, r.role_name, u.created_at, u.last_login
              FROM USERS u
              JOIN ROLES r ON u.role_id = r.role_id
             WHERE u.user_id = p_user_id;
    END get_user_profile;

    PROCEDURE update_profile(
        p_user_id       IN  NUMBER,
        p_full_name     IN  VARCHAR2,
        p_phone         IN  VARCHAR2,
        p_address       IN  VARCHAR2,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
    BEGIN
        UPDATE USERS
           SET full_name   = TRIM(p_full_name),
               phone       = TRIM(p_phone),
               address     = TRIM(p_address),
               updated_at  = SYSTIMESTAMP
         WHERE user_id     = p_user_id;

        IF SQL%ROWCOUNT = 0 THEN
            o_status := 'ERROR';
            o_message := 'User not found.';
        ELSE
            o_status := 'SUCCESS';
            o_message := 'Profile updated successfully.';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Update failed: ' || SQLERRM;
    END update_profile;

    PROCEDURE change_password(
        p_user_id       IN  NUMBER,
        p_old_password  IN  VARCHAR2,
        p_new_password  IN  VARCHAR2,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
        v_salt          VARCHAR2(64);
        v_stored_hash   VARCHAR2(256);
        v_new_salt      VARCHAR2(64);
        v_new_hash      VARCHAR2(256);
    BEGIN
        IF LENGTH(p_new_password) < 6 THEN
            o_status := 'ERROR';
            o_message := 'New password must be at least 6 characters long.';
            RETURN;
        END IF;

        SELECT password_hash, salt
          INTO v_stored_hash, v_salt
          FROM USERS
         WHERE user_id = p_user_id;

        IF hash_password(p_old_password, v_salt) <> v_stored_hash THEN
            o_status := 'ERROR';
            o_message := 'Current password is incorrect.';
            RETURN;
        END IF;

        v_new_salt := generate_salt();
        v_new_hash := hash_password(p_new_password, v_new_salt);

        UPDATE USERS
           SET password_hash = v_new_hash,
               salt          = v_new_salt,
               updated_at    = SYSTIMESTAMP
         WHERE user_id = p_user_id;

        o_status := 'SUCCESS';
        o_message := 'Password changed successfully.';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'User not found.';
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Failed to change password: ' || SQLERRM;
    END change_password;

END PKG_USER_MGMT;
/

-- ============================================================================
-- Package Body: PKG_BOOK_MGMT
-- ============================================================================
CREATE OR REPLACE PACKAGE BODY PKG_BOOK_MGMT AS

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
    ) IS
        v_count NUMBER;
    BEGIN
        IF p_price < 0 THEN
            o_status := 'ERROR';
            o_message := 'Price cannot be negative.';
            RETURN;
        END IF;

        IF p_stock_quantity < 0 THEN
            o_status := 'ERROR';
            o_message := 'Stock quantity cannot be negative.';
            RETURN;
        END IF;

        SELECT COUNT(*) INTO v_count FROM BOOKS WHERE isbn = TRIM(p_isbn);
        IF v_count > 0 THEN
            o_status := 'ERROR';
            o_message := 'A book with ISBN ' || p_isbn || ' already exists.';
            RETURN;
        END IF;

        o_book_id := SEQ_BOOKS.NEXTVAL;

        INSERT INTO BOOKS (
            book_id, isbn, title, author, category_id,
            price, stock_quantity, publisher, publication_year,
            description, cover_image_url, rating, is_active,
            created_at, updated_at
        ) VALUES (
            o_book_id, TRIM(p_isbn), TRIM(p_title), TRIM(p_author), p_category_id,
            p_price, p_stock_quantity, TRIM(p_publisher), p_publication_year,
            TRIM(p_description), TRIM(p_cover_image_url), 4.5, 'Y',
            SYSTIMESTAMP, SYSTIMESTAMP
        );

        COMMIT;

        o_status := 'SUCCESS';
        o_message := 'Book added successfully.';
    EXCEPTION
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Failed to add book: ' || SQLERRM;
    END add_book;

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
    ) IS
    BEGIN
        IF p_price < 0 THEN
            o_status := 'ERROR';
            o_message := 'Price cannot be negative.';
            RETURN;
        END IF;

        IF p_stock_quantity < 0 THEN
            o_status := 'ERROR';
            o_message := 'Stock cannot be negative.';
            RETURN;
        END IF;

        UPDATE BOOKS
           SET title            = TRIM(p_title),
               author           = TRIM(p_author),
               category_id      = p_category_id,
               price            = p_price,
               stock_quantity   = p_stock_quantity,
               publisher        = TRIM(p_publisher),
               publication_year = p_publication_year,
               description      = TRIM(p_description),
               cover_image_url  = NVL(TRIM(p_cover_image_url), cover_image_url),
               updated_at       = SYSTIMESTAMP
         WHERE book_id          = p_book_id;

        IF SQL%ROWCOUNT = 0 THEN
            o_status := 'ERROR';
            o_message := 'Book not found.';
        ELSE
            COMMIT;
            o_status := 'SUCCESS';
            o_message := 'Book details updated successfully.';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Failed to update book: ' || SQLERRM;
    END update_book;

    PROCEDURE remove_book(
        p_book_id       IN  NUMBER,
        p_hard_delete   IN  CHAR DEFAULT 'N',
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
        v_order_count   NUMBER;
    BEGIN
        IF p_hard_delete = 'Y' THEN
            SELECT COUNT(*) INTO v_order_count FROM ORDER_ITEMS WHERE book_id = p_book_id;
            IF v_order_count > 0 THEN
                -- Protect referential integrity: switch to soft delete
                UPDATE BOOKS SET is_active = 'N', updated_at = SYSTIMESTAMP WHERE book_id = p_book_id;
                o_status := 'SUCCESS';
                o_message := 'Book has historical orders, so it was marked inactive instead of hard-deleted.';
                RETURN;
            END IF;

            DELETE FROM CART_ITEMS WHERE book_id = p_book_id;
            DELETE FROM REVIEWS WHERE book_id = p_book_id;
            DELETE FROM BOOKS WHERE book_id = p_book_id;
        ELSE
            -- Soft delete
            UPDATE BOOKS SET is_active = 'N', updated_at = SYSTIMESTAMP WHERE book_id = p_book_id;
        END IF;

        IF SQL%ROWCOUNT = 0 THEN
            o_status := 'ERROR';
            o_message := 'Book not found.';
        ELSE
            COMMIT;
            o_status := 'SUCCESS';
            o_message := 'Book removed successfully.';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Failed to remove book: ' || SQLERRM;
    END remove_book;

    PROCEDURE search_books(
        p_query         IN  VARCHAR2 DEFAULT NULL,
        p_category_id   IN  NUMBER DEFAULT NULL,
        p_min_price     IN  NUMBER DEFAULT NULL,
        p_max_price     IN  NUMBER DEFAULT NULL,
        p_sort_by       IN  VARCHAR2 DEFAULT 'TITLE_ASC',
        o_cursor        OUT SYS_REFCURSOR
    ) IS
        v_like_query VARCHAR2(255) := '%' || UPPER(TRIM(p_query)) || '%';
    BEGIN
        OPEN o_cursor FOR
            SELECT b.book_id, b.isbn, b.title, b.author, b.category_id,
                   c.category_name, b.price, b.stock_quantity, b.publisher,
                   b.publication_year, b.description, b.cover_image_url,
                   b.rating, b.is_active, b.created_at
              FROM BOOKS b
              JOIN CATEGORIES c ON b.category_id = c.category_id
             WHERE b.is_active = 'Y'
               AND (p_query IS NULL OR (UPPER(b.title) LIKE v_like_query OR UPPER(b.author) LIKE v_like_query OR UPPER(b.isbn) LIKE v_like_query))
               AND (p_category_id IS NULL OR b.category_id = p_category_id)
               AND (p_min_price IS NULL OR b.price >= p_min_price)
               AND (p_max_price IS NULL OR b.price <= p_max_price)
             ORDER BY
                CASE WHEN p_sort_by = 'PRICE_ASC' THEN b.price END ASC,
                CASE WHEN p_sort_by = 'PRICE_DESC' THEN b.price END DESC,
                CASE WHEN p_sort_by = 'NEWEST' THEN b.book_id END DESC,
                CASE WHEN p_sort_by = 'TITLE_DESC' THEN UPPER(b.title) END DESC,
                CASE WHEN NVL(p_sort_by, 'TITLE_ASC') = 'TITLE_ASC' THEN UPPER(b.title) END ASC;
    END search_books;

    PROCEDURE get_book_details(
        p_book_id       IN  NUMBER,
        o_cursor        OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_cursor FOR
            SELECT b.book_id, b.isbn, b.title, b.author, b.category_id,
                   c.category_name, b.price, b.stock_quantity, b.publisher,
                   b.publication_year, b.description, b.cover_image_url,
                   b.rating, b.is_active, b.created_at, b.updated_at
              FROM BOOKS b
              JOIN CATEGORIES c ON b.category_id = c.category_id
             WHERE b.book_id = p_book_id;
    END get_book_details;

    PROCEDURE adjust_stock(
        p_book_id       IN  NUMBER,
        p_delta_quantity IN NUMBER,
        o_new_stock     OUT NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
        v_current_stock NUMBER;
    BEGIN
        SELECT stock_quantity INTO v_current_stock
          FROM BOOKS
         WHERE book_id = p_book_id
           FOR UPDATE;

        IF v_current_stock + p_delta_quantity < 0 THEN
            o_status := 'ERROR';
            o_message := 'Cannot reduce stock below 0. Current stock: ' || v_current_stock;
            o_new_stock := v_current_stock;
            RETURN;
        END IF;

        UPDATE BOOKS
           SET stock_quantity = stock_quantity + p_delta_quantity,
               updated_at     = SYSTIMESTAMP
         WHERE book_id        = p_book_id
        RETURNING stock_quantity INTO o_new_stock;

        o_status := 'SUCCESS';
        o_message := 'Stock updated successfully.';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'Book not found.';
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Failed to adjust stock: ' || SQLERRM;
    END adjust_stock;

END PKG_BOOK_MGMT;
/

-- ============================================================================
-- Package Body: PKG_CART_MGMT
-- ============================================================================
CREATE OR REPLACE PACKAGE BODY PKG_CART_MGMT AS

    PROCEDURE add_to_cart(
        p_user_id       IN  NUMBER,
        p_book_id       IN  NUMBER,
        p_quantity      IN  NUMBER DEFAULT 1,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
        v_stock         NUMBER;
        v_existing_qty  NUMBER := 0;
        v_cart_item_id  NUMBER;
    BEGIN
        IF p_quantity <= 0 THEN
            o_status := 'ERROR';
            o_message := 'Quantity must be at least 1.';
            RETURN;
        END IF;

        -- Verify book exists and check stock
        SELECT stock_quantity INTO v_stock
          FROM BOOKS
         WHERE book_id = p_book_id AND is_active = 'Y';

        BEGIN
            SELECT cart_item_id, quantity
              INTO v_cart_item_id, v_existing_qty
              FROM CART_ITEMS
             WHERE user_id = p_user_id AND book_id = p_book_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_cart_item_id := NULL;
                v_existing_qty := 0;
        END;

        IF (v_existing_qty + p_quantity) > v_stock THEN
            o_status := 'ERROR';
            o_message := 'Requested total (' || (v_existing_qty + p_quantity) || ') exceeds available stock (' || v_stock || ').';
            RETURN;
        END IF;

        IF v_cart_item_id IS NOT NULL THEN
            UPDATE CART_ITEMS
               SET quantity   = quantity + p_quantity,
                   updated_at = SYSTIMESTAMP
             WHERE cart_item_id = v_cart_item_id;
        ELSE
            INSERT INTO CART_ITEMS (
                cart_item_id, user_id, book_id, quantity, added_at, updated_at
            ) VALUES (
                SEQ_CART.NEXTVAL, p_user_id, p_book_id, p_quantity, SYSTIMESTAMP, SYSTIMESTAMP
            );
        END IF;

        o_status := 'SUCCESS';
        o_message := 'Book added to cart.';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'Book not found or is currently inactive.';
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Failed to add to cart: ' || SQLERRM;
    END add_to_cart;

    PROCEDURE update_cart_quantity(
        p_user_id       IN  NUMBER,
        p_book_id       IN  NUMBER,
        p_quantity      IN  NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
        v_stock NUMBER;
    BEGIN
        IF p_quantity <= 0 THEN
            remove_from_cart(p_user_id, p_book_id, o_status, o_message);
            RETURN;
        END IF;

        SELECT stock_quantity INTO v_stock
          FROM BOOKS
         WHERE book_id = p_book_id AND is_active = 'Y';

        IF p_quantity > v_stock THEN
            o_status := 'ERROR';
            o_message := 'Requested quantity (' || p_quantity || ') exceeds available stock (' || v_stock || ').';
            RETURN;
        END IF;

        UPDATE CART_ITEMS
           SET quantity   = p_quantity,
               updated_at = SYSTIMESTAMP
         WHERE user_id    = p_user_id
           AND book_id    = p_book_id;

        IF SQL%ROWCOUNT = 0 THEN
            o_status := 'ERROR';
            o_message := 'Item not in cart.';
        ELSE
            o_status := 'SUCCESS';
            o_message := 'Cart quantity updated.';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'Book not found or inactive.';
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Failed to update cart: ' || SQLERRM;
    END update_cart_quantity;

    PROCEDURE remove_from_cart(
        p_user_id       IN  NUMBER,
        p_book_id       IN  NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
    BEGIN
        DELETE FROM CART_ITEMS
         WHERE user_id = p_user_id
           AND book_id = p_book_id;

        IF SQL%ROWCOUNT = 0 THEN
            o_status := 'ERROR';
            o_message := 'Item not found in cart.';
        ELSE
            o_status := 'SUCCESS';
            o_message := 'Item removed from cart.';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Failed to remove from cart: ' || SQLERRM;
    END remove_from_cart;

    PROCEDURE clear_cart(
        p_user_id       IN  NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
    BEGIN
        DELETE FROM CART_ITEMS WHERE user_id = p_user_id;
        o_status := 'SUCCESS';
        o_message := 'Cart cleared successfully.';
    EXCEPTION
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Failed to clear cart: ' || SQLERRM;
    END clear_cart;

    PROCEDURE get_cart_items(
        p_user_id       IN  NUMBER,
        o_cart_cursor   OUT SYS_REFCURSOR,
        o_subtotal      OUT NUMBER,
        o_item_count    OUT NUMBER
    ) IS
    BEGIN
        SELECT NVL(SUM(c.quantity * b.price), 0),
               NVL(SUM(c.quantity), 0)
          INTO o_subtotal, o_item_count
          FROM CART_ITEMS c
          JOIN BOOKS b ON c.book_id = b.book_id
         WHERE c.user_id = p_user_id;

        OPEN o_cart_cursor FOR
            SELECT c.cart_item_id, c.book_id, b.title, b.author, b.isbn,
                   b.cover_image_url, b.price, c.quantity,
                   (c.quantity * b.price) AS line_total,
                   b.stock_quantity AS available_stock
              FROM CART_ITEMS c
              JOIN BOOKS b ON c.book_id = b.book_id
             WHERE c.user_id = p_user_id
             ORDER BY c.added_at DESC;
    END get_cart_items;

END PKG_CART_MGMT;
/

-- ============================================================================
-- Package Body: PKG_ORDER_MGMT
-- ============================================================================
CREATE OR REPLACE PACKAGE BODY PKG_ORDER_MGMT AS

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
    ) IS
        v_subtotal      NUMBER(10,2) := 0;
        v_tax           NUMBER(10,2) := 0;
        v_shipping      NUMBER(10,2) := 0;
        v_discount      NUMBER(10,2) := 0;
        v_cart_count    NUMBER := 0;
        v_stock         NUMBER;
        v_book_title    VARCHAR2(255);
        v_book_price    NUMBER(10,2);
    BEGIN
        -- Check if cart has items
        SELECT COUNT(*) INTO v_cart_count FROM CART_ITEMS WHERE user_id = p_user_id;
        IF v_cart_count = 0 THEN
            o_status := 'ERROR';
            o_message := 'Your shopping cart is empty.';
            RETURN;
        END IF;

        IF p_shipping_address IS NULL OR LENGTH(TRIM(p_shipping_address)) < 5 THEN
            o_status := 'ERROR';
            o_message := 'Please provide a complete shipping address.';
            RETURN;
        END IF;

        -- Row-level locking and stock verification across all items
        FOR item IN (SELECT c.book_id, c.quantity, b.title, b.price, b.stock_quantity
                       FROM CART_ITEMS c
                       JOIN BOOKS b ON c.book_id = b.book_id
                      WHERE c.user_id = p_user_id
                        FOR UPDATE OF b.stock_quantity) LOOP

            IF item.quantity > item.stock_quantity THEN
                o_status := 'ERROR';
                o_message := 'Insufficient stock for "' || item.title || '". Available: ' || item.stock_quantity || ', requested: ' || item.quantity;
                ROLLBACK;
                RETURN;
            END IF;

            v_subtotal := v_subtotal + (item.quantity * item.price);
        END LOOP;

        -- Calculate tax (5%), shipping fee ($5 flat, free over $50)
        v_tax := ROUND(v_subtotal * 0.05, 2);
        IF v_subtotal >= 50.00 THEN
            v_shipping := 0.00;
        ELSE
            v_shipping := 5.00;
        END IF;

        o_total_amount := v_subtotal + v_tax + v_shipping - v_discount;
        o_order_id := SEQ_ORDERS.NEXTVAL;

        -- Create master order record
        INSERT INTO ORDERS (
            order_id, user_id, order_date, order_status,
            subtotal, tax_amount, shipping_fee, discount_amount, total_amount,
            shipping_address, contact_phone, payment_method, payment_status,
            customer_notes, created_at, updated_at
        ) VALUES (
            o_order_id, p_user_id, SYSTIMESTAMP, 'PENDING',
            v_subtotal, v_tax, v_shipping, v_discount, o_total_amount,
            TRIM(p_shipping_address), TRIM(p_contact_phone), UPPER(p_payment_method), 'PAID',
            TRIM(p_customer_notes), SYSTIMESTAMP, SYSTIMESTAMP
        );

        -- Transfer cart items to order detail lines and deduct inventory
        FOR item IN (SELECT book_id, quantity FROM CART_ITEMS WHERE user_id = p_user_id) LOOP
            SELECT price INTO v_book_price FROM BOOKS WHERE book_id = item.book_id;

            INSERT INTO ORDER_ITEMS (
                order_item_id, order_id, book_id, quantity, unit_price, line_total
            ) VALUES (
                SEQ_ORDER_ITEMS.NEXTVAL, o_order_id, item.book_id, item.quantity,
                v_book_price, (item.quantity * v_book_price)
            );

            UPDATE BOOKS
               SET stock_quantity = stock_quantity - item.quantity,
                   updated_at     = SYSTIMESTAMP
             WHERE book_id        = item.book_id;
        END LOOP;

        -- Record payment transaction
        INSERT INTO PAYMENTS (
            payment_id, order_id, payment_date, amount,
            payment_method, transaction_ref, payment_status
        ) VALUES (
            SEQ_PAYMENTS.NEXTVAL, o_order_id, SYSTIMESTAMP, o_total_amount,
            UPPER(p_payment_method), 'TXN-' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISS') || '-' || o_order_id, 'PAID'
        );

        -- Clear user shopping cart
        DELETE FROM CART_ITEMS WHERE user_id = p_user_id;

        COMMIT;

        o_status := 'SUCCESS';
        o_message := 'Order #' || o_order_id || ' placed successfully!';
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Checkout failed: ' || SQLERRM;
    END place_order;

    PROCEDURE get_user_orders(
        p_user_id           IN  NUMBER,
        o_orders_cursor     OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_orders_cursor FOR
            SELECT o.order_id, o.order_date, o.order_status,
                   o.subtotal, o.tax_amount, o.shipping_fee, o.total_amount,
                   o.shipping_address, o.payment_method, o.payment_status,
                   (SELECT COUNT(*) FROM ORDER_ITEMS oi WHERE oi.order_id = o.order_id) AS total_items
              FROM ORDERS o
             WHERE o.user_id = p_user_id
             ORDER BY o.order_date DESC;
    END get_user_orders;

    PROCEDURE get_order_details(
        p_order_id          IN  NUMBER,
        o_order_cursor      OUT SYS_REFCURSOR,
        o_items_cursor      OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_order_cursor FOR
            SELECT o.order_id, o.user_id, u.username, u.full_name, u.email,
                   o.order_date, o.order_status, o.subtotal, o.tax_amount,
                   o.shipping_fee, o.discount_amount, o.total_amount,
                   o.shipping_address, o.contact_phone, o.payment_method,
                   o.payment_status, o.customer_notes
              FROM ORDERS o
              JOIN USERS u ON o.user_id = u.user_id
             WHERE o.order_id = p_order_id;

        OPEN o_items_cursor FOR
            SELECT oi.order_item_id, oi.book_id, b.title, b.author, b.isbn,
                   b.cover_image_url, oi.quantity, oi.unit_price, oi.line_total
              FROM ORDER_ITEMS oi
              JOIN BOOKS b ON oi.book_id = b.book_id
             WHERE oi.order_id = p_order_id;
    END get_order_details;

    PROCEDURE update_order_status(
        p_order_id          IN  NUMBER,
        p_new_status        IN  VARCHAR2,
        p_changed_by        IN  VARCHAR2,
        o_status            OUT VARCHAR2,
        o_message           OUT VARCHAR2
    ) IS
        v_current_status VARCHAR2(20);
    BEGIN
        SELECT order_status INTO v_current_status
          FROM ORDERS
         WHERE order_id = p_order_id
           FOR UPDATE;

        IF v_current_status = 'CANCELLED' THEN
            o_status := 'ERROR';
            o_message := 'Order is already cancelled and cannot be updated.';
            RETURN;
        END IF;

        IF v_current_status = 'DELIVERED' AND p_new_status <> 'DELIVERED' THEN
            o_status := 'ERROR';
            o_message := 'Delivered orders cannot transition back to another status.';
            RETURN;
        END IF;

        -- If cancelling order, restore inventory stock
        IF p_new_status = 'CANCELLED' AND v_current_status <> 'CANCELLED' THEN
            FOR item IN (SELECT book_id, quantity FROM ORDER_ITEMS WHERE order_id = p_order_id) LOOP
                UPDATE BOOKS
                   SET stock_quantity = stock_quantity + item.quantity,
                       updated_at     = SYSTIMESTAMP
                 WHERE book_id        = item.book_id;
            END LOOP;
        END IF;

        UPDATE ORDERS
           SET order_status = UPPER(p_new_status),
               updated_at   = SYSTIMESTAMP
         WHERE order_id     = p_order_id;

        COMMIT;

        o_status := 'SUCCESS';
        o_message := 'Order status updated to ' || UPPER(p_new_status);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'Order not found.';
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Failed to update order status: ' || SQLERRM;
    END update_order_status;

    PROCEDURE cancel_order(
        p_order_id          IN  NUMBER,
        p_user_id           IN  NUMBER,
        p_reason            IN  VARCHAR2 DEFAULT 'Customer Request',
        o_status            OUT VARCHAR2,
        o_message           OUT VARCHAR2
    ) IS
        v_order_user_id NUMBER;
        v_status        VARCHAR2(20);
    BEGIN
        SELECT user_id, order_status INTO v_order_user_id, v_status
          FROM ORDERS
         WHERE order_id = p_order_id;

        IF p_user_id IS NOT NULL AND v_order_user_id <> p_user_id THEN
            o_status := 'ERROR';
            o_message := 'Unauthorized. You can only cancel your own orders.';
            RETURN;
        END IF;

        IF v_status IN ('SHIPPED', 'DELIVERED') THEN
            o_status := 'ERROR';
            o_message := 'Cannot cancel order because it has already been ' || LOWER(v_status) || '.';
            RETURN;
        END IF;

        update_order_status(p_order_id, 'CANCELLED', 'User #' || p_user_id, o_status, o_message);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'Order not found.';
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Failed to cancel order: ' || SQLERRM;
    END cancel_order;

END PKG_ORDER_MGMT;
/

-- ============================================================================
-- Package Body: PKG_REPORTS
-- ============================================================================
CREATE OR REPLACE PACKAGE BODY PKG_REPORTS AS

    PROCEDURE get_best_selling_books(
        p_limit             IN  NUMBER DEFAULT 10,
        o_report_cursor     OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_report_cursor FOR
            SELECT * FROM (
                SELECT b.book_id, b.title, b.author, c.category_name,
                       b.price,
                       NVL(SUM(oi.quantity), 0) AS total_units_sold,
                       NVL(SUM(oi.line_total), 0) AS total_revenue
                  FROM BOOKS b
                  JOIN CATEGORIES c ON b.category_id = c.category_id
                  LEFT JOIN ORDER_ITEMS oi ON b.book_id = oi.book_id
                  LEFT JOIN ORDERS o ON oi.order_id = o.order_id AND o.order_status <> 'CANCELLED'
                 GROUP BY b.book_id, b.title, b.author, c.category_name, b.price
                 ORDER BY total_units_sold DESC, total_revenue DESC
            ) WHERE ROWNUM <= NVL(p_limit, 10);
    END get_best_selling_books;

    PROCEDURE get_sales_trends(
        p_months_back       IN  NUMBER DEFAULT 6,
        o_report_cursor     OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_report_cursor FOR
            SELECT TO_CHAR(order_date, 'YYYY-MM') AS month_year,
                   COUNT(order_id) AS total_orders,
                   SUM(total_amount) AS total_sales,
                   ROUND(AVG(total_amount), 2) AS avg_order_value
              FROM ORDERS
             WHERE order_status <> 'CANCELLED'
               AND order_date >= ADD_MONTHS(SYSDATE, -NVL(p_months_back, 6))
             GROUP BY TO_CHAR(order_date, 'YYYY-MM')
             ORDER BY month_year ASC;
    END get_sales_trends;

    PROCEDURE get_category_performance(
        o_report_cursor     OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_report_cursor FOR
            SELECT c.category_id, c.category_name,
                   COUNT(DISTINCT b.book_id) AS book_count,
                   NVL(SUM(oi.quantity), 0) AS total_units_sold,
                   NVL(SUM(oi.line_total), 0) AS category_revenue
              FROM CATEGORIES c
              LEFT JOIN BOOKS b ON c.category_id = b.category_id AND b.is_active = 'Y'
              LEFT JOIN ORDER_ITEMS oi ON b.book_id = oi.book_id
              LEFT JOIN ORDERS o ON oi.order_id = o.order_id AND o.order_status <> 'CANCELLED'
             GROUP BY c.category_id, c.category_name
             ORDER BY category_revenue DESC;
    END get_category_performance;

    PROCEDURE get_low_stock_alert(
        p_threshold         IN  NUMBER DEFAULT 10,
        o_report_cursor     OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_report_cursor FOR
            SELECT b.book_id, b.isbn, b.title, b.author, c.category_name,
                   b.stock_quantity, b.price
              FROM BOOKS b
              JOIN CATEGORIES c ON b.category_id = c.category_id
             WHERE b.is_active = 'Y'
               AND b.stock_quantity <= NVL(p_threshold, 10)
             ORDER BY b.stock_quantity ASC;
    END get_low_stock_alert;

    PROCEDURE get_dashboard_summary(
        o_total_users       OUT NUMBER,
        o_total_books       OUT NUMBER,
        o_total_orders      OUT NUMBER,
        o_total_revenue     OUT NUMBER,
        o_pending_orders    OUT NUMBER
    ) IS
    BEGIN
        SELECT COUNT(*) INTO o_total_users FROM USERS WHERE is_active = 'Y';
        SELECT COUNT(*) INTO o_total_books FROM BOOKS WHERE is_active = 'Y';
        SELECT COUNT(*) INTO o_total_orders FROM ORDERS WHERE order_status <> 'CANCELLED';
        SELECT NVL(SUM(total_amount), 0) INTO o_total_revenue FROM ORDERS WHERE order_status <> 'CANCELLED';
        SELECT COUNT(*) INTO o_pending_orders FROM ORDERS WHERE order_status = 'PENDING';
    END get_dashboard_summary;

END PKG_REPORTS;
/

-- >>> END: 03_packages_body.sql <<<


-- >>> START: 04_triggers.sql <<<
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

-- >>> END: 04_triggers.sql <<<


-- >>> START: 05_views_and_functions.sql <<<
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

-- >>> END: 05_views_and_functions.sql <<<


-- >>> START: 06_seed_data.sql <<<
-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM
-- Script: 06_seed_data.sql
-- Description: Realistic initial seed data for testing and demonstrations.
-- Target DB: Oracle Database 19c / 21c / 23c / XE
-- ============================================================================

-- Insert Roles
INSERT INTO ROLES (role_id, role_name, description) VALUES (1, 'ADMIN', 'System Administrator with full access');
INSERT INTO ROLES (role_id, role_name, description) VALUES (2, 'CUSTOMER', 'Registered standard shopper');

-- Insert Initial Users with seeded hashes (password: Admin@123 for admin, User@123 for customers)
-- Using SHA-256 with salt 's4lt_k3y_9876'
-- STANDARD_HASH('s4lt_k3y_9876' || 'Admin@123', 'SHA256')
-- Note: Seed script executes standard PL/SQL to invoke PKG_USER_MGMT.register_user for consistency!

DECLARE
    v_uid NUMBER;
    v_st  VARCHAR2(20);
    v_msg VARCHAR2(255);
BEGIN
    -- 1. Administrator Account
    PKG_USER_MGMT.register_user('admin', 'admin@bookstore.com', 'Admin@123', 'System Administrator', '+1-555-0100', '100 Tech Blvd, Silicon Valley, CA', 1, v_uid, v_st, v_msg);

    -- 2. Regular Customer: John Doe
    PKG_USER_MGMT.register_user('johndoe', 'john@example.com', 'User@123', 'John Doe', '+1-555-0101', '742 Evergreen Terrace, Springfield, OR', 2, v_uid, v_st, v_msg);

    -- 3. Regular Customer: Sarah Connor
    PKG_USER_MGMT.register_user('sarahc', 'sarah@cyberdyne.org', 'User@123', 'Sarah Connor', '+1-555-0102', '1244 Cyber Way, Los Angeles, CA', 2, v_uid, v_st, v_msg);

    -- 4. Regular Customer: Alice Smith
    PKG_USER_MGMT.register_user('alicesmith', 'alice@wonderland.com', 'User@123', 'Alice Smith', '+1-555-0103', '42 Rabbit Hole Lane, Oxford, UK', 2, v_uid, v_st, v_msg);
END;
/

-- Insert Categories
INSERT INTO CATEGORIES (category_id, category_name, description) VALUES (101, 'Computer Science', 'Algorithms, data structures, architectures, and programming');
INSERT INTO CATEGORIES (category_id, category_name, description) VALUES (102, 'Databases and SQL', 'Relational database systems, PL/SQL, indexing, and architecture');
INSERT INTO CATEGORIES (category_id, category_name, description) VALUES (103, 'Fiction and Literature', 'Classics, contemporary fiction, drama, and narrative novels');
INSERT INTO CATEGORIES (category_id, category_name, description) VALUES (104, 'Science and Nature', 'Physics, astronomy, biology, and scientific explorations');
INSERT INTO CATEGORIES (category_id, category_name, description) VALUES (105, 'Business and Leadership', 'Strategy, management, entrepreneurship, and economics');
INSERT INTO CATEGORIES (category_id, category_name, description) VALUES (106, 'Sci-Fi and Fantasy', 'Speculative fiction, epic fantasy, space operas, and dystopias');

-- Insert Catalog Books
INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5001, '978-0131103627', 'The C Programming Language', 'Brian W. Kernighan, Dennis M. Ritchie', 101, 44.99, 25,
    'Prentice Hall', 1988,
    'The authoritative guide to ANSI standard C by its original designers. Essential for every systems programmer.',
    'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=600&q=80', 4.9, 'Y'
);

INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5002, '978-0262033848', 'Introduction to Algorithms (CLRS)', 'Thomas H. Cormen, Charles E. Leiserson', 101, 89.50, 15,
    'MIT Press', 2009,
    'Comprehensive textbook on modern computer algorithms covering greedy algorithms, dynamic programming, graph theory, and NP-completeness.',
    'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?auto=format&fit=crop&w=600&q=80', 4.8, 'Y'
);

INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5003, '978-0596009205', 'Oracle PL/SQL Programming (6th Edition)', 'Steven Feuerstein, Bill Pribyl', 102, 59.99, 30,
    'O''Reilly Media', 2014,
    'The ultimate PL/SQL bible covering packages, triggers, cursor variables, dynamic SQL, autonomous transactions, and performance tuning.',
    'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=600&q=80', 4.9, 'Y'
);

INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5004, '978-1449373320', 'Designing Data-Intensive Applications', 'Martin Kleppmann', 102, 48.00, 20,
    'O''Reilly Media', 2017,
    'The definitive guide to the architecture of reliable, scalable, and maintainable distributed data systems and databases.',
    'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?auto=format&fit=crop&w=600&q=80', 5.0, 'Y'
);

INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5005, '978-0132350884', 'Clean Code: A Handbook of Agile Software Craftsmanship', 'Robert C. Martin', 101, 42.50, 4,
    'Prentice Hall', 2008,
    'Revolutionary guidelines and principles for writing clean, maintainable, self-documenting code with clear design patterns.',
    'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?auto=format&fit=crop&w=600&q=80', 4.7, 'Y'
);

INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5006, '978-0451524935', '1984', 'George Orwell', 103, 14.99, 50,
    'Signet Classic', 1949,
    'Classic dystopian social science fiction exploring government surveillance, propaganda, and thought control in Oceania.',
    'https://images.unsplash.com/photo-1495640388908-05fa85288e61?auto=format&fit=crop&w=600&q=80', 4.8, 'Y'
);

INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5007, '978-0743273565', 'The Great Gatsby', 'F. Scott Fitzgerald', 103, 12.95, 35,
    'Scribner', 1925,
    'Set in the Jazz Age, this masterpiece explores the American Dream, decadence, ambition, and tragic love on Long Island.',
    'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&w=600&q=80', 4.6, 'Y'
);

INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5008, '978-0553380163', 'A Brief History of Time', 'Stephen Hawking', 104, 18.50, 18,
    'Bantam', 1988,
    'A landmark volume in science writing that explores black holes, the big bang, general relativity, and quantum mechanics.',
    'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=600&q=80', 4.7, 'Y'
);

INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5009, '978-0812968255', 'Cosmos', 'Carl Sagan', 104, 19.99, 22,
    'Ballantine Books', 1980,
    'Lyrical and deeply moving journey exploring the universe, civilizations, and our journey of discovery through space and time.',
    'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?auto=format&fit=crop&w=600&q=80', 4.9, 'Y'
);

INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5010, '978-0060555665', 'The Intelligent Investor', 'Benjamin Graham', 105, 24.95, 2,
    'Harper Business', 1949,
    'The definitive book on value investing, teaching timeless philosophies to safeguard capital and achieve long-term wealth.',
    'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?auto=format&fit=crop&w=600&q=80', 4.7, 'Y'
);

INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5011, '978-0441172719', 'Dune', 'Frank Herbert', 106, 21.00, 40,
    'Chilton Books', 1965,
    'Set on the desert planet Arrakis, Dune tells the story of Paul Atreides and the most precious resource in the universe: the spice melange.',
    'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=600&q=80', 4.9, 'Y'
);

INSERT INTO BOOKS (
    book_id, isbn, title, author, category_id, price, stock_quantity,
    publisher, publication_year, description, cover_image_url, rating, is_active
) VALUES (
    5012, '978-0547928227', 'The Hobbit', 'J.R.R. Tolkien', 106, 16.50, 30,
    'George Allen & Unwin', 1937,
    'Bilbo Baggins is a hobbit who enjoys a comfortable, unambitious life, until Gandalf and a company of dwarves arrive on a grand quest.',
    'https://images.unsplash.com/photo-1507842229451-9f7a77e5e019?auto=format&fit=crop&w=600&q=80', 4.9, 'Y'
);

-- Seed an existing order for John Doe (user_id 1002) using PKG_ORDER_MGMT
DECLARE
    v_order_id NUMBER;
    v_total    NUMBER;
    v_status   VARCHAR2(20);
    v_msg      VARCHAR2(255);
BEGIN
    -- Put books in John's cart
    PKG_CART_MGMT.add_to_cart(1002, 5001, 1, v_status, v_msg);
    PKG_CART_MGMT.add_to_cart(1002, 5003, 1, v_status, v_msg);

    -- Checkout
    PKG_ORDER_MGMT.place_order(
        1002,
        '742 Evergreen Terrace, Springfield, OR',
        '+1-555-0101',
        'CREDIT_CARD',
        'Please leave near front porch door.',
        v_order_id,
        v_total,
        v_status,
        v_msg
    );

    -- Mark order as SHIPPED
    IF v_order_id IS NOT NULL THEN
        PKG_ORDER_MGMT.update_order_status(v_order_id, 'SHIPPED', 'System Initializer', v_status, v_msg);
    END IF;

    -- Add another order for Sarah Connor (user_id 1003)
    PKG_CART_MGMT.add_to_cart(1003, 5011, 2, v_status, v_msg);
    PKG_CART_MGMT.add_to_cart(1003, 5004, 1, v_status, v_msg);
    PKG_ORDER_MGMT.place_order(
        1003,
        '1244 Cyber Way, Los Angeles, CA',
        '+1-555-0102',
        'CARD',
        'Standard delivery.',
        v_order_id,
        v_total,
        v_status,
        v_msg
    );
END;
/

-- Sample customer reviews
INSERT INTO REVIEWS (review_id, book_id, user_id, rating, review_text)
VALUES (SEQ_REVIEWS.NEXTVAL, 5003, 1002, 5, 'Indispensable resource! The sections on bulk collecting and pipeline functions saved hours of work.');

INSERT INTO REVIEWS (review_id, book_id, user_id, rating, review_text)
VALUES (SEQ_REVIEWS.NEXTVAL, 5004, 1003, 5, 'Every software engineer building scalable systems needs to read this book twice.');

INSERT INTO REVIEWS (review_id, book_id, user_id, rating, review_text)
VALUES (SEQ_REVIEWS.NEXTVAL, 5011, 1002, 5, 'A masterpiece of sci-fi worldbuilding. Could not put it down!');

COMMIT;

-- >>> END: 06_seed_data.sql <<<


-- >>> START: 07_test_suite.sql <<<
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

-- >>> END: 07_test_suite.sql <<<

