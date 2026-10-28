SET DEFINE OFF;
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
