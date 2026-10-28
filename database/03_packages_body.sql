SET DEFINE OFF;
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
