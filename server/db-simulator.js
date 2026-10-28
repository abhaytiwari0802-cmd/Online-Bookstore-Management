// ============================================================================
// ONLINE BOOKSTORE MANAGEMENT SYSTEM
// File: server/db-simulator.js
// Description: In-memory relational database & PL/SQL package emulation engine.
// Provides 100% fidelity with Oracle PL/SQL business rules, triggers & constraints.
// ============================================================================

const crypto = require('crypto');

class DatabaseSimulator {
    constructor() {
        this.reset();
    }

    reset() {
        // Sequences
        this.seq = {
            users: 1005,
            categories: 107,
            books: 5013,
            cart: 10,
            orders: 7003,
            order_items: 20,
            reviews: 10,
            audit: 1,
            payments: 9005
        };

        // Tables
        this.roles = [
            { role_id: 1, role_name: 'ADMIN', description: 'System Administrator with full access' },
            { role_id: 2, role_name: 'CUSTOMER', description: 'Registered standard shopper' }
        ];

        this.categories = [
            { category_id: 101, category_name: 'Computer Science', description: 'Algorithms, data structures, architectures, and programming', is_active: 'Y' },
            { category_id: 102, category_name: 'Databases & SQL', description: 'Relational database systems, PL/SQL, indexing, and architecture', is_active: 'Y' },
            { category_id: 103, category_name: 'Fiction & Literature', description: 'Classics, contemporary fiction, drama, and narrative novels', is_active: 'Y' },
            { category_id: 104, category_name: 'Science & Nature', description: 'Physics, astronomy, biology, and scientific explorations', is_active: 'Y' },
            { category_id: 105, category_name: 'Business & Leadership', description: 'Strategy, management, entrepreneurship, and economics', is_active: 'Y' },
            { category_id: 106, category_name: 'Sci-Fi & Fantasy', description: 'Speculative fiction, epic fantasy, space operas, and dystopias', is_active: 'Y' }
        ];

        this.users = [];
        this.books = [];
        this.cart_items = [];
        this.orders = [];
        this.order_items = [];
        this.reviews = [];
        this.audit_logs = [];
        this.payments = [];

        this.seedInitialData();
    }

    // Helper: SHA-256 standard hash
    hashPassword(password, salt) {
        return crypto.createHash('sha256').update(salt + password).digest('hex');
    }

    generateSalt() {
        return crypto.randomBytes(16).toString('hex');
    }

    // Trigger emulation: TRG_AUDIT_USERS / TRG_AUDIT_ORDERS
    logAudit(tableName, actionType, recordId, changedBy, oldValues, newValues) {
        const logId = this.seq.audit++;
        const logEntry = {
            log_id: logId,
            table_name: tableName,
            action_type: actionType,
            record_id: String(recordId),
            changed_by: changedBy || 'SYSTEM',
            old_values: oldValues ? (typeof oldValues === 'string' ? oldValues : JSON.stringify(oldValues)) : null,
            new_values: newValues ? (typeof newValues === 'string' ? newValues : JSON.stringify(newValues)) : null,
            log_timestamp: new Date().toISOString()
        };
        this.audit_logs.unshift(logEntry);
        return logEntry;
    }

    seedInitialData() {
        // Seed users: admin (Admin@123), johndoe (User@123), sarahc (User@123)
        const saltAdmin = 's4lt_k3y_admin_001';
        this.users.push({
            user_id: 1001,
            username: 'admin',
            email: 'admin@bookstore.com',
            password_hash: this.hashPassword('Admin@123', saltAdmin),
            salt: saltAdmin,
            full_name: 'System Administrator',
            phone: '+1-555-0100',
            address: '100 Tech Blvd, Silicon Valley, CA',
            role_id: 1,
            is_active: 'Y',
            created_at: new Date('2024-01-01T08:00:00Z').toISOString(),
            updated_at: new Date('2024-01-01T08:00:00Z').toISOString(),
            last_login: new Date().toISOString()
        });

        const saltJohn = 's4lt_k3y_john_002';
        this.users.push({
            user_id: 1002,
            username: 'johndoe',
            email: 'john@example.com',
            password_hash: this.hashPassword('User@123', saltJohn),
            salt: saltJohn,
            full_name: 'John Doe',
            phone: '+1-555-0101',
            address: '742 Evergreen Terrace, Springfield, OR',
            role_id: 2,
            is_active: 'Y',
            created_at: new Date('2024-01-02T10:30:00Z').toISOString(),
            updated_at: new Date('2024-01-02T10:30:00Z').toISOString(),
            last_login: new Date().toISOString()
        });

        const saltSarah = 's4lt_k3y_sarah_003';
        this.users.push({
            user_id: 1003,
            username: 'sarahc',
            email: 'sarah@cyberdyne.org',
            password_hash: this.hashPassword('User@123', saltSarah),
            salt: saltSarah,
            full_name: 'Sarah Connor',
            phone: '+1-555-0102',
            address: '1244 Cyber Way, Los Angeles, CA',
            role_id: 2,
            is_active: 'Y',
            created_at: new Date('2024-01-05T14:15:00Z').toISOString(),
            updated_at: new Date('2024-01-05T14:15:00Z').toISOString(),
            last_login: new Date().toISOString()
        });

        // Seed books
        const rawBooks = [
            {
                book_id: 5001,
                isbn: '978-0131103627',
                title: 'The C Programming Language',
                author: 'Brian W. Kernighan, Dennis M. Ritchie',
                category_id: 101,
                price: 44.99,
                stock_quantity: 24,
                publisher: 'Prentice Hall',
                publication_year: 1988,
                description: 'The authoritative guide to ANSI standard C by its original designers. Essential for every systems programmer.',
                cover_image_url: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=600&q=80',
                rating: 4.9,
                is_active: 'Y'
            },
            {
                book_id: 5002,
                isbn: '978-0262033848',
                title: 'Introduction to Algorithms (CLRS)',
                author: 'Thomas H. Cormen, Charles E. Leiserson',
                category_id: 101,
                price: 89.50,
                stock_quantity: 15,
                publisher: 'MIT Press',
                publication_year: 2009,
                description: 'Comprehensive textbook on modern computer algorithms covering dynamic programming, graph theory, and NP-completeness.',
                cover_image_url: 'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?auto=format&fit=crop&w=600&q=80',
                rating: 4.8,
                is_active: 'Y'
            },
            {
                book_id: 5003,
                isbn: '978-0596009205',
                title: 'Oracle PL/SQL Programming (6th Edition)',
                author: 'Steven Feuerstein, Bill Pribyl',
                category_id: 102,
                price: 59.99,
                stock_quantity: 28,
                publisher: "O'Reilly Media",
                publication_year: 2014,
                description: 'The ultimate PL/SQL bible covering packages, triggers, cursor variables, dynamic SQL, and performance tuning.',
                cover_image_url: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=600&q=80',
                rating: 4.9,
                is_active: 'Y'
            },
            {
                book_id: 5004,
                isbn: '978-1449373320',
                title: 'Designing Data-Intensive Applications',
                author: 'Martin Kleppmann',
                category_id: 102,
                price: 48.00,
                stock_quantity: 19,
                publisher: "O'Reilly Media",
                publication_year: 2017,
                description: 'The definitive guide to the architecture of reliable, scalable, and maintainable distributed data systems and databases.',
                cover_image_url: 'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?auto=format&fit=crop&w=600&q=80',
                rating: 5.0,
                is_active: 'Y'
            },
            {
                book_id: 5005,
                isbn: '978-0132350884',
                title: 'Clean Code: A Handbook of Agile Software Craftsmanship',
                author: 'Robert C. Martin',
                category_id: 101,
                price: 42.50,
                stock_quantity: 4, // Low stock test case
                publisher: 'Prentice Hall',
                publication_year: 2008,
                description: 'Revolutionary guidelines and principles for writing clean, maintainable, self-documenting code with clear design patterns.',
                cover_image_url: 'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?auto=format&fit=crop&w=600&q=80',
                rating: 4.7,
                is_active: 'Y'
            },
            {
                book_id: 5006,
                isbn: '978-0451524935',
                title: '1984',
                author: 'George Orwell',
                category_id: 103,
                price: 14.99,
                stock_quantity: 50,
                publisher: 'Signet Classic',
                publication_year: 1949,
                description: 'Classic dystopian social science fiction exploring government surveillance, propaganda, and thought control in Oceania.',
                cover_image_url: 'https://images.unsplash.com/photo-1495640388908-05fa85288e61?auto=format&fit=crop&w=600&q=80',
                rating: 4.8,
                is_active: 'Y'
            },
            {
                book_id: 5007,
                isbn: '978-0743273565',
                title: 'The Great Gatsby',
                author: 'F. Scott Fitzgerald',
                category_id: 103,
                price: 12.95,
                stock_quantity: 35,
                publisher: 'Scribner',
                publication_year: 1925,
                description: 'Set in the Jazz Age, this masterpiece explores the American Dream, decadence, ambition, and tragic love on Long Island.',
                cover_image_url: 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&w=600&q=80',
                rating: 4.6,
                is_active: 'Y'
            },
            {
                book_id: 5008,
                isbn: '978-0553380163',
                title: 'A Brief History of Time',
                author: 'Stephen Hawking',
                category_id: 104,
                price: 18.50,
                stock_quantity: 18,
                publisher: 'Bantam',
                publication_year: 1988,
                description: 'A landmark volume in science writing that explores black holes, the big bang, general relativity, and quantum mechanics.',
                cover_image_url: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=600&q=80',
                rating: 4.7,
                is_active: 'Y'
            },
            {
                book_id: 5009,
                isbn: '978-0812968255',
                title: 'Cosmos',
                author: 'Carl Sagan',
                category_id: 104,
                price: 19.99,
                stock_quantity: 22,
                publisher: 'Ballantine Books',
                publication_year: 1980,
                description: 'Lyrical and deeply moving journey exploring the universe, civilizations, and our journey of discovery through space and time.',
                cover_image_url: 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?auto=format&fit=crop&w=600&q=80',
                rating: 4.9,
                is_active: 'Y'
            },
            {
                book_id: 5010,
                isbn: '978-0060555665',
                title: 'The Intelligent Investor',
                author: 'Benjamin Graham',
                category_id: 105,
                price: 24.95,
                stock_quantity: 2, // Low stock test case
                publisher: 'Harper Business',
                publication_year: 1949,
                description: 'The definitive book on value investing, teaching timeless philosophies to safeguard capital and achieve long-term wealth.',
                cover_image_url: 'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?auto=format&fit=crop&w=600&q=80',
                rating: 4.7,
                is_active: 'Y'
            },
            {
                book_id: 5011,
                isbn: '978-0441172719',
                title: 'Dune',
                author: 'Frank Herbert',
                category_id: 106,
                price: 21.00,
                stock_quantity: 38,
                publisher: 'Chilton Books',
                publication_year: 1965,
                description: 'Set on the desert planet Arrakis, Dune tells the story of Paul Atreides and the most precious resource in the universe: the spice melange.',
                cover_image_url: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=600&q=80',
                rating: 4.9,
                is_active: 'Y'
            },
            {
                book_id: 5012,
                isbn: '978-0547928227',
                title: 'The Hobbit',
                author: 'J.R.R. Tolkien',
                category_id: 106,
                price: 16.50,
                stock_quantity: 30,
                publisher: 'George Allen & Unwin',
                publication_year: 1937,
                description: 'Bilbo Baggins is a hobbit who enjoys a comfortable, unambitious life, until Gandalf and a company of dwarves arrive on a grand quest.',
                cover_image_url: 'https://images.unsplash.com/photo-1507842229451-9f7a77e5e019?auto=format&fit=crop&w=600&q=80',
                rating: 4.9,
                is_active: 'Y'
            }
        ];

        this.books = rawBooks.map(b => ({
            ...b,
            created_at: new Date('2024-01-01T00:00:00Z').toISOString(),
            updated_at: new Date('2024-01-01T00:00:00Z').toISOString()
        }));

        // Seed Orders for historical analytics
        this.orders.push({
            order_id: 7001,
            user_id: 1002,
            order_date: new Date(Date.now() - 15 * 86400000).toISOString(),
            order_status: 'DELIVERED',
            subtotal: 104.98,
            tax_amount: 5.25,
            shipping_fee: 0.00,
            discount_amount: 0.00,
            total_amount: 110.23,
            shipping_address: '742 Evergreen Terrace, Springfield, OR',
            contact_phone: '+1-555-0101',
            payment_method: 'CARD',
            payment_status: 'PAID',
            customer_notes: 'Leave on porch',
            created_at: new Date(Date.now() - 15 * 86400000).toISOString(),
            updated_at: new Date(Date.now() - 12 * 86400000).toISOString()
        });

        this.order_items.push(
            { order_item_id: 1, order_id: 7001, book_id: 5001, quantity: 1, unit_price: 44.99, line_total: 44.99 },
            { order_item_id: 2, order_id: 7001, book_id: 5003, quantity: 1, unit_price: 59.99, line_total: 59.99 }
        );

        this.orders.push({
            order_id: 7002,
            user_id: 1003,
            order_date: new Date(Date.now() - 2 * 86400000).toISOString(),
            order_status: 'PROCESSING',
            subtotal: 90.00,
            tax_amount: 4.50,
            shipping_fee: 0.00,
            discount_amount: 0.00,
            total_amount: 94.50,
            shipping_address: '1244 Cyber Way, Los Angeles, CA',
            contact_phone: '+1-555-0102',
            payment_method: 'CARD',
            payment_status: 'PAID',
            customer_notes: 'Rush delivery if possible',
            created_at: new Date(Date.now() - 2 * 86400000).toISOString(),
            updated_at: new Date(Date.now() - 2 * 86400000).toISOString()
        });

        this.order_items.push(
            { order_item_id: 3, order_id: 7002, book_id: 5011, quantity: 2, unit_price: 21.00, line_total: 42.00 },
            { order_item_id: 4, order_id: 7002, book_id: 5004, quantity: 1, unit_price: 48.00, line_total: 48.00 }
        );

        this.logAudit('ORDERS', 'INSERT', 7001, 'SYSTEM', null, 'Delivered historical order');
        this.logAudit('ORDERS', 'INSERT', 7002, 'SYSTEM', null, 'Processing active order');
    }

    // ========================================================================
    // PKG_USER_MGMT Implementation
    // ========================================================================
    pkg_user_mgmt_register(username, email, password, fullName, phone, address, roleId = 2) {
        if (!username || username.trim().length < 3) {
            return { status: 'ERROR', message: 'Username must be at least 3 characters long.' };
        }
        if (!email || !email.includes('@') || !email.includes('.')) {
            return { status: 'ERROR', message: 'Please provide a valid email address.' };
        }
        if (!password || password.length < 6) {
            return { status: 'ERROR', message: 'Password must be at least 6 characters long.' };
        }

        const normUser = username.trim().toLowerCase();
        const normEmail = email.trim().toLowerCase();

        if (this.users.some(u => u.username.toLowerCase() === normUser)) {
            return { status: 'ERROR', message: 'Username already taken. Please choose another.' };
        }
        if (this.users.some(u => u.email.toLowerCase() === normEmail)) {
            return { status: 'ERROR', message: 'An account with this email address already exists.' };
        }

        const salt = this.generateSalt();
        const hash = this.hashPassword(password, salt);
        const userId = this.seq.users++;

        const newUser = {
            user_id: userId,
            username: username.trim(),
            email: normEmail,
            password_hash: hash,
            salt: salt,
            full_name: fullName.trim(),
            phone: phone ? phone.trim() : null,
            address: address ? address.trim() : null,
            role_id: Number(roleId) || 2,
            is_active: 'Y',
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            last_login: null
        };

        this.users.push(newUser);
        this.logAudit('USERS', 'INSERT', userId, username, null, `Registered user ${username}`);

        return {
            status: 'SUCCESS',
            message: 'User registered successfully.',
            user_id: userId
        };
    }

    pkg_user_mgmt_authenticate(usernameOrEmail, password) {
        if (!usernameOrEmail || !password) {
            return { status: 'ERROR', message: 'Please provide username/email and password.' };
        }

        const norm = usernameOrEmail.trim().toLowerCase();
        const user = this.users.find(u => u.username.toLowerCase() === norm || u.email.toLowerCase() === norm);

        if (!user) {
            return { status: 'ERROR', message: 'Invalid username or password.' };
        }

        if (user.is_active !== 'Y') {
            return { status: 'ERROR', message: 'Account is inactive or suspended. Contact administrator.' };
        }

        const calculatedHash = this.hashPassword(password, user.salt);
        if (calculatedHash !== user.password_hash) {
            return { status: 'ERROR', message: 'Invalid username or password.' };
        }

        user.last_login = new Date().toISOString();
        const role = this.roles.find(r => r.role_id === user.role_id);

        return {
            status: 'SUCCESS',
            message: 'Login successful.',
            user: {
                user_id: user.user_id,
                username: user.username,
                email: user.email,
                full_name: user.full_name,
                phone: user.phone,
                address: user.address,
                role_id: user.role_id,
                role_name: role ? role.role_name : 'CUSTOMER'
            }
        };
    }

    pkg_user_mgmt_get_profile(userId) {
        const user = this.users.find(u => u.user_id === Number(userId));
        if (!user) return null;
        const role = this.roles.find(r => r.role_id === user.role_id);
        return {
            user_id: user.user_id,
            username: user.username,
            email: user.email,
            full_name: user.full_name,
            phone: user.phone,
            address: user.address,
            role_id: user.role_id,
            role_name: role ? role.role_name : 'CUSTOMER',
            created_at: user.created_at,
            last_login: user.last_login
        };
    }

    pkg_user_mgmt_update_profile(userId, fullName, phone, address) {
        const user = this.users.find(u => u.user_id === Number(userId));
        if (!user) return { status: 'ERROR', message: 'User not found.' };

        const oldValues = { full_name: user.full_name, phone: user.phone, address: user.address };
        user.full_name = fullName ? fullName.trim() : user.full_name;
        user.phone = phone ? phone.trim() : user.phone;
        user.address = address ? address.trim() : user.address;
        user.updated_at = new Date().toISOString();

        this.logAudit('USERS', 'UPDATE', user.user_id, user.username, oldValues, { full_name: user.full_name, phone: user.phone, address: user.address });

        return { status: 'SUCCESS', message: 'Profile updated successfully.' };
    }

    pkg_user_mgmt_change_password(userId, oldPassword, newPassword) {
        const user = this.users.find(u => u.user_id === Number(userId));
        if (!user) return { status: 'ERROR', message: 'User not found.' };

        if (!newPassword || newPassword.length < 6) {
            return { status: 'ERROR', message: 'New password must be at least 6 characters long.' };
        }

        const oldHash = this.hashPassword(oldPassword, user.salt);
        if (oldHash !== user.password_hash) {
            return { status: 'ERROR', message: 'Current password is incorrect.' };
        }

        const newSalt = this.generateSalt();
        user.salt = newSalt;
        user.password_hash = this.hashPassword(newPassword, newSalt);
        user.updated_at = new Date().toISOString();

        return { status: 'SUCCESS', message: 'Password changed successfully.' };
    }

    // ========================================================================
    // PKG_BOOK_MGMT Implementation
    // ========================================================================
    pkg_book_mgmt_search(query = '', categoryId = null, minPrice = null, maxPrice = null, sortBy = 'TITLE_ASC') {
        let results = this.books.filter(b => b.is_active === 'Y');

        if (query && query.trim()) {
            const q = query.trim().toLowerCase();
            results = results.filter(b =>
                b.title.toLowerCase().includes(q) ||
                b.author.toLowerCase().includes(q) ||
                b.isbn.toLowerCase().includes(q) ||
                (b.description && b.description.toLowerCase().includes(q))
            );
        }

        if (categoryId) {
            results = results.filter(b => b.category_id === Number(categoryId));
        }

        if (minPrice !== null && minPrice !== undefined && minPrice !== '') {
            results = results.filter(b => b.price >= Number(minPrice));
        }

        if (maxPrice !== null && maxPrice !== undefined && maxPrice !== '') {
            results = results.filter(b => b.price <= Number(maxPrice));
        }

        // Sort
        results.sort((a, b) => {
            switch (sortBy) {
                case 'PRICE_ASC': return a.price - b.price;
                case 'PRICE_DESC': return b.price - a.price;
                case 'NEWEST': return b.book_id - a.book_id;
                case 'TITLE_DESC': return b.title.localeCompare(a.title);
                case 'TITLE_ASC':
                default:
                    return a.title.localeCompare(b.title);
            }
        });

        // Enrich with category name
        return results.map(b => {
            const cat = this.categories.find(c => c.category_id === b.category_id);
            return {
                ...b,
                category_name: cat ? cat.category_name : 'General',
                stock_status: b.stock_quantity === 0 ? 'Out of Stock' : (b.stock_quantity <= 5 ? 'Low Stock' : 'In Stock')
            };
        });
    }

    pkg_book_mgmt_get_details(bookId) {
        const book = this.books.find(b => b.book_id === Number(bookId));
        if (!book) return null;
        const cat = this.categories.find(c => c.category_id === book.category_id);
        const bookReviews = this.reviews.filter(r => r.book_id === book.book_id);
        return {
            ...book,
            category_name: cat ? cat.category_name : 'General',
            stock_status: book.stock_quantity === 0 ? 'Out of Stock' : (book.stock_quantity <= 5 ? 'Low Stock' : 'In Stock'),
            reviews: bookReviews
        };
    }

    pkg_book_mgmt_add(data) {
        const { isbn, title, author, category_id, price, stock_quantity, publisher, publication_year, description, cover_image_url } = data;

        if (!isbn || !title || !author || !category_id || price === undefined || stock_quantity === undefined) {
            return { status: 'ERROR', message: 'Missing required book fields.' };
        }
        if (Number(price) < 0) {
            return { status: 'ERROR', message: 'Price cannot be negative.' };
        }
        if (Number(stock_quantity) < 0) {
            return { status: 'ERROR', message: 'Stock quantity cannot be negative.' };
        }
        if (this.books.some(b => b.isbn === isbn.trim())) {
            return { status: 'ERROR', message: `Book with ISBN ${isbn} already exists.` };
        }

        const bookId = this.seq.books++;
        const newBook = {
            book_id: bookId,
            isbn: isbn.trim(),
            title: title.trim(),
            author: author.trim(),
            category_id: Number(category_id),
            price: Number(price),
            stock_quantity: Number(stock_quantity),
            publisher: publisher ? publisher.trim() : null,
            publication_year: publication_year ? Number(publication_year) : null,
            description: description ? description.trim() : null,
            cover_image_url: cover_image_url ? cover_image_url.trim() : 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=600&q=80',
            rating: 4.5,
            is_active: 'Y',
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };

        this.books.push(newBook);
        this.logAudit('BOOKS', 'INSERT', bookId, 'ADMIN', null, `Added book "${title}"`);

        return { status: 'SUCCESS', message: 'Book added successfully.', book_id: bookId };
    }

    pkg_book_mgmt_update(bookId, data) {
        const book = this.books.find(b => b.book_id === Number(bookId));
        if (!book) return { status: 'ERROR', message: 'Book not found.' };

        if (data.price !== undefined && Number(data.price) < 0) {
            return { status: 'ERROR', message: 'Price cannot be negative.' };
        }
        if (data.stock_quantity !== undefined && Number(data.stock_quantity) < 0) {
            return { status: 'ERROR', message: 'Stock cannot be negative.' };
        }

        const oldValues = { ...book };

        if (data.title) book.title = data.title.trim();
        if (data.author) book.author = data.author.trim();
        if (data.category_id) book.category_id = Number(data.category_id);
        if (data.price !== undefined) book.price = Number(data.price);
        if (data.stock_quantity !== undefined) book.stock_quantity = Number(data.stock_quantity);
        if (data.publisher !== undefined) book.publisher = data.publisher ? data.publisher.trim() : null;
        if (data.publication_year !== undefined) book.publication_year = data.publication_year ? Number(data.publication_year) : null;
        if (data.description !== undefined) book.description = data.description ? data.description.trim() : null;
        if (data.cover_image_url) book.cover_image_url = data.cover_image_url.trim();
        book.updated_at = new Date().toISOString();

        this.logAudit('BOOKS', 'UPDATE', book.book_id, 'ADMIN', oldValues, book);

        return { status: 'SUCCESS', message: 'Book details updated successfully.' };
    }

    pkg_book_mgmt_remove(bookId, hardDelete = false) {
        const id = Number(bookId);
        const book = this.books.find(b => b.book_id === id);
        if (!book) return { status: 'ERROR', message: 'Book not found.' };

        const hasOrders = this.order_items.some(oi => oi.book_id === id);
        if (hardDelete && !hasOrders) {
            this.books = this.books.filter(b => b.book_id !== id);
            this.cart_items = this.cart_items.filter(c => c.book_id !== id);
            this.logAudit('BOOKS', 'DELETE', id, 'ADMIN', book, null);
            return { status: 'SUCCESS', message: 'Book permanently removed.' };
        } else {
            book.is_active = 'N';
            book.updated_at = new Date().toISOString();
            this.logAudit('BOOKS', 'UPDATE', id, 'ADMIN', { is_active: 'Y' }, { is_active: 'N' });
            return { status: 'SUCCESS', message: 'Book marked as inactive.' };
        }
    }

    // ========================================================================
    // PKG_CART_MGMT Implementation
    // ========================================================================
    pkg_cart_mgmt_add(userId, bookId, quantity = 1) {
        const uId = Number(userId);
        const bId = Number(bookId);
        const qty = Number(quantity) || 1;

        if (qty <= 0) return { status: 'ERROR', message: 'Quantity must be at least 1.' };

        const book = this.books.find(b => b.book_id === bId && b.is_active === 'Y');
        if (!book) return { status: 'ERROR', message: 'Book not found or is inactive.' };

        const existing = this.cart_items.find(c => c.user_id === uId && c.book_id === bId);
        const existingQty = existing ? existing.quantity : 0;

        if (existingQty + qty > book.stock_quantity) {
            return {
                status: 'ERROR',
                message: `Requested total (${existingQty + qty}) exceeds available stock (${book.stock_quantity}).`
            };
        }

        if (existing) {
            existing.quantity += qty;
            existing.updated_at = new Date().toISOString();
        } else {
            this.cart_items.push({
                cart_item_id: this.seq.cart++,
                user_id: uId,
                book_id: bId,
                quantity: qty,
                added_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            });
        }

        return { status: 'SUCCESS', message: 'Book added to cart.' };
    }

    pkg_cart_mgmt_update_qty(userId, bookId, quantity) {
        const uId = Number(userId);
        const bId = Number(bookId);
        const qty = Number(quantity);

        if (qty <= 0) {
            return this.pkg_cart_mgmt_remove(uId, bId);
        }

        const book = this.books.find(b => b.book_id === bId && b.is_active === 'Y');
        if (!book) return { status: 'ERROR', message: 'Book not found or inactive.' };

        if (qty > book.stock_quantity) {
            return {
                status: 'ERROR',
                message: `Requested quantity (${qty}) exceeds available stock (${book.stock_quantity}).`
            };
        }

        const item = this.cart_items.find(c => c.user_id === uId && c.book_id === bId);
        if (!item) return { status: 'ERROR', message: 'Item not in cart.' };

        item.quantity = qty;
        item.updated_at = new Date().toISOString();

        return { status: 'SUCCESS', message: 'Cart quantity updated.' };
    }

    pkg_cart_mgmt_remove(userId, bookId) {
        const uId = Number(userId);
        const bId = Number(bookId);

        const initialLen = this.cart_items.length;
        this.cart_items = this.cart_items.filter(c => !(c.user_id === uId && c.book_id === bId));

        if (this.cart_items.length === initialLen) {
            return { status: 'ERROR', message: 'Item not found in cart.' };
        }
        return { status: 'SUCCESS', message: 'Item removed from cart.' };
    }

    pkg_cart_mgmt_clear(userId) {
        const uId = Number(userId);
        this.cart_items = this.cart_items.filter(c => c.user_id !== uId);
        return { status: 'SUCCESS', message: 'Cart cleared successfully.' };
    }

    pkg_cart_mgmt_get_items(userId) {
        const uId = Number(userId);
        const userCart = this.cart_items.filter(c => c.user_id === uId);

        let subtotal = 0;
        let itemCount = 0;

        const items = userCart.map(c => {
            const book = this.books.find(b => b.book_id === c.book_id) || {};
            const lineTotal = Number((c.quantity * (book.price || 0)).toFixed(2));
            subtotal += lineTotal;
            itemCount += c.quantity;

            return {
                cart_item_id: c.cart_item_id,
                book_id: c.book_id,
                title: book.title || 'Unknown Title',
                author: book.author || '',
                isbn: book.isbn || '',
                cover_image_url: book.cover_image_url || '',
                price: book.price || 0,
                quantity: c.quantity,
                line_total: lineTotal,
                available_stock: book.stock_quantity !== undefined ? book.stock_quantity : 0
            };
        });

        subtotal = Number(subtotal.toFixed(2));

        return {
            items,
            subtotal,
            item_count: itemCount
        };
    }

    // ========================================================================
    // PKG_ORDER_MGMT Implementation
    // ========================================================================
    pkg_order_mgmt_place_order(userId, shippingAddress, contactPhone, paymentMethod = 'CARD', customerNotes = '', promoCode = '') {
        const uId = Number(userId);
        const userCart = this.cart_items.filter(c => c.user_id === uId);

        if (userCart.length === 0) {
            return { status: 'ERROR', message: 'Your shopping cart is empty.' };
        }

        if (!shippingAddress || shippingAddress.trim().length < 5) {
            return { status: 'ERROR', message: 'Please provide a valid shipping address.' };
        }

        // Verify stock for all items atomically
        for (const item of userCart) {
            const book = this.books.find(b => b.book_id === item.book_id);
            if (!book || book.is_active !== 'Y') {
                return { status: 'ERROR', message: `Book #${item.book_id} is no longer available.` };
            }
            if (item.quantity > book.stock_quantity) {
                return {
                    status: 'ERROR',
                    message: `Insufficient stock for "${book.title}". Available: ${book.stock_quantity}, requested: ${item.quantity}`
                };
            }
        }

        let subtotal = 0;
        userCart.forEach(item => {
            const book = this.books.find(b => b.book_id === item.book_id);
            subtotal += item.quantity * book.price;
        });
        subtotal = Number(subtotal.toFixed(2));

        // Promotional discount calculation (matching FN_CALCULATE_DISCOUNT)
        let discount = 0;
        if (promoCode) {
            const code = promoCode.trim().toUpperCase();
            if (code === 'BOOKWORM10') discount = Number((subtotal * 0.10).toFixed(2));
            else if (code === 'READ20' && subtotal >= 40.0) discount = Number((subtotal * 0.20).toFixed(2));
            else if (code === 'FREESHIP') discount = 5.00;
            else if (code === 'WELCOME5') discount = 5.00;
            if (discount > subtotal) discount = subtotal;
        }

        const tax = Number((subtotal * 0.05).toFixed(2));
        const shippingFee = subtotal >= 50.00 ? 0.00 : 5.00;
        const totalAmount = Number((subtotal + tax + shippingFee - discount).toFixed(2));

        const orderId = this.seq.orders++;

        const newOrder = {
            order_id: orderId,
            user_id: uId,
            order_date: new Date().toISOString(),
            order_status: 'PENDING',
            subtotal,
            tax_amount: tax,
            shipping_fee: shippingFee,
            discount_amount: discount,
            total_amount: totalAmount,
            shipping_address: shippingAddress.trim(),
            contact_phone: contactPhone ? contactPhone.trim() : '',
            payment_method: paymentMethod.toUpperCase(),
            payment_status: 'PAID',
            customer_notes: customerNotes ? customerNotes.trim() : null,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };

        this.orders.unshift(newOrder);

        // Deduct inventory and create order items
        userCart.forEach(item => {
            const book = this.books.find(b => b.book_id === item.book_id);
            const lineTotal = Number((item.quantity * book.price).toFixed(2));

            this.order_items.push({
                order_item_id: this.seq.order_items++,
                order_id: orderId,
                book_id: item.book_id,
                quantity: item.quantity,
                unit_price: book.price,
                line_total: lineTotal
            });

            // Trigger emulation: stock deduction
            book.stock_quantity -= item.quantity;
            book.updated_at = new Date().toISOString();
        });

        // Record payment
        this.payments.push({
            payment_id: this.seq.payments++,
            order_id: orderId,
            payment_date: new Date().toISOString(),
            amount: totalAmount,
            payment_method: paymentMethod.toUpperCase(),
            transaction_ref: `TXN-${Date.now()}-${orderId}`,
            payment_status: 'PAID'
        });

        // Clear cart
        this.cart_items = this.cart_items.filter(c => c.user_id !== uId);

        this.logAudit('ORDERS', 'INSERT', orderId, `User #${uId}`, null, `Placed order #${orderId} ($${totalAmount})`);

        return {
            status: 'SUCCESS',
            message: `Order #${orderId} placed successfully!`,
            order_id: orderId,
            total_amount: totalAmount
        };
    }

    pkg_order_mgmt_get_user_orders(userId) {
        const uId = Number(userId);
        const userOrders = this.orders.filter(o => o.user_id === uId);

        return userOrders.map(o => {
            const items = this.order_items.filter(oi => oi.order_id === o.order_id);
            return {
                ...o,
                total_items: items.reduce((sum, it) => sum + it.quantity, 0),
                items: items.map(oi => {
                    const book = this.books.find(b => b.book_id === oi.book_id) || {};
                    return {
                        ...oi,
                        title: book.title || 'Unknown Book',
                        cover_image_url: book.cover_image_url || ''
                    };
                })
            };
        });
    }

    pkg_order_mgmt_get_all_orders() {
        return this.orders.map(o => {
            const user = this.users.find(u => u.user_id === o.user_id) || {};
            const items = this.order_items.filter(oi => oi.order_id === o.order_id);
            return {
                ...o,
                username: user.username || 'Unknown',
                full_name: user.full_name || 'Customer',
                email: user.email || '',
                total_items: items.reduce((sum, it) => sum + it.quantity, 0),
                items: items.map(oi => {
                    const book = this.books.find(b => b.book_id === oi.book_id) || {};
                    return {
                        ...oi,
                        title: book.title || 'Unknown Book'
                    };
                })
            };
        });
    }

    pkg_order_mgmt_get_order_details(orderId) {
        const order = this.orders.find(o => o.order_id === Number(orderId));
        if (!order) return null;

        const user = this.users.find(u => u.user_id === order.user_id) || {};
        const items = this.order_items
            .filter(oi => oi.order_id === order.order_id)
            .map(oi => {
                const book = this.books.find(b => b.book_id === oi.book_id) || {};
                return {
                    ...oi,
                    title: book.title,
                    author: book.author,
                    isbn: book.isbn,
                    cover_image_url: book.cover_image_url
                };
            });

        return {
            ...order,
            customer_name: user.full_name,
            customer_email: user.email,
            items
        };
    }

    pkg_order_mgmt_update_status(orderId, newStatus, changedBy = 'ADMIN') {
        const order = this.orders.find(o => o.order_id === Number(orderId));
        if (!order) return { status: 'ERROR', message: 'Order not found.' };

        const targetStatus = newStatus.toUpperCase();
        const currentStatus = order.order_status;

        if (currentStatus === 'CANCELLED') {
            return { status: 'ERROR', message: 'Order is already cancelled and cannot be updated.' };
        }
        if (currentStatus === 'DELIVERED' && targetStatus !== 'DELIVERED') {
            return { status: 'ERROR', message: 'Delivered orders cannot transition back to another status.' };
        }

        // Trigger logic: If transitioning to CANCELLED, restore inventory
        if (targetStatus === 'CANCELLED' && currentStatus !== 'CANCELLED') {
            const items = this.order_items.filter(oi => oi.order_id === order.order_id);
            items.forEach(it => {
                const book = this.books.find(b => b.book_id === it.book_id);
                if (book) {
                    book.stock_quantity += it.quantity;
                    book.updated_at = new Date().toISOString();
                }
            });
        }

        const oldStatus = order.order_status;
        order.order_status = targetStatus;
        order.updated_at = new Date().toISOString();

        this.logAudit('ORDERS', 'UPDATE', order.order_id, changedBy, `Status: ${oldStatus}`, `Status: ${targetStatus}`);

        return { status: 'SUCCESS', message: `Order status updated to ${targetStatus}` };
    }

    pkg_order_mgmt_cancel(orderId, userId, reason = 'Customer Request') {
        const order = this.orders.find(o => o.order_id === Number(orderId));
        if (!order) return { status: 'ERROR', message: 'Order not found.' };

        if (userId && order.user_id !== Number(userId)) {
            return { status: 'ERROR', message: 'Unauthorized. You can only cancel your own orders.' };
        }

        if (['SHIPPED', 'DELIVERED'].includes(order.order_status)) {
            return { status: 'ERROR', message: `Cannot cancel order because it has already been ${order.order_status.toLowerCase()}.` };
        }

        return this.pkg_order_mgmt_update_status(orderId, 'CANCELLED', `User #${userId} (${reason})`);
    }

    // ========================================================================
    // PKG_REPORTS Implementation
    // ========================================================================
    pkg_reports_get_bestsellers(limit = 10) {
        const bookSales = {};
        this.order_items.forEach(oi => {
            const order = this.orders.find(o => o.order_id === oi.order_id);
            if (order && order.order_status !== 'CANCELLED') {
                if (!bookSales[oi.book_id]) {
                    bookSales[oi.book_id] = { units: 0, revenue: 0 };
                }
                bookSales[oi.book_id].units += oi.quantity;
                bookSales[oi.book_id].revenue += oi.line_total;
            }
        });

        const list = this.books.map(b => {
            const sales = bookSales[b.book_id] || { units: 0, revenue: 0 };
            const cat = this.categories.find(c => c.category_id === b.category_id);
            return {
                book_id: b.book_id,
                title: b.title,
                author: b.author,
                category_name: cat ? cat.category_name : 'General',
                price: b.price,
                stock_quantity: b.stock_quantity,
                total_units_sold: sales.units,
                total_revenue: Number(sales.revenue.toFixed(2))
            };
        });

        list.sort((a, b) => b.total_units_sold - a.total_units_sold || b.total_revenue - a.total_revenue);
        return list.slice(0, Number(limit) || 10);
    }

    pkg_reports_get_sales_trends() {
        const monthly = {};
        this.orders.forEach(o => {
            if (o.order_status !== 'CANCELLED') {
                const month = o.order_date.substring(0, 7); // YYYY-MM
                if (!monthly[month]) {
                    monthly[month] = { month_year: month, total_orders: 0, total_sales: 0 };
                }
                monthly[month].total_orders += 1;
                monthly[month].total_sales += o.total_amount;
            }
        });

        const trends = Object.values(monthly).map(m => ({
            ...m,
            total_sales: Number(m.total_sales.toFixed(2)),
            avg_order_value: Number((m.total_sales / m.total_orders).toFixed(2))
        }));

        trends.sort((a, b) => a.month_year.localeCompare(b.month_year));
        return trends;
    }

    pkg_reports_get_category_performance() {
        return this.categories.map(cat => {
            const catBooks = this.books.filter(b => b.category_id === cat.category_id);
            const bookIds = new Set(catBooks.map(b => b.book_id));

            let unitsSold = 0;
            let revenue = 0;

            this.order_items.forEach(oi => {
                if (bookIds.has(oi.book_id)) {
                    const order = this.orders.find(o => o.order_id === oi.order_id);
                    if (order && order.order_status !== 'CANCELLED') {
                        unitsSold += oi.quantity;
                        revenue += oi.line_total;
                    }
                }
            });

            return {
                category_id: cat.category_id,
                category_name: cat.category_name,
                book_count: catBooks.length,
                total_units_sold: unitsSold,
                category_revenue: Number(revenue.toFixed(2))
            };
        }).sort((a, b) => b.category_revenue - a.category_revenue);
    }

    pkg_reports_get_low_stock(threshold = 10) {
        return this.books
            .filter(b => b.is_active === 'Y' && b.stock_quantity <= Number(threshold))
            .map(b => {
                const cat = this.categories.find(c => c.category_id === b.category_id);
                return {
                    book_id: b.book_id,
                    isbn: b.isbn,
                    title: b.title,
                    author: b.author,
                    category_name: cat ? cat.category_name : 'General',
                    stock_quantity: b.stock_quantity,
                    price: b.price
                };
            })
            .sort((a, b) => a.stock_quantity - b.stock_quantity);
    }

    pkg_reports_get_dashboard_summary() {
        const activeUsers = this.users.filter(u => u.is_active === 'Y').length;
        const activeBooks = this.books.filter(b => b.is_active === 'Y').length;
        const validOrders = this.orders.filter(o => o.order_status !== 'CANCELLED');
        const totalRevenue = Number(validOrders.reduce((sum, o) => sum + o.total_amount, 0).toFixed(2));
        const pendingOrders = this.orders.filter(o => o.order_status === 'PENDING').length;
        const lowStockCount = this.books.filter(b => b.is_active === 'Y' && b.stock_quantity <= 5).length;

        return {
            total_users: activeUsers,
            total_books: activeBooks,
            total_orders: validOrders.length,
            total_revenue: totalRevenue,
            pending_orders: pendingOrders,
            low_stock_count: lowStockCount
        };
    }
}

// Export singleton instance
const dbSimulator = new DatabaseSimulator();
module.exports = dbSimulator;
