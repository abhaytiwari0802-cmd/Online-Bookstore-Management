// ============================================================================
// ONLINE BOOKSTORE MANAGEMENT SYSTEM
// File: server/server.js
// Description: Zero-dependency Node.js HTTP REST API Server & Static File Server.
// Maps all front-end actions to Oracle PL/SQL stored procedures & packages.
// ============================================================================

const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

// Simple zero-dependency .env loader if .env exists
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

const db = require('./oracle-connector');
const oracle = require('./oracle-connector');

const PORT = process.env.PORT || 3000;
const PUBLIC_DIR = path.join(__dirname, '..', 'public');
const DATABASE_DIR = path.join(__dirname, '..', 'database');

const MIME_TYPES = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.sql': 'text/plain'
};

// Parse JSON request body helper
function parseBody(req) {
    return new Promise((resolve, reject) => {
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
            // Guard against massive payloads (>1MB)
            if (body.length > 1e6) {
                req.destroy();
                reject(new Error('Payload too large'));
            }
        });
        req.on('end', () => {
            if (!body) return resolve({});
            try {
                resolve(JSON.parse(body));
            } catch (err) {
                resolve({});
            }
        });
        req.on('error', reject);
    });
}

// Send JSON response helper
function sendJson(res, statusCode, data) {
    res.writeHead(statusCode, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    });
    res.end(JSON.stringify(data));
}

// Extract authenticated user ID from Authorization header or query param
function getUserIdFromReq(req, parsedUrl) {
    const authHeader = req.headers['authorization'];
    if (authHeader && authHeader.startsWith('Bearer ')) {
        const token = authHeader.substring(7);
        const parsed = parseInt(token, 10);
        if (!isNaN(parsed)) return parsed;
    }
    if (parsedUrl.query && parsedUrl.query.user_id) {
        return parseInt(parsedUrl.query.user_id, 10);
    }
    // Default fallback to John Doe for quick testing if none supplied
    return 1002;
}

// Main HTTP request handler
const server = http.createServer(async (req, res) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        res.writeHead(204, {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        });
        return res.end();
    }

    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    const method = req.method;

    try {
        // ====================================================================
        // API ROUTES - USER MANAGEMENT (PKG_USER_MGMT)
        // ====================================================================
        if (pathname === '/api/auth/register' && method === 'POST') {
            const body = await parseBody(req);
            const result = await db.pkg_user_mgmt_register(
                body.username, body.email, body.password,
                body.full_name, body.phone, body.address, body.role_id
            );
            return sendJson(res, result.status === 'SUCCESS' ? 201 : 400, result);
        }

        if (pathname === '/api/auth/login' && method === 'POST') {
            const body = await parseBody(req);
            const result = await db.pkg_user_mgmt_authenticate(body.username, body.password);
            return sendJson(res, result.status === 'SUCCESS' ? 200 : 401, result);
        }

        if (pathname === '/api/auth/profile' && method === 'GET') {
            const userId = getUserIdFromReq(req, parsedUrl);
            const profile = await db.pkg_user_mgmt_get_profile(userId);
            if (!profile) return sendJson(res, 404, { status: 'ERROR', message: 'User not found' });
            return sendJson(res, 200, { status: 'SUCCESS', data: profile });
        }

        if (pathname === '/api/auth/profile' && method === 'PUT') {
            const userId = getUserIdFromReq(req, parsedUrl);
            const body = await parseBody(req);
            const result = await db.pkg_user_mgmt_update_profile(userId, body.full_name, body.phone, body.address);
            return sendJson(res, result.status === 'SUCCESS' ? 200 : 400, result);
        }

        if (pathname === '/api/auth/change-password' && method === 'POST') {
            const userId = getUserIdFromReq(req, parsedUrl);
            const body = await parseBody(req);
            const result = await db.pkg_user_mgmt_change_password(userId, body.old_password, body.new_password);
            return sendJson(res, result.status === 'SUCCESS' ? 200 : 400, result);
        }

        // ====================================================================
        // API ROUTES - BOOK MANAGEMENT (PKG_BOOK_MGMT)
        // ====================================================================
        if (pathname === '/api/categories' && method === 'GET') {
            const categories = typeof db.getCategories === 'function' ? await db.getCategories() : db.categories;
            return sendJson(res, 200, { status: 'SUCCESS', data: categories });
        }

        if (pathname === '/api/books' && method === 'GET') {
            const query = parsedUrl.query.q || '';
            const categoryId = parsedUrl.query.category_id || null;
            const minPrice = parsedUrl.query.min_price || null;
            const maxPrice = parsedUrl.query.max_price || null;
            const sortBy = parsedUrl.query.sort_by || 'TITLE_ASC';

            const books = await db.pkg_book_mgmt_search(query, categoryId, minPrice, maxPrice, sortBy);
            return sendJson(res, 200, { status: 'SUCCESS', data: books, count: books.length });
        }

        const bookDetailsMatch = pathname.match(/^\/api\/books\/(\d+)$/);
        if (bookDetailsMatch && method === 'GET') {
            const bookId = bookDetailsMatch[1];
            const book = await db.pkg_book_mgmt_get_details(bookId);
            if (!book) return sendJson(res, 404, { status: 'ERROR', message: 'Book not found' });
            return sendJson(res, 200, { status: 'SUCCESS', data: book });
        }

        if (pathname === '/api/books' && method === 'POST') {
            const body = await parseBody(req);
            const result = await db.pkg_book_mgmt_add(body);
            return sendJson(res, result.status === 'SUCCESS' ? 201 : 400, result);
        }

        if (bookDetailsMatch && method === 'PUT') {
            const bookId = bookDetailsMatch[1];
            const body = await parseBody(req);
            const result = await db.pkg_book_mgmt_update(bookId, body);
            return sendJson(res, result.status === 'SUCCESS' ? 200 : 400, result);
        }

        if (bookDetailsMatch && method === 'DELETE') {
            const bookId = bookDetailsMatch[1];
            const hardDelete = parsedUrl.query.hard === 'true';
            const result = await db.pkg_book_mgmt_remove(bookId, hardDelete);
            return sendJson(res, result.status === 'SUCCESS' ? 200 : 400, result);
        }

        // ====================================================================
        // API ROUTES - SHOPPING CART (PKG_CART_MGMT)
        // ====================================================================
        if (pathname === '/api/cart' && method === 'GET') {
            const userId = getUserIdFromReq(req, parsedUrl);
            const cartData = await db.pkg_cart_mgmt_get_items(userId);
            return sendJson(res, 200, { status: 'SUCCESS', data: cartData });
        }

        if (pathname === '/api/cart' && method === 'POST') {
            const userId = getUserIdFromReq(req, parsedUrl);
            const body = await parseBody(req);
            const result = await db.pkg_cart_mgmt_add(userId, body.book_id, body.quantity || 1);
            return sendJson(res, result.status === 'SUCCESS' ? 200 : 400, result);
        }

        const cartItemMatch = pathname.match(/^\/api\/cart\/(\d+)$/);
        if (cartItemMatch && method === 'PUT') {
            const userId = getUserIdFromReq(req, parsedUrl);
            const bookId = cartItemMatch[1];
            const body = await parseBody(req);
            const result = await db.pkg_cart_mgmt_update_qty(userId, bookId, body.quantity);
            return sendJson(res, result.status === 'SUCCESS' ? 200 : 400, result);
        }

        if (cartItemMatch && method === 'DELETE') {
            const userId = getUserIdFromReq(req, parsedUrl);
            const bookId = cartItemMatch[1];
            const result = await db.pkg_cart_mgmt_remove(userId, bookId);
            return sendJson(res, result.status === 'SUCCESS' ? 200 : 400, result);
        }

        if (pathname === '/api/cart' && method === 'DELETE') {
            const userId = getUserIdFromReq(req, parsedUrl);
            const result = await db.pkg_cart_mgmt_clear(userId);
            return sendJson(res, 200, result);
        }

        // ====================================================================
        // API ROUTES - ORDER MANAGEMENT (PKG_ORDER_MGMT)
        // ====================================================================
        if (pathname === '/api/orders/checkout' && method === 'POST') {
            const userId = getUserIdFromReq(req, parsedUrl);
            const body = await parseBody(req);
            const result = await db.pkg_order_mgmt_place_order(
                userId,
                body.shipping_address,
                body.contact_phone,
                body.payment_method,
                body.customer_notes,
                body.promo_code
            );
            return sendJson(res, result.status === 'SUCCESS' ? 201 : 400, result);
        }

        if (pathname === '/api/orders' && method === 'GET') {
            const userId = getUserIdFromReq(req, parsedUrl);
            const orders = await db.pkg_order_mgmt_get_user_orders(userId);
            return sendJson(res, 200, { status: 'SUCCESS', data: orders });
        }

        if (pathname === '/api/orders/all' && method === 'GET') {
            const orders = await db.pkg_order_mgmt_get_all_orders();
            return sendJson(res, 200, { status: 'SUCCESS', data: orders });
        }

        const orderDetailsMatch = pathname.match(/^\/api\/orders\/(\d+)$/);
        if (orderDetailsMatch && method === 'GET') {
            const orderId = orderDetailsMatch[1];
            const order = await db.pkg_order_mgmt_get_order_details(orderId);
            if (!order) return sendJson(res, 404, { status: 'ERROR', message: 'Order not found' });
            return sendJson(res, 200, { status: 'SUCCESS', data: order });
        }

        const orderStatusMatch = pathname.match(/^\/api\/orders\/(\d+)\/status$/);
        if (orderStatusMatch && method === 'PUT') {
            const orderId = orderStatusMatch[1];
            const body = await parseBody(req);
            const result = await db.pkg_order_mgmt_update_status(orderId, body.status, body.changed_by || 'ADMIN');
            return sendJson(res, result.status === 'SUCCESS' ? 200 : 400, result);
        }

        const orderCancelMatch = pathname.match(/^\/api\/orders\/(\d+)\/cancel$/);
        if (orderCancelMatch && method === 'POST') {
            const userId = getUserIdFromReq(req, parsedUrl);
            const orderId = orderCancelMatch[1];
            const body = await parseBody(req);
            const result = await db.pkg_order_mgmt_cancel(orderId, userId, body.reason);
            return sendJson(res, result.status === 'SUCCESS' ? 200 : 400, result);
        }

        // ====================================================================
        // API ROUTES - REPORTING & ANALYTICS (PKG_REPORTS)
        // ====================================================================
        if (pathname === '/api/reports/dashboard' && method === 'GET') {
            const summary = await db.pkg_reports_get_dashboard_summary();
            return sendJson(res, 200, { status: 'SUCCESS', data: summary });
        }

        if (pathname === '/api/reports/bestsellers' && method === 'GET') {
            const limit = parsedUrl.query.limit || 10;
            const data = await db.pkg_reports_get_bestsellers(limit);
            return sendJson(res, 200, { status: 'SUCCESS', data });
        }

        if (pathname === '/api/reports/sales-trends' && method === 'GET') {
            const data = await db.pkg_reports_get_sales_trends();
            return sendJson(res, 200, { status: 'SUCCESS', data });
        }

        if (pathname === '/api/reports/categories' && method === 'GET') {
            const data = await db.pkg_reports_get_category_performance();
            return sendJson(res, 200, { status: 'SUCCESS', data });
        }

        if (pathname === '/api/reports/low-stock' && method === 'GET') {
            const threshold = parsedUrl.query.threshold || 10;
            const data = await db.pkg_reports_get_low_stock(threshold);
            return sendJson(res, 200, { status: 'SUCCESS', data });
        }

        if (pathname === '/api/audit-logs' && method === 'GET') {
            const logs = typeof db.getAuditLogs === 'function' ? await db.getAuditLogs() : db.audit_logs.slice(0, 50);
            return sendJson(res, 200, { status: 'SUCCESS', data: logs });
        }

        // ====================================================================
        // API ROUTES - PL/SQL EXPLORER & DEMO RUNNER
        // ====================================================================
        if (pathname === '/api/plsql/files' && method === 'GET') {
            const files = fs.readdirSync(DATABASE_DIR).filter(f => f.endsWith('.sql'));
            const fileData = {};
            for (const file of files) {
                fileData[file] = fs.readFileSync(path.join(DATABASE_DIR, file), 'utf8');
            }
            return sendJson(res, 200, { status: 'SUCCESS', files: fileData });
        }

        if (pathname === '/api/plsql/reset' && method === 'POST') {
            db.reset();
            return sendJson(res, 200, { status: 'SUCCESS', message: 'Database reset to initial seed state.' });
        }

        // ====================================================================
        // STATIC FILE SERVING
        // ====================================================================
        let filePath = path.join(PUBLIC_DIR, pathname === '/' ? 'index.html' : pathname);

        // Security check: avoid directory traversal
        if (!filePath.startsWith(PUBLIC_DIR)) {
            res.writeHead(403, { 'Content-Type': 'text/plain' });
            return res.end('Access Denied');
        }

        fs.stat(filePath, (err, stats) => {
            if (err || !stats.isFile()) {
                // If file doesn't exist, try index.html
                filePath = path.join(PUBLIC_DIR, 'index.html');
            }

            const ext = path.extname(filePath).toLowerCase();
            const contentType = MIME_TYPES[ext] || 'application/octet-stream';

            fs.readFile(filePath, (readErr, content) => {
                if (readErr) {
                    res.writeHead(404, { 'Content-Type': 'text/plain' });
                    return res.end('File Not Found');
                }
                res.writeHead(200, { 'Content-Type': contentType });
                res.end(content);
            });
        });

    } catch (serverErr) {
        console.error('[Server Error]', serverErr);
        sendJson(res, 500, { status: 'ERROR', message: 'Internal server error: ' + serverErr.message });
    }
});

server.listen(PORT, async () => {
    console.log('================================================================');
    console.log(`  ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)`);
    console.log(`  Web Server running at: http://localhost:${PORT}`);
    console.log(`  Storefront:   http://localhost:${PORT}/index.html`);
    console.log(`  Admin Portal: http://localhost:${PORT}/admin.html`);
    console.log(`  PL/SQL Runner: http://localhost:${PORT}/plsql-runner.html`);
    console.log('================================================================');
    await oracle.initOraclePool();
});
