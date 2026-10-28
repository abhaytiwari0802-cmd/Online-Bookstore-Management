# Online Bookstore Management System (Oracle PL/SQL)

An enterprise-grade **Online Bookstore Management System** built with **Oracle PL/SQL**, RESTful Web APIs, and a modern, responsive HTML5/CSS3/JavaScript web interface.

This application allows customers to browse, search, and purchase books online, while providing administrators with inventory management, order pipeline processing, and business analytics.

---

## 🌟 Features Implemented

### 1. User Management (`PKG_USER_MGMT`)
- **Registration**: Secure sign-up with SHA-256 cryptographic password hashing and unique salt generation (`STANDARD_HASH`).
- **Login / Authentication**: Secure credential validation with session tracking and last-login timestamps.
- **Profile Management**: View and update customer personal details, delivery addresses, and contact phone numbers.
- **Password Updates**: Secure password modification requiring current password verification.
- **Role-Based Access Control**: Granular roles (`ADMIN` vs `CUSTOMER`).

### 2. Book Management (`PKG_BOOK_MGMT`)
- **Add Books**: Administrators can register new titles with ISBNs, author, category, price, publisher, publication year, description, and cover images.
- **Update Books**: Real-time modification of prices, details, categories, and inventory counts.
- **Remove Books**: Intelligent deletion protecting referential integrity — automatically converts to soft-delete if historical purchase orders exist.
- **Dynamic Search & Filtering**: Multi-criteria search across title, author, ISBN, category/genre, price ranges, and sorting (price low-high, title A-Z, newest).
- **Stock Adjustments**: Direct inventory increment/decrement with non-negative constraints.

### 3. Shopping Cart (`PKG_CART_MGMT`)
- **Add to Cart**: Real-time stock availability check preventing customers from adding more items than currently in stock.
- **Quantity Update**: Adjust item counts with dynamic subtotal recalculation.
- **Item Removal & Clear Cart**: Remove single items or flush the entire cart.
- **Cart Summary & Subtotals**: Auto-computed subtotals, tax (5%), shipping calculation (free over $50, flat $5 below), and coupon discount support (`BOOKWORM10`, `READ20`, `FREESHIP`).

### 4. Order Management (`PKG_ORDER_MGMT`)
- **Place Order (Atomic Transaction)**:
  - Row-level locking on inventory (`SELECT ... FOR UPDATE`).
  - Immediate deduction of purchased stock.
  - Generates master order header (`ORDERS`) and detail line items (`ORDER_ITEMS`).
  - Clears user shopping cart.
  - Automatic `ROLLBACK` on any error (e.g. concurrent stock depletion) to guarantee zero data inconsistency.
- **Order Tracking & History**: Customers can track orders with status progressions: `PENDING` &rarr; `PROCESSING` &rarr; `SHIPPED` &rarr; `DELIVERED`.
- **Order Cancellation & Stock Rollback**: Customers or admins can cancel pending orders, which automatically returns the reserved units back into book stock.

### 5. Reporting & Analytics (`PKG_REPORTS`)
- **Best-Selling Books**: Ranks titles by total physical volume sold and total dollar revenue generated.
- **Sales Trends**: Monthly sales volume aggregates and average order values.
- **Category Performance**: Performance breakdown across genres (active titles, units sold, revenue).
- **Low Stock Replenishment Warnings**: Immediate alerts for inventory falling below safety thresholds (&le; 10 units).
- **Executive KPI Dashboard**: Summary metrics for total revenue, active titles, registered users, and pending orders.

### 6. PL/SQL Triggers & Security Auditing
- `TRG_PREVENT_NEGATIVE_STOCK`: Enforces inventory non-negativity constraint before insert/update.
- `TRG_ORDER_ITEMS_CALC_TOTAL`: Guarantees `line_total = quantity * unit_price`.
- `TRG_USERS_UPDATE_TIMESTAMP` & `TRG_BOOKS_UPDATE_TIMESTAMP`: Auto-syncs `updated_at`.
- `TRG_AUDIT_USERS` & `TRG_AUDIT_ORDERS`: Autonomous compliance triggers capturing all insertions, updates, and cancellations into the `AUDIT_LOGS` table.

---

## 🏗️ Architecture & Directory Structure

```
plsqlproject/
│
├── database/                                  # Pure Oracle PL/SQL Scripts
│   ├── 00_run_all.sql                         # Master one-click deployment runner
│   ├── 01_schema_ddl.sql                      # Tables, sequences, constraints, indexes
│   ├── 02_packages_spec.sql                   # PL/SQL Package Specifications
│   ├── 03_packages_body.sql                   # PL/SQL Package Bodies (Business Logic)
│   ├── 04_triggers.sql                        # Integrity & Audit Triggers
│   ├── 05_views_and_functions.sql             # Utility functions and analytics views
│   ├── 06_seed_data.sql                       # Initial seed catalog, users, orders
│   ├── 07_test_suite.sql                      # Automated DBMS_OUTPUT unit test runner
│   └── 08_cleanup.sql                         # Teardown / Drop scripts
│
├── public/                                    # Front-End Web Application
│   ├── css/
│   │   └── style.css                          # Modern responsive styling
│   ├── js/
│   │   ├── api.js                             # REST API client & session manager
│   │   ├── app.js                             # Storefront & cart behavior
│   │   └── admin.js                           # Admin dashboard & analytics
│   ├── index.html                             # Customer Storefront & Cart
│   ├── admin.html                             # Admin Portal & Inventory Management
│   └── plsql-runner.html                      # Interactive PL/SQL Source & Test Runner
│
├── server/                                    # Server Architecture
│   ├── server.js                              # Zero-dependency Node.js HTTP server
│   ├── db-simulator.js                        # In-memory PL/SQL engine (100% rule fidelity)
│   └── oracle-connector.js                    # Live Oracle DB adapter (node-oracledb)
│
├── start.bat                                  # Windows 1-Click Startup Script
├── start.sh                                   # Linux / macOS Startup Script
├── package.json                               # Node.js project manifest
├── README.md                                  # Comprehensive System Documentation
└── PROJECT_REPORT.md                          # Full Academic Project Report
```

---

## 🚀 Quick Start Guide

### Option A: Run the Interactive Web System (Immediate)

The application includes a zero-dependency web server that runs immediately without needing external package downloads or active Oracle listener configuration:

1. **Double-click `start.bat`** (or open PowerShell in this directory and run):
   ```powershell
   node server/server.js
   ```
2. **Open your web browser:**
   - **Customer Storefront:** [http://localhost:3000/index.html](http://localhost:3000/index.html)
   - **Admin Management Portal:** [http://localhost:3000/admin.html](http://localhost:3000/admin.html)
   - **Interactive PL/SQL Source Explorer:** [http://localhost:3000/plsql-runner.html](http://localhost:3000/plsql-runner.html)

3. **Pre-configured Demo Credentials:**
   | Role | Username / Email | Password |
   |---|---|---|
   | **System Administrator** | `admin` or `admin@bookstore.com` | `Admin@123` |
   | **Customer Account** | `johndoe` or `john@example.com` | `User@123` |
   | **Customer Account** | `sarahc` or `sarah@cyberdyne.org` | `User@123` |

---

### Option B: Deploying directly to an Oracle Database Instance

If you are using **Oracle Database 19c / 21c / 23c / XE** with **SQL Developer** or **SQL\*Plus**:

1. Open **SQL Developer** or **SQL\*Plus** and connect as your target schema user:
   ```sql
   CONNECT bookstore_user/your_password@localhost:1521/XEPDB1;
   ```
2. Navigate to the `database/` folder and execute the master runner:
   ```sql
   @00_run_all.sql
   ```
3. This executes all scripts sequentially:
   - `01_schema_ddl.sql` &rarr; Creates tables, sequences, indexes, and foreign keys.
   - `02_packages_spec.sql` &rarr; Compiles all 5 package specifications.
   - `03_packages_body.sql` &rarr; Compiles all 5 package bodies.
   - `04_triggers.sql` &rarr; Creates integrity and audit triggers.
   - `05_views_and_functions.sql` &rarr; Compiles custom views and functions.
   - `06_seed_data.sql` &rarr; Inserts initial realistic catalog, users, and orders.
   - `07_test_suite.sql` &rarr; Runs automated `DBMS_OUTPUT` unit tests and prints verification results.

---

## 🗄️ Database Relational Design (Schema)

```
 [ROLES] 1 ──────── ∞ [USERS] 1 ──────── ∞ [ORDERS] 1 ──────── ∞ [ORDER_ITEMS] ∞ ──────── 1 [BOOKS]
                        │                                                                      │
                        ∞                                                                      ∞
                   [CART_ITEMS]                                                           [CATEGORIES]
                        │
                        ∞
                   [AUDIT_LOGS]
```

### Table Definitions

| Table | Description | Primary Key | Key Foreign Keys |
|---|---|---|---|
| `ROLES` | User authorization roles | `role_id` | - |
| `USERS` | Customer & Admin accounts with salt and SHA-256 hash | `user_id` | `role_id` &rarr; `ROLES(role_id)` |
| `CATEGORIES` | Genre classifications | `category_id` | - |
| `BOOKS` | Catalog titles with pricing, stock & metadata | `book_id` | `category_id` &rarr; `CATEGORIES(category_id)` |
| `CART_ITEMS` | Pending shopping cart items per user | `cart_item_id` | `user_id` &rarr; `USERS`, `book_id` &rarr; `BOOKS` |
| `ORDERS` | Master purchase order headers with totals | `order_id` | `user_id` &rarr; `USERS(user_id)` |
| `ORDER_ITEMS`| Detail line items per order | `order_item_id` | `order_id` &rarr; `ORDERS`, `book_id` &rarr; `BOOKS` |
| `PAYMENTS` | Financial transaction audit trail | `payment_id` | `order_id` &rarr; `ORDERS(order_id)` |
| `REVIEWS` | Customer feedback and star ratings | `review_id` | `book_id` &rarr; `BOOKS`, `user_id` &rarr; `USERS` |
| `AUDIT_LOGS` | Compliance logging for all DML operations | `log_id` | - |

---

## 🧪 Automated Unit Test Harness (`07_test_suite.sql`)

The test script runs 10 automated test cases with `DBMS_OUTPUT`:
- **Test 01**: User registration with input validation.
- **Test 02**: Duplicate email detection (`DUP_VAL_ON_INDEX`).
- **Test 03**: Authentication with valid credentials.
- **Test 04**: Invalid credentials rejection.
- **Test 05**: Administrative book creation.
- **Test 06**: Cart item addition and quantity checking.
- **Test 07**: Subtotal and promotion coupon calculations.
- **Test 08**: Atomic order placement, row locking & inventory deduction.
- **Test 09**: Order cancellation and stock restoration.
- **Test 10**: Business analytics KPI retrieval.

---

## 🛡️ Security Implementation
1. **Password Hashing**: Cryptographic salt generation via `SYS_GUID()` / random bytes and SHA-256 hashing. Passwords are never stored in plaintext.
2. **SQL Injection Prevention**: All queries in PL/SQL and Node.js use parameterized queries and bind variables.
3. **Transaction Isolation**: Concurrency control via `SELECT ... FOR UPDATE` row-level locks on `BOOKS.stock_quantity`.
4. **Audit Logging**: Autonomous compliance triggers record administrative and user actions with old and new values.
