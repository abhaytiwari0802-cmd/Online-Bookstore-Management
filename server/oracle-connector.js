// ============================================================================
// ONLINE BOOKSTORE MANAGEMENT SYSTEM
// File: server/oracle-connector.js
// Description: Oracle Database Connection & PL/SQL Stored Procedure Adapter.
// Connects to Oracle 19c/21c/23c/XE via node-oracledb with automatic fallback
// to db-simulator when Oracle is offline or in simulation mode.
// ============================================================================

const fs = require('fs');
const path = require('path');

// Auto-load .env if present
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
    try {
        const envContent = fs.readFileSync(envPath, 'utf8');
        envContent.split(/\r?\n/).forEach(line => {
            const trimmed = line.trim();
            if (trimmed && !trimmed.startsWith('#')) {
                const eqIdx = trimmed.indexOf('=');
                if (eqIdx !== -1) {
                    const key = trimmed.substring(0, eqIdx).trim();
                    const val = trimmed.substring(eqIdx + 1).trim();
                    if (!process.env[key]) {
                        process.env[key] = val;
                    }
                }
            }
        });
    } catch (e) {
        // ignore
    }
}

const dbSimulator = require('./db-simulator');

let oracledb = null;
let oraclePool = null;

// Dynamically load node-oracledb if available
try {
    oracledb = require('oracledb');
    // Default to outFormat as OBJECT so columns map to JSON property names
    oracledb.outFormat = oracledb.OUT_FORMAT_OBJECT;
    oracledb.autoCommit = true;
} catch (err) {
    // node-oracledb not installed; simulation engine active
}

const config = {
    user: process.env.DB_USER || 'bookstore_user',
    password: process.env.DB_PASSWORD || 'bookstore_pass',
    connectString: process.env.DB_CONNECT_STRING || 'localhost:1521/XEPDB1',
    useOracle: process.env.USE_ORACLE === 'true'
};

async function initOraclePool() {
    if (!config.useOracle) {
        console.log('[Database Engine] Operating in Built-in High-Fidelity PL/SQL Simulation Mode.');
        return false;
    }

    if (!oracledb) {
        console.warn('[Database Engine] USE_ORACLE is true, but "oracledb" package is not installed.');
        console.warn('                  Run: npm install oracledb');
        console.warn('                  Falling back to Built-in PL/SQL Simulation Mode.');
        return false;
    }

    try {
        oraclePool = await oracledb.createPool({
            user: config.user,
            password: config.password,
            connectString: config.connectString,
            poolMin: 1,
            poolMax: 5,
            poolIncrement: 1
        });
        console.log('================================================================');
        console.log(`[Oracle Database] Connected successfully to Oracle instance:`);
        console.log(`                  User: ${config.user}`);
        console.log(`                  Host/Service: ${config.connectString}`);
        console.log('================================================================');
        return true;
    } catch (err) {
        console.error('================================================================');
        console.error(`[Oracle Database] Connection failed: ${err.message}`);
        console.warn(`[Oracle Database] Falling back to Built-in PL/SQL Simulation Mode.`);
        console.error('================================================================');
        oraclePool = null;
        return false;
    }
}

function normalizeRow(row) {
    if (!row || typeof row !== 'object') return row;
    const norm = {};
    for (const key of Object.keys(row)) {
        norm[key.toLowerCase()] = row[key];
        norm[key.toUpperCase()] = row[key];
        norm[key] = row[key];
    }
    // Convert numeric fields properly
    const bookId = Number(norm.book_id ?? norm.id) || norm.book_id;
    norm.book_id = bookId;
    norm.BOOK_ID = bookId;

    const price = typeof norm.price === 'number' ? norm.price : (parseFloat(norm.price) || 0);
    norm.price = price;
    norm.PRICE = price;

    const stock = typeof norm.stock_quantity === 'number' ? norm.stock_quantity : (parseInt(norm.stock_quantity, 10) || 0);
    norm.stock_quantity = stock;
    norm.STOCK_QUANTITY = stock;

    const totalAmount = typeof norm.total_amount === 'number' ? norm.total_amount : (parseFloat(norm.total_amount) || 0);
    norm.total_amount = totalAmount;
    norm.TOTAL_AMOUNT = totalAmount;

    const subtotal = typeof norm.subtotal === 'number' ? norm.subtotal : (parseFloat(norm.subtotal) || 0);
    norm.subtotal = subtotal;
    norm.SUBTOTAL = subtotal;

    const lineTotal = typeof norm.line_total === 'number' ? norm.line_total : (parseFloat(norm.line_total) || 0);
    norm.line_total = lineTotal;
    norm.LINE_TOTAL = lineTotal;

    const quantity = typeof norm.quantity === 'number' ? norm.quantity : (parseInt(norm.quantity, 10) || 0);
    norm.quantity = quantity;
    norm.QUANTITY = quantity;

    const rating = typeof norm.rating === 'number' ? norm.rating : (parseFloat(norm.rating) || 4.5);
    norm.rating = rating;
    norm.RATING = rating;

    const unitsSold = typeof norm.total_units_sold === 'number' ? norm.total_units_sold : (parseInt(norm.total_units_sold, 10) || 0);
    norm.total_units_sold = unitsSold;
    norm.TOTAL_UNITS_SOLD = unitsSold;

    const totalRev = typeof norm.total_revenue === 'number' ? norm.total_revenue : (parseFloat(norm.total_revenue) || 0);
    norm.total_revenue = totalRev;
    norm.TOTAL_REVENUE = totalRev;

    const catRev = typeof norm.category_revenue === 'number' ? norm.category_revenue : (parseFloat(norm.category_revenue) || 0);
    norm.category_revenue = catRev;
    norm.CATEGORY_REVENUE = catRev;

    const avgVal = typeof norm.avg_order_value === 'number' ? norm.avg_order_value : (parseFloat(norm.avg_order_value) || 0);
    norm.avg_order_value = avgVal;
    norm.AVG_ORDER_VALUE = avgVal;

    const totalSales = typeof norm.total_sales === 'number' ? norm.total_sales : (parseFloat(norm.total_sales) || 0);
    norm.total_sales = totalSales;
    norm.TOTAL_SALES = totalSales;

    if (!norm.stock_status) {
        norm.stock_status = stock === 0 ? 'Out of Stock' : (stock <= 5 ? 'Low Stock' : 'In Stock');
    }
    norm.STOCK_STATUS = norm.stock_status;

    return norm;
}

function normalizeOutBinds(outBinds) {
    if (!outBinds || typeof outBinds !== 'object') return outBinds;
    const norm = {};
    for (const key of Object.keys(outBinds)) {
        norm[key] = outBinds[key];
        norm[key.toLowerCase()] = outBinds[key];
        norm[key.toUpperCase()] = outBinds[key];
    }
    return norm;
}

function getBind(outBinds, key) {
    if (!outBinds) return undefined;
    return outBinds[key] ?? outBinds[key.toLowerCase()] ?? outBinds[key.toUpperCase()];
}

// Helper to execute PL/SQL against Oracle Pool
async function executeOracle(sql, binds = {}, opts = {}) {
    if (!oraclePool) throw new Error('Oracle pool is not active');
    const conn = await oraclePool.getConnection();
    try {
        const res = await conn.execute(sql, binds, { autoCommit: true, ...opts });
        if (res && res.rows && Array.isArray(res.rows)) {
            res.rows = res.rows.map(normalizeRow);
        }
        if (res && res.outBinds && typeof res.outBinds === 'object') {
            res.outBinds = normalizeOutBinds(res.outBinds);
        }
        return res;
    } finally {
        await conn.close();
    }
}

// ----------------------------------------------------------------------------
// Unified Database Access Layer (Dual-Mode Oracle & Simulator)
// ----------------------------------------------------------------------------
const dbProxy = {
    isOracleActive: () => Boolean(oraclePool),
    initOraclePool,
    config,

    // Categories
    get categories() {
        return dbSimulator.categories;
    },

    async getCategories() {
        if (!oraclePool) return dbSimulator.categories;
        try {
            const res = await executeOracle(`SELECT category_id, category_name, description, is_active FROM CATEGORIES WHERE is_active = 'Y' ORDER BY category_id`);
            if (res.rows && res.rows.length) return res.rows;
            return dbSimulator.categories;
        } catch (err) {
            return dbSimulator.categories;
        }
    },

    // Audit logs
    get audit_logs() {
        return dbSimulator.audit_logs;
    },

    async getAuditLogs() {
        if (!oraclePool) return dbSimulator.audit_logs.slice(0, 50);
        try {
            const res = await executeOracle(`SELECT * FROM AUDIT_LOGS ORDER BY log_timestamp DESC FETCH FIRST 50 ROWS ONLY`);
            if (res.rows && res.rows.length) return res.rows;
            return dbSimulator.audit_logs.slice(0, 50);
        } catch (err) {
            return dbSimulator.audit_logs.slice(0, 50);
        }
    },

    reset() {
        return dbSimulator.reset();
    },

    // ------------------------------------------------------------------------
    // User Management (PKG_USER_MGMT)
    // ------------------------------------------------------------------------
    async pkg_user_mgmt_register(username, email, password, fullName, phone, address, roleId = 2) {
        if (!oraclePool) {
            return dbSimulator.pkg_user_mgmt_register(username, email, password, fullName, phone, address, roleId);
        }
        try {
            const sql = `
                BEGIN
                    PKG_USER_MGMT.register_user(
                        p_username  => :username,
                        p_email     => :email,
                        p_password  => :password,
                        p_full_name => :fullName,
                        p_phone     => :phone,
                        p_address   => :address,
                        p_role_id   => :roleId,
                        o_user_id   => :o_user_id,
                        o_status    => :o_status,
                        o_message   => :o_message
                    );
                END;
            `;
            const result = await executeOracle(sql, {
                username, email, password,
                fullName,
                phone: phone || null,
                address: address || null,
                roleId: Number(roleId) || 2,
                o_user_id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
                o_status: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                o_message: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return {
                status: getBind(result.outBinds, 'o_status') || 'SUCCESS',
                message: getBind(result.outBinds, 'o_message') || 'User registered successfully.',
                user_id: getBind(result.outBinds, 'o_user_id')
            };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    async pkg_user_mgmt_authenticate(usernameOrEmail, password) {
        if (!oraclePool) {
            return dbSimulator.pkg_user_mgmt_authenticate(usernameOrEmail, password);
        }
        try {
            const sql = `
                BEGIN
                    PKG_USER_MGMT.authenticate_user(
                        p_username_or_email => :u,
                        p_password          => :p,
                        o_user_id           => :o_user_id,
                        o_username          => :o_username,
                        o_full_name         => :o_full_name,
                        o_role_name         => :o_role_name,
                        o_status            => :o_status,
                        o_message           => :o_message
                    );
                END;
            `;
            const result = await executeOracle(sql, {
                u: usernameOrEmail,
                p: password,
                o_user_id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
                o_username: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 60 },
                o_full_name: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 120 },
                o_role_name: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                o_status: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                o_message: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });

            const status = getBind(result.outBinds, 'o_status');
            const message = getBind(result.outBinds, 'o_message');
            if (status === 'SUCCESS') {
                return {
                    status: 'SUCCESS',
                    message: message || 'Authentication successful',
                    user: {
                        user_id: getBind(result.outBinds, 'o_user_id'),
                        username: getBind(result.outBinds, 'o_username'),
                        full_name: getBind(result.outBinds, 'o_full_name'),
                        role_name: getBind(result.outBinds, 'o_role_name')
                    }
                };
            }
            return { status: 'ERROR', message: message || 'Authentication failed' };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    async pkg_user_mgmt_get_profile(userId) {
        if (!oraclePool) return dbSimulator.pkg_user_mgmt_get_profile(userId);
        try {
            const res = await executeOracle(`SELECT user_id, username, email, full_name, phone, address, role_id, created_at, last_login FROM USERS WHERE user_id = :id`, { id: userId });
            return res.rows && res.rows.length ? res.rows[0] : null;
        } catch (err) {
            return dbSimulator.pkg_user_mgmt_get_profile(userId);
        }
    },

    async pkg_user_mgmt_update_profile(userId, fullName, phone, address) {
        if (!oraclePool) return dbSimulator.pkg_user_mgmt_update_profile(userId, fullName, phone, address);
        try {
            const sql = `
                BEGIN
                    PKG_USER_MGMT.update_profile(:id, :fn, :ph, :ad, :st, :msg);
                END;
            `;
            const r = await executeOracle(sql, {
                id: userId, fn: fullName, ph: phone, ad: address,
                st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return { status: getBind(r.outBinds, 'st') || 'SUCCESS', message: getBind(r.outBinds, 'msg') || 'Profile updated successfully.' };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    async pkg_user_mgmt_change_password(userId, oldPassword, newPassword) {
        if (!oraclePool) return dbSimulator.pkg_user_mgmt_change_password(userId, oldPassword, newPassword);
        try {
            const sql = `BEGIN PKG_USER_MGMT.change_password(:id, :oldp, :newp, :st, :msg); END;`;
            const r = await executeOracle(sql, {
                id: userId, oldp: oldPassword, newp: newPassword,
                st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return { status: getBind(r.outBinds, 'st') || 'SUCCESS', message: getBind(r.outBinds, 'msg') || 'Password changed successfully.' };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    // ------------------------------------------------------------------------
    // Book Management (PKG_BOOK_MGMT)
    // ------------------------------------------------------------------------
    async pkg_book_mgmt_search(query = '', categoryId = null, minPrice = null, maxPrice = null, sortBy = 'TITLE_ASC') {
        if (!oraclePool) {
            return dbSimulator.pkg_book_mgmt_search(query, categoryId, minPrice, maxPrice, sortBy);
        }
        try {
            let sql = `
                SELECT b.book_id, b.isbn, b.title, b.author, b.category_id,
                       NVL(c.category_name, 'General') AS category_name, b.price, b.stock_quantity, b.publisher,
                       b.publication_year, b.description, b.cover_image_url,
                       b.rating, b.is_active,
                       CASE 
                           WHEN b.stock_quantity = 0 THEN 'Out of Stock'
                           WHEN b.stock_quantity <= 5 THEN 'Low Stock'
                           ELSE 'In Stock'
                       END AS stock_status
                  FROM BOOKS b
                  LEFT JOIN CATEGORIES c ON b.category_id = c.category_id
                 WHERE b.is_active = 'Y'
            `;
            const binds = {};
            if (query && query.trim()) {
                sql += ` AND (UPPER(b.title) LIKE :q OR UPPER(b.author) LIKE :q OR UPPER(b.isbn) LIKE :q) `;
                binds.q = `%${query.trim().toUpperCase()}%`;
            }
            if (categoryId) {
                sql += ` AND b.category_id = :cat `;
                binds.cat = Number(categoryId);
            }
            if (minPrice !== null && minPrice !== '') {
                sql += ` AND b.price >= :minp `;
                binds.minp = Number(minPrice);
            }
            if (maxPrice !== null && maxPrice !== '') {
                sql += ` AND b.price <= :maxp `;
                binds.maxp = Number(maxPrice);
            }

            if (sortBy === 'PRICE_ASC') sql += ` ORDER BY b.price ASC `;
            else if (sortBy === 'PRICE_DESC') sql += ` ORDER BY b.price DESC `;
            else if (sortBy === 'NEWEST') sql += ` ORDER BY b.book_id DESC `;
            else if (sortBy === 'TITLE_DESC') sql += ` ORDER BY UPPER(b.title) DESC `;
            else sql += ` ORDER BY UPPER(b.title) ASC `;

            const res = await executeOracle(sql, binds);
            return res.rows || [];
        } catch (err) {
            console.error('Oracle search error, fallback to simulator:', err);
            return dbSimulator.pkg_book_mgmt_search(query, categoryId, minPrice, maxPrice, sortBy);
        }
    },

    async pkg_book_mgmt_get_details(bookId) {
        if (!oraclePool) return dbSimulator.pkg_book_mgmt_get_details(bookId);
        try {
            const sql = `
                SELECT b.*, NVL(c.category_name, 'General') AS category_name,
                       CASE WHEN b.stock_quantity = 0 THEN 'Out of Stock'
                            WHEN b.stock_quantity <= 5 THEN 'Low Stock'
                            ELSE 'In Stock' END AS stock_status
                  FROM BOOKS b
                  LEFT JOIN CATEGORIES c ON b.category_id = c.category_id
                 WHERE b.book_id = :id
            `;
            const res = await executeOracle(sql, { id: bookId });
            if (!res.rows || !res.rows.length) return null;
            const book = res.rows[0];
            const revRes = await executeOracle(`SELECT * FROM REVIEWS WHERE book_id = :id`, { id: bookId });
            book.reviews = revRes.rows || [];
            return book;
        } catch (err) {
            return dbSimulator.pkg_book_mgmt_get_details(bookId);
        }
    },

    async pkg_book_mgmt_add(data) {
        if (!oraclePool) return dbSimulator.pkg_book_mgmt_add(data);
        try {
            const sql = `
                BEGIN
                    PKG_BOOK_MGMT.add_book(
                        p_isbn             => :isbn,
                        p_title            => :title,
                        p_author           => :author,
                        p_category_id      => :cat,
                        p_price            => :price,
                        p_stock_quantity   => :stock,
                        p_publisher        => :pub,
                        p_publication_year => :yr,
                        p_description      => :descr,
                        p_cover_image_url  => :cover,
                        o_book_id          => :o_id,
                        o_status           => :o_st,
                        o_message          => :o_msg
                    );
                END;
            `;
            const res = await executeOracle(sql, {
                isbn: data.isbn,
                title: data.title,
                author: data.author,
                cat: Number(data.category_id),
                price: Number(data.price),
                stock: Number(data.stock_quantity),
                pub: data.publisher || null,
                yr: Number(data.publication_year) || null,
                descr: data.description || null,
                cover: data.cover_image_url || null,
                o_id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
                o_st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                o_msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return {
                status: getBind(res.outBinds, 'o_st') || 'SUCCESS',
                message: getBind(res.outBinds, 'o_msg') || 'Book added successfully.',
                book_id: getBind(res.outBinds, 'o_id')
            };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    async pkg_book_mgmt_update(bookId, data) {
        if (!oraclePool) return dbSimulator.pkg_book_mgmt_update(bookId, data);
        try {
            const sql = `
                BEGIN
                    PKG_BOOK_MGMT.update_book(
                        p_book_id          => :id,
                        p_title            => :title,
                        p_author           => :author,
                        p_category_id      => :cat,
                        p_price            => :price,
                        p_stock_quantity   => :stock,
                        p_publisher        => :pub,
                        p_publication_year => :yr,
                        p_description      => :descr,
                        p_cover_image_url  => :cover,
                        o_status           => :o_st,
                        o_message          => :o_msg
                    );
                END;
            `;
            const res = await executeOracle(sql, {
                id: Number(bookId),
                title: data.title,
                author: data.author,
                cat: Number(data.category_id),
                price: Number(data.price),
                stock: Number(data.stock_quantity),
                pub: data.publisher || null,
                yr: Number(data.publication_year) || null,
                descr: data.description || null,
                cover: data.cover_image_url || null,
                o_st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                o_msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return {
                status: getBind(res.outBinds, 'o_st') || 'SUCCESS',
                message: getBind(res.outBinds, 'o_msg') || 'Book updated successfully.'
            };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    async pkg_book_mgmt_remove(bookId, hardDelete = false) {
        if (!oraclePool) return dbSimulator.pkg_book_mgmt_remove(bookId, hardDelete);
        try {
            const sql = `BEGIN PKG_BOOK_MGMT.remove_book(:id, :hard, :st, :msg); END;`;
            const res = await executeOracle(sql, {
                id: Number(bookId),
                hard: hardDelete ? 'Y' : 'N',
                st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return {
                status: getBind(res.outBinds, 'st') || 'SUCCESS',
                message: getBind(res.outBinds, 'msg') || 'Book removed successfully.'
            };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    // ------------------------------------------------------------------------
    // Shopping Cart (PKG_CART_MGMT)
    // ------------------------------------------------------------------------
    async pkg_cart_mgmt_add(userId, bookId, quantity = 1) {
        if (!oraclePool) return dbSimulator.pkg_cart_mgmt_add(userId, bookId, quantity);
        try {
            const sql = `BEGIN PKG_CART_MGMT.add_to_cart(:uid, :bid, :qty, :st, :msg); END;`;
            const res = await executeOracle(sql, {
                uid: Number(userId), bid: Number(bookId), qty: Number(quantity),
                st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return {
                status: getBind(res.outBinds, 'st') || 'SUCCESS',
                message: getBind(res.outBinds, 'msg') || 'Added to cart.'
            };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    async pkg_cart_mgmt_update_qty(userId, bookId, quantity) {
        if (!oraclePool) return dbSimulator.pkg_cart_mgmt_update_qty(userId, bookId, quantity);
        try {
            const sql = `BEGIN PKG_CART_MGMT.update_cart_quantity(:uid, :bid, :qty, :st, :msg); END;`;
            const res = await executeOracle(sql, {
                uid: Number(userId), bid: Number(bookId), qty: Number(quantity),
                st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return {
                status: getBind(res.outBinds, 'st') || 'SUCCESS',
                message: getBind(res.outBinds, 'msg') || 'Cart updated.'
            };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    async pkg_cart_mgmt_remove(userId, bookId) {
        if (!oraclePool) return dbSimulator.pkg_cart_mgmt_remove(userId, bookId);
        try {
            const sql = `BEGIN PKG_CART_MGMT.remove_from_cart(:uid, :bid, :st, :msg); END;`;
            const res = await executeOracle(sql, {
                uid: Number(userId), bid: Number(bookId),
                st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return {
                status: getBind(res.outBinds, 'st') || 'SUCCESS',
                message: getBind(res.outBinds, 'msg') || 'Item removed from cart.'
            };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    async pkg_cart_mgmt_clear(userId) {
        if (!oraclePool) return dbSimulator.pkg_cart_mgmt_clear(userId);
        try {
            const sql = `BEGIN PKG_CART_MGMT.clear_cart(:uid, :st, :msg); END;`;
            const res = await executeOracle(sql, {
                uid: Number(userId),
                st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return {
                status: getBind(res.outBinds, 'st') || 'SUCCESS',
                message: getBind(res.outBinds, 'msg') || 'Cart cleared.'
            };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    async pkg_cart_mgmt_get_items(userId) {
        if (!oraclePool) return dbSimulator.pkg_cart_mgmt_get_items(userId);
        try {
            const sql = `
                SELECT c.cart_item_id, c.book_id, b.title, b.author, b.isbn,
                       b.cover_image_url, b.price, c.quantity,
                       (c.quantity * b.price) AS line_total,
                       b.stock_quantity AS available_stock
                  FROM CART_ITEMS c
                  JOIN BOOKS b ON c.book_id = b.book_id
                 WHERE c.user_id = :uid
                 ORDER BY c.added_at DESC
            `;
            const res = await executeOracle(sql, { uid: Number(userId) });
            const items = res.rows || [];
            let subtotal = 0;
            let itemCount = 0;
            items.forEach(it => {
                subtotal += (it.quantity * it.price);
                itemCount += it.quantity;
            });
            return { items, subtotal: Number(subtotal.toFixed(2)), item_count: itemCount };
        } catch (err) {
            return dbSimulator.pkg_cart_mgmt_get_items(userId);
        }
    },

    // ------------------------------------------------------------------------
    // Order Management (PKG_ORDER_MGMT)
    // ------------------------------------------------------------------------
    async pkg_order_mgmt_place_order(userId, address, phone, paymentMethod = 'CARD', notes = '', promoCode = '') {
        if (!oraclePool) {
            return dbSimulator.pkg_order_mgmt_place_order(userId, address, phone, paymentMethod, notes, promoCode);
        }
        try {
            const sql = `
                BEGIN
                    PKG_ORDER_MGMT.place_order(
                        p_user_id          => :uid,
                        p_shipping_address => :ad,
                        p_contact_phone    => :ph,
                        p_payment_method   => :pm,
                        p_customer_notes   => :notes,
                        o_order_id         => :o_id,
                        o_total_amount     => :o_tot,
                        o_status           => :o_st,
                        o_message          => :o_msg
                    );
                END;
            `;
            const res = await executeOracle(sql, {
                uid: Number(userId),
                ad: address,
                ph: phone,
                pm: paymentMethod,
                notes: notes || null,
                o_id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
                o_tot: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
                o_st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                o_msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return {
                status: getBind(res.outBinds, 'o_st') || 'SUCCESS',
                message: getBind(res.outBinds, 'o_msg') || 'Order placed successfully.',
                order_id: getBind(res.outBinds, 'o_id'),
                total_amount: Number(getBind(res.outBinds, 'o_tot')) || 0
            };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    async pkg_order_mgmt_get_user_orders(userId) {
        if (!oraclePool) return dbSimulator.pkg_order_mgmt_get_user_orders(userId);
        try {
            const res = await executeOracle(`
                SELECT o.*,
                       (SELECT COUNT(*) FROM ORDER_ITEMS oi WHERE oi.order_id = o.order_id) AS total_items
                  FROM ORDERS o
                 WHERE o.user_id = :uid
                 ORDER BY o.order_date DESC
            `, { uid: Number(userId) });
            const orders = res.rows || [];
            for (const o of orders) {
                const itemRes = await executeOracle(`
                    SELECT oi.*, b.title, b.cover_image_url
                      FROM ORDER_ITEMS oi
                      JOIN BOOKS b ON oi.book_id = b.book_id
                     WHERE oi.order_id = :id
                `, { id: o.order_id });
                o.items = itemRes.rows || [];
            }
            return orders;
        } catch (err) {
            return dbSimulator.pkg_order_mgmt_get_user_orders(userId);
        }
    },

    async pkg_order_mgmt_get_all_orders() {
        if (!oraclePool) return dbSimulator.pkg_order_mgmt_get_all_orders();
        try {
            const res = await executeOracle(`
                SELECT o.*, u.username, u.full_name, u.email,
                       (SELECT COUNT(*) FROM ORDER_ITEMS oi WHERE oi.order_id = o.order_id) AS total_items
                  FROM ORDERS o
                  JOIN USERS u ON o.user_id = u.user_id
                 ORDER BY o.order_date DESC
            `);
            const orders = res.rows || [];
            for (const o of orders) {
                const itemRes = await executeOracle(`
                    SELECT oi.*, b.title
                      FROM ORDER_ITEMS oi
                      JOIN BOOKS b ON oi.book_id = b.book_id
                     WHERE oi.order_id = :id
                `, { id: o.order_id });
                o.items = itemRes.rows || [];
            }
            return orders;
        } catch (err) {
            return dbSimulator.pkg_order_mgmt_get_all_orders();
        }
    },

    async pkg_order_mgmt_get_order_details(orderId) {
        if (!oraclePool) return dbSimulator.pkg_order_mgmt_get_order_details(orderId);
        try {
            const res = await executeOracle(`
                SELECT o.*, u.full_name AS customer_name, u.email AS customer_email
                  FROM ORDERS o
                  JOIN USERS u ON o.user_id = u.user_id
                 WHERE o.order_id = :id
            `, { id: Number(orderId) });
            if (!res.rows || !res.rows.length) return null;
            const order = res.rows[0];
            const itemRes = await executeOracle(`
                SELECT oi.*, b.title, b.author, b.isbn, b.cover_image_url
                  FROM ORDER_ITEMS oi
                  JOIN BOOKS b ON oi.book_id = b.book_id
                 WHERE oi.order_id = :id
            `, { id: Number(orderId) });
            order.items = itemRes.rows || [];
            return order;
        } catch (err) {
            return dbSimulator.pkg_order_mgmt_get_order_details(orderId);
        }
    },

    async pkg_order_mgmt_update_status(orderId, newStatus, changedBy = 'ADMIN') {
        if (!oraclePool) return dbSimulator.pkg_order_mgmt_update_status(orderId, newStatus, changedBy);
        try {
            const sql = `BEGIN PKG_ORDER_MGMT.update_order_status(:id, :st, :by, :out_st, :msg); END;`;
            const res = await executeOracle(sql, {
                id: Number(orderId), st: newStatus, by: changedBy,
                out_st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return {
                status: getBind(res.outBinds, 'out_st') || 'SUCCESS',
                message: getBind(res.outBinds, 'msg') || 'Order status updated.'
            };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    async pkg_order_mgmt_cancel(orderId, userId, reason = 'Customer Request') {
        if (!oraclePool) return dbSimulator.pkg_order_mgmt_cancel(orderId, userId, reason);
        try {
            const sql = `BEGIN PKG_ORDER_MGMT.cancel_order(:id, :uid, :rsn, :st, :msg); END;`;
            const res = await executeOracle(sql, {
                id: Number(orderId), uid: Number(userId), rsn: reason,
                st: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 50 },
                msg: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 500 }
            });
            return {
                status: getBind(res.outBinds, 'st') || 'SUCCESS',
                message: getBind(res.outBinds, 'msg') || 'Order cancelled.'
            };
        } catch (err) {
            return { status: 'ERROR', message: err.message };
        }
    },

    // ------------------------------------------------------------------------
    // Reports & Analytics (PKG_REPORTS)
    // ------------------------------------------------------------------------
    async pkg_reports_get_bestsellers(limit = 10) {
        if (!oraclePool) return dbSimulator.pkg_reports_get_bestsellers(limit);
        try {
            const res = await executeOracle(`
                SELECT * FROM (
                    SELECT b.book_id, b.title, b.author, c.category_name, b.price,
                           NVL(SUM(oi.quantity), 0) AS total_units_sold,
                           NVL(SUM(oi.line_total), 0) AS total_revenue
                      FROM BOOKS b
                      JOIN CATEGORIES c ON b.category_id = c.category_id
                      LEFT JOIN ORDER_ITEMS oi ON b.book_id = oi.book_id
                      LEFT JOIN ORDERS o ON oi.order_id = o.order_id AND o.order_status <> 'CANCELLED'
                     GROUP BY b.book_id, b.title, b.author, c.category_name, b.price
                     ORDER BY total_units_sold DESC, total_revenue DESC
                ) WHERE ROWNUM <= :lim
            `, { lim: Number(limit) });
            return res.rows || [];
        } catch (err) {
            return dbSimulator.pkg_reports_get_bestsellers(limit);
        }
    },

    async pkg_reports_get_sales_trends() {
        if (!oraclePool) return dbSimulator.pkg_reports_get_sales_trends();
        try {
            const res = await executeOracle(`
                SELECT TO_CHAR(order_date, 'YYYY-MM') AS month_year,
                       COUNT(order_id) AS total_orders,
                       SUM(total_amount) AS total_sales,
                       ROUND(AVG(total_amount), 2) AS avg_order_value
                  FROM ORDERS
                 WHERE order_status <> 'CANCELLED'
                 GROUP BY TO_CHAR(order_date, 'YYYY-MM')
                 ORDER BY month_year ASC
            `);
            return res.rows || [];
        } catch (err) {
            return dbSimulator.pkg_reports_get_sales_trends();
        }
    },

    async pkg_reports_get_category_performance() {
        if (!oraclePool) return dbSimulator.pkg_reports_get_category_performance();
        try {
            const res = await executeOracle(`
                SELECT c.category_id, c.category_name,
                       COUNT(DISTINCT b.book_id) AS book_count,
                       NVL(SUM(oi.quantity), 0) AS total_units_sold,
                       NVL(SUM(oi.line_total), 0) AS category_revenue
                  FROM CATEGORIES c
                  LEFT JOIN BOOKS b ON c.category_id = b.category_id AND b.is_active = 'Y'
                  LEFT JOIN ORDER_ITEMS oi ON b.book_id = oi.book_id
                  LEFT JOIN ORDERS o ON oi.order_id = o.order_id AND o.order_status <> 'CANCELLED'
                 GROUP BY c.category_id, c.category_name
                 ORDER BY category_revenue DESC
            `);
            return res.rows || [];
        } catch (err) {
            return dbSimulator.pkg_reports_get_category_performance();
        }
    },

    async pkg_reports_get_low_stock(threshold = 10) {
        if (!oraclePool) return dbSimulator.pkg_reports_get_low_stock(threshold);
        try {
            const res = await executeOracle(`
                SELECT b.book_id, b.isbn, b.title, b.author, c.category_name,
                       b.stock_quantity, b.price
                  FROM BOOKS b
                  JOIN CATEGORIES c ON b.category_id = c.category_id
                 WHERE b.is_active = 'Y'
                   AND b.stock_quantity <= :th
                 ORDER BY b.stock_quantity ASC
            `, { th: Number(threshold) });
            return res.rows || [];
        } catch (err) {
            return dbSimulator.pkg_reports_get_low_stock(threshold);
        }
    },

    async pkg_reports_get_dashboard_summary() {
        if (!oraclePool) return dbSimulator.pkg_reports_get_dashboard_summary();
        try {
            const sql = `BEGIN PKG_REPORTS.get_dashboard_summary(:u, :b, :o, :r, :p); END;`;
            const res = await executeOracle(sql, {
                u: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
                b: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
                o: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
                r: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
                p: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER }
            });
            const lowRes = await executeOracle(`SELECT COUNT(*) AS c FROM BOOKS WHERE is_active = 'Y' AND stock_quantity <= 5`);
            const lowStockCount = lowRes.rows && lowRes.rows.length ? Number(lowRes.rows[0].c ?? lowRes.rows[0].C ?? 0) : 0;
            return {
                total_users: Number(getBind(res.outBinds, 'u')) || 0,
                total_books: Number(getBind(res.outBinds, 'b')) || 0,
                total_orders: Number(getBind(res.outBinds, 'o')) || 0,
                total_revenue: Number(getBind(res.outBinds, 'r')) || 0,
                pending_orders: Number(getBind(res.outBinds, 'p')) || 0,
                low_stock_count: lowStockCount
            };
        } catch (err) {
            return dbSimulator.pkg_reports_get_dashboard_summary();
        }
    }
};

module.exports = dbProxy;
