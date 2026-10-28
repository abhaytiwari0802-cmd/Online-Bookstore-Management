SET DEFINE OFF;
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
