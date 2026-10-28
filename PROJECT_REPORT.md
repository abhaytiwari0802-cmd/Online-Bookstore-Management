# PROJECT REPORT: ONLINE BOOKSTORE MANAGEMENT SYSTEM

**Project Title:** Online Bookstore Management System  
**Domain:** Database Management Systems / Enterprise Software Development  
**Core Technologies:** Oracle Database, PL/SQL (Packages, Procedures, Functions, Triggers, Views), Node.js REST API, HTML5, CSS3, JavaScript  
**Execution Environment:** Windows / Cross-platform  

---

## 1. Executive Summary

The **Online Bookstore Management System** is a software solution designed to provide customers with an interactive, secure platform to discover, search, review, and purchase books online, while providing store administrators with tools for inventory management, order pipeline tracking, and business intelligence reporting.

The core data integrity and business logic reside within **Oracle PL/SQL packages, stored procedures, triggers, and views**, ensuring data consistency, concurrency control, and transactional compliance (`ACID`).

---

## 2. Problem Statement & Motivation

Traditional brick-and-mortar bookstores and poorly architected e-commerce systems face significant challenges:
- **Inventory Discrepancies**: High risk of overselling stock during concurrent checkouts when transactions lack proper row-level locking.
- **Data Integrity & Security**: Insecure password handling, lack of parameterization leading to SQL injection, and missing audit trails for compliance.
- **Business Reporting Overhead**: Difficulty generating timely reports on bestsellers, revenue trends, and replenishment alerts without heavy operational queries.

This project addresses these challenges by offloading business logic, validations, and security into high-performance **PL/SQL database packages** coupled with responsive, modern web interfaces.

---

## 3. System Objectives

1. **User Management**:
   - Provide user registration with automated password hashing using SHA-256 and cryptographic salts.
   - Implement role-based authentication separating standard customers from store administrators.
   - Enable customer profile management and password modifications.
2. **Book & Inventory Management**:
   - Admin capabilities for adding, updating, and removing books.
   - Referential integrity preservation via automatic conversion to soft-deletion when historical order items reference a book.
   - Fast, multi-criteria search and dynamic filtering by title, author, category, price range, and sorting.
3. **Shopping Cart Management**:
   - Persistent basket lifecycle with stock verification before insertion.
   - Dynamic quantity adjustments, subtotal computation, and coupon discount calculations.
4. **Order Management & Concurrency Control**:
   - Atomic checkout transaction using row-level locking (`SELECT ... FOR UPDATE`) to prevent overselling.
   - Status pipeline tracking (`PENDING` &rarr; `PROCESSING` &rarr; `SHIPPED` &rarr; `DELIVERED`).
   - Order cancellation workflow with automated inventory restoration.
5. **Reporting & Analytics**:
   - Executive dashboard KPIs (Total Revenue, Orders, Titles, Active Customers, Pending Orders).
   - Best-selling books ranking by physical volume and financial revenue.
   - Monthly sales trends and category performance metrics.
   - Automated low-stock replenishment warnings.
6. **Auditing & Compliance**:
   - Autonomous triggers capturing DML changes into an `AUDIT_LOGS` table with timestamps, user context, and before/after values.

---

## 4. System Architecture

The application adopts a **Three-Tier Architecture**:

```
+-------------------------------------------------------------+
|                     PRESENTATION TIER                       |
|  - Customer Storefront (index.html, app.js)                 |
|  - Admin Management & Reporting Portal (admin.html, admin.js)|
|  - Interactive PL/SQL Source Explorer (plsql-runner.html)   |
+------------------------------+------------------------------+
                               | REST APIs (JSON over HTTP)
+------------------------------v------------------------------+
|                     APPLICATION TIER                        |
|  - Node.js Zero-Dependency HTTP Web Server (server.js)      |
|  - Relational PL/SQL Emulation Adapter (db-simulator.js)    |
|  - Oracle Database Adapter (oracle-connector.js)            |
+------------------------------+------------------------------+
                               | PL/SQL Stored Calls / SQL*Plus
+------------------------------v------------------------------+
|                       DATABASE TIER                         |
|  - Oracle Database (19c / 21c / 23c / XE)                   |
|  - Relational Tables, Constraints, Indexes & Sequences      |
|  - PL/SQL Packages: PKG_USER_MGMT, PKG_BOOK_MGMT,           |
|                     PKG_CART_MGMT, PKG_ORDER_MGMT,          |
|                     PKG_REPORTS                             |
|  - Triggers: TRG_PREVENT_NEGATIVE_STOCK, TRG_AUDIT_*        |
|  - Views: VW_ACTIVE_CATALOG, VW_USER_ORDERS_SUMMARY         |
+-------------------------------------------------------------+
```

---

## 5. Database Schema & Data Dictionary

The relational schema consists of 10 normalized tables designed to Third Normal Form (3NF).

### 5.1 Tables Summary

1. **`ROLES`**: Stores system roles (`ADMIN`, `CUSTOMER`).
2. **`USERS`**: User credentials, salt, SHA-256 hash, contact information, role mapping, and timestamps.
3. **`CATEGORIES`**: Classification of book genres (Computer Science, Databases, Fiction, etc.).
4. **`BOOKS`**: Master catalog of titles, authors, ISBNs, prices, stock levels, publishers, and ratings.
5. **`CART_ITEMS`**: User shopping cart items pending checkout with unique `(user_id, book_id)` constraint.
6. **`ORDERS`**: Master purchase order headers storing total amount, tax, shipping, discount, status, and shipping address.
7. **`ORDER_ITEMS`**: Detail line items associating books with orders, storing unit price and computed line total.
8. **`PAYMENTS`**: Transaction log storing payment methods, reference tokens, amounts, and statuses.
9. **`REVIEWS`**: Customer star ratings (1 to 5) and written feedback on books.
10. **`AUDIT_LOGS`**: Compliance trail recording all DML operations across critical entities.

### 5.2 Entity Relationship Diagram (ERD)

```
       +------------------+             +-------------------+
       |      ROLES       |             |    CATEGORIES     |
       +------------------+             +-------------------+
       | PK role_id       |             | PK category_id    |
       |    role_name     |             |    category_name  |
       +--------+---------+             +---------+---------+
                | 1                               | 1
                |                                 |
                | ∞                               | ∞
       +--------v---------+             +---------v---------+
       |      USERS       |             |       BOOKS       |
       +------------------+             +-------------------+
       | PK user_id       |             | PK book_id        |
       |    username (UQ) |             |    isbn (UQ)      |
       |    email (UQ)    |             |    title          |
       |    password_hash |             |    author         |
       |    salt          |             | FK category_id    |
       | FK role_id       |             |    price          |
       +---+----------+---+             |    stock_quantity |
           | 1        | 1               +----+----------+---+
           |          |                      | 1        | 1
           | ∞        | ∞                    |          |
+----------v---+    +-v------------+         |          |
|  CART_ITEMS  |    |    ORDERS    |         |          |
+--------------+    +--------------+         |          |
|PK cart_item_id|   |PK order_id   |         |          |
|FK user_id    |    |FK user_id    |         |          |
|FK book_id ---+----+   total_amt  |         |          |
|   quantity   |    |   status     |         |          |
+--------------+    +-------+------+         |          |
                            | 1              |          |
                            |                |          |
                            | ∞              | ∞        |
                    +-------v----------------v------+   |
                    |          ORDER_ITEMS          |   |
                    +-------------------------------+   |
                    | PK order_item_id              |   |
                    | FK order_id                   |   |
                    | FK book_id -------------------+   |
                    |    quantity                   |   |
                    |    unit_price                 |   |
                    |    line_total                 |   |
                    +-------------------------------+   |
                                                        |
                                                        | ∞
                                                +-------v-------+
                                                |    REVIEWS    |
                                                +---------------+
                                                | PK review_id  |
                                                | FK book_id    |
                                                | FK user_id    |
                                                |    rating     |
                                                +---------------+
```

---

## 6. PL/SQL Implementation Highlights

### 6.1 Package `PKG_USER_MGMT`
- **Password Security**: Uses Oracle's standard `STANDARD_HASH(salt || password, 'SHA256')`.
- **Exception Handling**: Intercepts `DUP_VAL_ON_INDEX` to return clear error messages when usernames or emails already exist.
- **Procedures**:
  - `register_user`: Validates input length and formats, generates salt, computes hash, inserts into `USERS`.
  - `authenticate_user`: Verifies credentials, checks active account status, updates `last_login`.
  - `update_profile` & `change_password`: Enables secure profile and password management.

### 6.2 Package `PKG_BOOK_MGMT`
- **Referential Protection**: When removing a book, checks `ORDER_ITEMS`. If historical orders exist, automatically defaults to soft-delete (`is_active = 'N'`), preventing `ORA-02292` integrity violation errors.
- **Dynamic Search Procedure**: `search_books` uses `SYS_REFCURSOR` with dynamic filtering across title, author, category, min/max price, and sorting criteria.

### 6.3 Package `PKG_CART_MGMT`
- **Real-Time Stock Checks**: Before inserting or updating cart items, queries `BOOKS.stock_quantity`. If `(existing_quantity + requested_quantity) > stock`, raises a business error.
- **Subtotal & Aggregates**: `get_cart_items` returns a joined cursor with computed line totals, subtotal, and total item count.

### 6.4 Package `PKG_ORDER_MGMT`
- **Atomic Checkout (`place_order`)**:
  - Uses row-level lock `SELECT stock_quantity, price, title FROM BOOKS WHERE book_id = c.book_id FOR UPDATE;`.
  - Verifies stock for all items before writing orders.
  - Inserts master header into `ORDERS` and detail items into `ORDER_ITEMS`.
  - Deducts inventory in `BOOKS`.
  - Records transaction in `PAYMENTS`.
  - Clears `CART_ITEMS` for the user.
  - Executes `COMMIT;` on success; on any exception, executes `ROLLBACK;` to keep database consistent.
- **Status Progression & Cancellation**: `update_order_status` manages transitions (`PENDING` &rarr; `PROCESSING` &rarr; `SHIPPED` &rarr; `DELIVERED`). If an order is marked `CANCELLED`, the procedure loops over its line items and restores the stock quantities back into `BOOKS`.

### 6.5 Package `PKG_REPORTS`
- `get_best_selling_books`: Uses `SUM(oi.quantity)` and `SUM(oi.line_total)` grouped by title and author.
- `get_sales_trends`: Aggregates orders by `TO_CHAR(order_date, 'YYYY-MM')`.
- `get_category_performance`: Groups revenue and units sold by category.
- `get_low_stock_alert`: Retrieves titles where `stock_quantity <= threshold`.
- `get_dashboard_summary`: Computes active users, active books, total orders, revenue, and pending orders.

### 6.6 Triggers
- `TRG_PREVENT_NEGATIVE_STOCK`: `BEFORE INSERT OR UPDATE OF stock_quantity ON BOOKS FOR EACH ROW`. Raises `ORA-20005` if stock drops below zero.
- `TRG_ORDER_ITEMS_CALC_TOTAL`: `BEFORE INSERT OR UPDATE OF quantity, unit_price ON ORDER_ITEMS FOR EACH ROW`. Enforces `:NEW.line_total := ROUND(:NEW.quantity * :NEW.unit_price, 2)`.
- `TRG_AUDIT_USERS` & `TRG_AUDIT_ORDERS`: `AFTER INSERT OR UPDATE OR DELETE`. Automatically logs DML changes to `AUDIT_LOGS`.

---

## 7. Testing & Verification Results

The automated test harness in `database/07_test_suite.sql` validates all core requirements:

| Test # | Test Case Description | Expected Result | Status |
|---|---|---|---|
| **01** | User Registration with valid credentials | User created with user_id, status = SUCCESS | **PASS** |
| **02** | Duplicate Email Prevention | Rejected with friendly error message | **PASS** |
| **03** | User Authentication with valid password | Authenticated, returns ADMIN role | **PASS** |
| **04** | User Authentication with invalid password | Rejected, status = ERROR, user_id = NULL | **PASS** |
| **05** | Add Book to Catalog via Admin Package | Book inserted into BOOKS with generated ID | **PASS** |
| **06** | Add Book to Shopping Cart | Record created in CART_ITEMS | **PASS** |
| **07** | Cart Subtotal Calculation | Correct subtotal calculated | **PASS** |
| **08** | Order Placement & Stock Deduction | Order created, stock deducted by ordered quantity | **PASS** |
| **09** | Order Cancellation & Stock Reversal | Order marked CANCELLED, stock restored to original count | **PASS** |
| **10** | Executive Analytics KPI Retrieval | Total users, books, orders, and revenue returned | **PASS** |

**Summary: 10/10 Unit & Integration Tests Passed (100% Success Rate).**

---

## 8. Conclusion

The Online Bookstore Management System demonstrates enterprise database design and software engineering principles:
- **Separation of Concerns**: Database-enforced business rules and transactions cleanly separated from the presentation layer.
- **Robustness**: Complete handling of edge cases, concurrency locks, and automatic rollbacks.
- **Security & Compliance**: Standard cryptographic hashing (SHA-256) and audit logging triggers.
- **Usability**: Accessible, intuitive user interfaces for customers, administrators, and database developers.
