// ============================================================================
// ONLINE BOOKSTORE MANAGEMENT SYSTEM
// File: public/js/admin.js
// Description: Admin Portal Logic - Book CRUD, Order Status Workflow, Reports.
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
    // Check Admin Authentication
    const user = API.getUser();
    if (!user || user.role_name !== 'ADMIN') {
        const warning = document.getElementById('admin-access-warning');
        if (warning) {
            warning.style.display = 'block';
        }
    }

    // Tab Navigation
    const navTabs = document.querySelectorAll('.admin-nav-tab');
    const tabPanes = document.querySelectorAll('.tab-pane');

    navTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const target = tab.getAttribute('data-tab');
            navTabs.forEach(t => t.classList.remove('active'));
            tabPanes.forEach(p => p.classList.remove('active'));

            tab.classList.add('active');
            const targetPane = document.getElementById(`tab-${target}`);
            if (targetPane) targetPane.classList.add('active');

            if (target === 'dashboard') loadDashboard();
            if (target === 'books') loadAdminBooks();
            if (target === 'orders') loadAdminOrders();
            if (target === 'reports') loadReports();
            if (target === 'audit') loadAuditLogs();
        });
    });

    // ------------------------------------------------------------------------
    // 1. Dashboard KPI Summary
    // ------------------------------------------------------------------------
    async function loadDashboard() {
        try {
            const summary = await API.getDashboardSummary() || {};
            const totalRev = Number(summary.total_revenue ?? summary.TOTAL_REVENUE) || 0;
            const totalOrd = Number(summary.total_orders ?? summary.TOTAL_ORDERS) || 0;
            const totalBk = Number(summary.total_books ?? summary.TOTAL_BOOKS) || 0;
            const totalUsr = Number(summary.total_users ?? summary.TOTAL_USERS) || 0;
            const pendOrd = Number(summary.pending_orders ?? summary.PENDING_ORDERS) || 0;
            const lowStock = Number(summary.low_stock_count ?? summary.LOW_STOCK_COUNT) || 0;

            document.getElementById('kpi-revenue').textContent = `$${totalRev.toFixed(2)}`;
            document.getElementById('kpi-orders').textContent = totalOrd;
            document.getElementById('kpi-books').textContent = totalBk;
            document.getElementById('kpi-users').textContent = totalUsr;
            document.getElementById('kpi-pending').textContent = pendOrd;
            document.getElementById('kpi-low-stock').textContent = lowStock;

            // Load bestsellers preview
            const bestsellers = await API.getBestsellers(5) || [];
            const bestsellersEl = document.getElementById('dash-bestsellers-list');
            if (bestsellersEl) {
                bestsellersEl.innerHTML = bestsellers.map((b, idx) => {
                    const title = b.title ?? b.TITLE ?? 'Unknown';
                    const author = b.author ?? b.AUTHOR ?? 'Unknown';
                    const catName = b.category_name ?? b.CATEGORY_NAME ?? 'General';
                    const unitsSold = Number(b.total_units_sold ?? b.TOTAL_UNITS_SOLD) || 0;
                    const revenue = Number(b.total_revenue ?? b.TOTAL_REVENUE) || 0;
                    return `
                    <div style="display: flex; align-items: center; justify-content: space-between; padding: 0.75rem 0; border-bottom: 1px solid var(--border);">
                        <div>
                            <span style="font-weight: 700; color: var(--primary); margin-right: 0.5rem;">#${idx + 1}</span>
                            <strong>${escapeHtml(title)}</strong>
                            <div style="font-size: 0.8rem; color: var(--text-muted);">${escapeHtml(author)} • ${escapeHtml(catName)}</div>
                        </div>
                        <div style="text-align: right;">
                            <div style="font-weight: 700; color: var(--dark);">${unitsSold} sold</div>
                            <div style="font-size: 0.82rem; color: var(--success);">$${revenue.toFixed(2)}</div>
                        </div>
                    </div>
                `;
                }).join('') || '<div style="color: var(--text-muted);">No sales data yet.</div>';
            }
        } catch (err) {
            console.error('Failed to load dashboard', err);
        }
    }

    // ------------------------------------------------------------------------
    // 2. Book Catalog Management (CRUD)
    // ------------------------------------------------------------------------
    async function loadAdminBooks() {
        const tableBody = document.getElementById('admin-books-table-body');
        if (!tableBody) return;

        try {
            tableBody.innerHTML = '<tr><td colspan="7" style="text-align: center; padding: 2rem;">Loading books...</td></tr>';
            const res = await API.getBooks();
            const books = res.data || [];

            tableBody.innerHTML = books.map(book => {
                const bookId = book.book_id ?? book.BOOK_ID;
                const title = book.title ?? book.TITLE ?? '';
                const isbn = book.isbn ?? book.ISBN ?? '';
                const author = book.author ?? book.AUTHOR ?? '';
                const categoryName = book.category_name ?? book.CATEGORY_NAME ?? 'General';
                const price = Number(book.price ?? book.PRICE) || 0;
                const stockQty = Number(book.stock_quantity ?? book.STOCK_QUANTITY) || 0;
                const isActive = (book.is_active ?? book.IS_ACTIVE ?? 'Y') === 'Y';

                return `
                <tr>
                    <td><strong>#${bookId}</strong></td>
                    <td>
                        <div style="font-weight: 700; color: var(--dark);">${escapeHtml(title)}</div>
                        <div style="font-size: 0.8rem; color: var(--text-muted);">ISBN: ${escapeHtml(isbn)} • by ${escapeHtml(author)}</div>
                    </td>
                    <td><span class="stock-pill" style="background:#f1f5f9; color:var(--dark);">${escapeHtml(categoryName)}</span></td>
                    <td style="font-weight: 700;">$${price.toFixed(2)}</td>
                    <td>
                        <span class="stock-pill ${stockQty === 0 ? 'stock-out' : (stockQty <= 5 ? 'stock-low' : 'stock-in')}">
                            ${stockQty} in stock
                        </span>
                    </td>
                    <td>
                        <span class="stock-pill ${isActive ? 'stock-in' : 'stock-out'}">
                            ${isActive ? 'Active' : 'Inactive'}
                        </span>
                    </td>
                    <td>
                        <button class="btn btn-outline btn-sm" onclick="editBook(${bookId})">Edit</button>
                        <button class="btn btn-outline btn-sm" style="color: var(--danger); border-color: var(--danger);" onclick="deleteBook(${bookId})">Delete</button>
                    </td>
                </tr>
            `;
            }).join('') || '<tr><td colspan="7" style="text-align:center;">No books found.</td></tr>';
        } catch (err) {
            tableBody.innerHTML = `<tr><td colspan="7" style="color:red; text-align:center;">Error: ${err.message}</td></tr>`;
        }
    }

    // Book Modal Handlers
    const bookModal = document.getElementById('admin-book-modal');
    const bookBackdrop = document.getElementById('admin-book-backdrop');
    const formBook = document.getElementById('form-admin-book');
    const modalBookTitle = document.getElementById('admin-book-modal-title');
    const btnAddBook = document.getElementById('btn-add-new-book');

    if (btnAddBook) {
        btnAddBook.addEventListener('click', () => {
            modalBookTitle.textContent = 'Add New Book to Inventory';
            formBook.reset();
            document.getElementById('admin-book-id').value = '';
            bookModal.classList.add('active');
            bookBackdrop.classList.add('active');
        });
    }

    window.editBook = async function (bookId) {
        try {
            const res = await API.getBookDetails(bookId);
            const book = res.data;
            if (!book) return;

            const bId = book.book_id ?? book.BOOK_ID;
            modalBookTitle.textContent = `Edit Book #${bId}`;
            document.getElementById('admin-book-id').value = bId;
            document.getElementById('book-form-title').value = book.title ?? book.TITLE ?? '';
            document.getElementById('book-form-author').value = book.author ?? book.AUTHOR ?? '';
            document.getElementById('book-form-isbn').value = book.isbn ?? book.ISBN ?? '';
            document.getElementById('book-form-category').value = book.category_id ?? book.CATEGORY_ID ?? 101;
            document.getElementById('book-form-price').value = book.price ?? book.PRICE ?? 0;
            document.getElementById('book-form-stock').value = book.stock_quantity ?? book.STOCK_QUANTITY ?? 0;
            document.getElementById('book-form-publisher').value = book.publisher ?? book.PUBLISHER ?? '';
            document.getElementById('book-form-year').value = book.publication_year ?? book.PUBLICATION_YEAR ?? '';
            document.getElementById('book-form-cover').value = book.cover_image_url ?? book.COVER_IMAGE_URL ?? '';
            document.getElementById('book-form-desc').value = book.description ?? book.DESCRIPTION ?? '';

            bookModal.classList.add('active');
            bookBackdrop.classList.add('active');
        } catch (err) {
            showToast('Failed to load book: ' + err.message, 'error');
        }
    };

    window.deleteBook = async function (bookId) {
        if (!confirm(`Are you sure you want to remove Book #${bookId}?`)) return;
        try {
            const res = await API.deleteBook(bookId, false);
            showToast(res.message || 'Book removed successfully.', 'success');
            loadAdminBooks();
            loadDashboard();
        } catch (err) {
            showToast(err.message, 'error');
        }
    };

    if (formBook) {
        formBook.addEventListener('submit', async (e) => {
            e.preventDefault();
            const bookId = document.getElementById('admin-book-id').value;
            const payload = {
                title: document.getElementById('book-form-title').value.trim(),
                author: document.getElementById('book-form-author').value.trim(),
                isbn: document.getElementById('book-form-isbn').value.trim(),
                category_id: parseInt(document.getElementById('book-form-category').value, 10),
                price: parseFloat(document.getElementById('book-form-price').value),
                stock_quantity: parseInt(document.getElementById('book-form-stock').value, 10),
                publisher: document.getElementById('book-form-publisher').value.trim(),
                publication_year: parseInt(document.getElementById('book-form-year').value, 10) || null,
                cover_image_url: document.getElementById('book-form-cover').value.trim(),
                description: document.getElementById('book-form-desc').value.trim()
            };

            try {
                if (bookId) {
                    const res = await API.updateBook(bookId, payload);
                    showToast(res.message || 'Book updated successfully!', 'success');
                } else {
                    const res = await API.addBook(payload);
                    showToast(res.message || 'Book added successfully!', 'success');
                }
                bookModal.classList.remove('active');
                bookBackdrop.classList.remove('active');
                loadAdminBooks();
                loadDashboard();
            } catch (err) {
                showToast(err.message, 'error');
            }
        });
    }

    const bookCloseBtn = document.getElementById('admin-book-close-btn');
    if (bookCloseBtn) {
        bookCloseBtn.addEventListener('click', () => {
            bookModal.classList.remove('active');
            bookBackdrop.classList.remove('active');
        });
    }
    if (bookBackdrop) {
        bookBackdrop.addEventListener('click', () => {
            bookModal.classList.remove('active');
            bookBackdrop.classList.remove('active');
        });
    }

    // ------------------------------------------------------------------------
    // 3. Order Management (Status Transition Workflow)
    // ------------------------------------------------------------------------
    async function loadAdminOrders() {
        const tableBody = document.getElementById('admin-orders-table-body');
        if (!tableBody) return;

        try {
            tableBody.innerHTML = '<tr><td colspan="7" style="text-align: center; padding: 2rem;">Loading orders...</td></tr>';
            const orders = await API.getAllOrders() || [];

            tableBody.innerHTML = orders.map(order => {
                const orderId = order.order_id ?? order.ORDER_ID;
                const fullName = order.full_name ?? order.FULL_NAME ?? order.customer_name ?? order.CUSTOMER_NAME ?? 'Customer';
                const email = order.email ?? order.EMAIL ?? order.customer_email ?? order.CUSTOMER_EMAIL ?? '';
                const orderDate = order.order_date ?? order.ORDER_DATE ?? new Date().toISOString();
                const totalItems = Number(order.total_items ?? order.TOTAL_ITEMS) || 0;
                const totalAmount = Number(order.total_amount ?? order.TOTAL_AMOUNT) || 0;
                const orderStatus = order.order_status ?? order.ORDER_STATUS ?? 'PENDING';

                return `
                <tr>
                    <td><strong>#${orderId}</strong></td>
                    <td>
                        <div style="font-weight: 700; color: var(--dark);">${escapeHtml(fullName)}</div>
                        <div style="font-size: 0.8rem; color: var(--text-muted);">${escapeHtml(email)}</div>
                    </td>
                    <td>${new Date(orderDate).toLocaleDateString()}</td>
                    <td>${totalItems} items</td>
                    <td style="font-weight: 700; color: var(--dark);">$${totalAmount.toFixed(2)}</td>
                    <td>
                        <select class="form-control" style="padding: 0.35rem 0.5rem; font-size: 0.85rem;"
                                onchange="changeOrderStatus(${orderId}, this.value)"
                                ${['CANCELLED', 'DELIVERED'].includes(orderStatus) ? 'disabled' : ''}>
                            <option value="PENDING" ${orderStatus === 'PENDING' ? 'selected' : ''}>PENDING</option>
                            <option value="PROCESSING" ${orderStatus === 'PROCESSING' ? 'selected' : ''}>PROCESSING</option>
                            <option value="SHIPPED" ${orderStatus === 'SHIPPED' ? 'selected' : ''}>SHIPPED</option>
                            <option value="DELIVERED" ${orderStatus === 'DELIVERED' ? 'selected' : ''}>DELIVERED</option>
                            <option value="CANCELLED" ${orderStatus === 'CANCELLED' ? 'selected' : ''}>CANCELLED</option>
                        </select>
                    </td>
                    <td>
                        <button class="btn btn-outline btn-sm" onclick="viewOrderDetailsModal(${orderId})">View Items</button>
                    </td>
                </tr>
            `;
            }).join('') || '<tr><td colspan="7" style="text-align:center;">No orders recorded.</td></tr>';
        } catch (err) {
            tableBody.innerHTML = `<tr><td colspan="7" style="color:red; text-align:center;">Error: ${err.message}</td></tr>`;
        }
    }

    window.changeOrderStatus = async function (orderId, newStatus) {
        try {
            const res = await API.updateOrderStatus(orderId, newStatus);
            showToast(res.message || `Order #${orderId} status updated to ${newStatus}`, 'success');
            loadAdminOrders();
            loadDashboard();
        } catch (err) {
            showToast(err.message, 'error');
            loadAdminOrders();
        }
    };

    window.viewOrderDetailsModal = async function (orderId) {
        try {
            const order = await API.getOrderDetails(orderId);
            if (!order) return;

            const total = Number(order.total_amount ?? order.TOTAL_AMOUNT) || 0;
            const items = order.items ?? order.ITEMS ?? [];

            alert(`Order #${order.order_id ?? order.ORDER_ID} Details:\n` +
                  `Customer: ${order.customer_name ?? order.CUSTOMER_NAME ?? ''} (${order.customer_email ?? order.CUSTOMER_EMAIL ?? ''})\n` +
                  `Shipping Address: ${order.shipping_address ?? order.SHIPPING_ADDRESS ?? ''}\n` +
                  `Contact Phone: ${order.contact_phone ?? order.CONTACT_PHONE ?? ''}\n` +
                  `Status: ${order.order_status ?? order.ORDER_STATUS ?? ''}\n` +
                  `Total: $${total.toFixed(2)}\n\n` +
                  `Items:\n` +
                  items.map(it => {
                      const title = it.title ?? it.TITLE ?? '';
                      const qty = Number(it.quantity ?? it.QUANTITY) || 1;
                      const lineTot = Number(it.line_total ?? it.LINE_TOTAL) || 0;
                      return `• ${title} (x${qty}) - $${lineTot.toFixed(2)}`;
                  }).join('\n'));
        } catch (err) {
            showToast('Failed to get order details: ' + err.message, 'error');
        }
    };

    // ------------------------------------------------------------------------
    // 4. Reports & Business Analytics (PKG_REPORTS)
    // ------------------------------------------------------------------------
    async function loadReports() {
        try {
            // Best sellers
            const bestsellers = await API.getBestsellers(10) || [];
            const bestTable = document.getElementById('report-bestsellers-table');
            if (bestTable) {
                bestTable.innerHTML = bestsellers.map((b, i) => {
                    const title = b.title ?? b.TITLE ?? '';
                    const author = b.author ?? b.AUTHOR ?? '';
                    const catName = b.category_name ?? b.CATEGORY_NAME ?? '';
                    const price = Number(b.price ?? b.PRICE) || 0;
                    const units = Number(b.total_units_sold ?? b.TOTAL_UNITS_SOLD) || 0;
                    const rev = Number(b.total_revenue ?? b.TOTAL_REVENUE) || 0;
                    return `
                    <tr>
                        <td><strong>#${i + 1}</strong></td>
                        <td><strong>${escapeHtml(title)}</strong><div style="font-size:0.8rem;color:var(--text-muted);">${escapeHtml(author)}</div></td>
                        <td>${escapeHtml(catName)}</td>
                        <td>$${price.toFixed(2)}</td>
                        <td style="font-weight:700;">${units}</td>
                        <td style="font-weight:700; color:var(--success);">$${rev.toFixed(2)}</td>
                    </tr>
                `;
                }).join('') || '<tr><td colspan="6" style="text-align:center;">No data</td></tr>';
            }

            // Sales trends
            const trends = await API.getSalesTrends() || [];
            const trendsTable = document.getElementById('report-trends-table');
            if (trendsTable) {
                trendsTable.innerHTML = trends.map(t => {
                    const monthYear = t.month_year ?? t.MONTH_YEAR ?? '';
                    const totalOrders = Number(t.total_orders ?? t.TOTAL_ORDERS) || 0;
                    const totalSales = Number(t.total_sales ?? t.TOTAL_SALES) || 0;
                    const avgVal = Number(t.avg_order_value ?? t.AVG_ORDER_VALUE) || 0;
                    return `
                    <tr>
                        <td><strong>${monthYear}</strong></td>
                        <td>${totalOrders}</td>
                        <td style="font-weight:700; color:var(--primary);">$${totalSales.toFixed(2)}</td>
                        <td>$${avgVal.toFixed(2)}</td>
                    </tr>
                `;
                }).join('') || '<tr><td colspan="4" style="text-align:center;">No sales trend data</td></tr>';
            }

            // Category performance
            const categories = await API.getCategoryPerformance() || [];
            const catTable = document.getElementById('report-categories-table');
            if (catTable) {
                catTable.innerHTML = categories.map(c => {
                    const catName = c.category_name ?? c.CATEGORY_NAME ?? '';
                    const bookCount = Number(c.book_count ?? c.BOOK_COUNT) || 0;
                    const unitsSold = Number(c.total_units_sold ?? c.TOTAL_UNITS_SOLD) || 0;
                    const catRev = Number(c.category_revenue ?? c.CATEGORY_REVENUE) || 0;
                    return `
                    <tr>
                        <td><strong>${escapeHtml(catName)}</strong></td>
                        <td>${bookCount} active titles</td>
                        <td>${unitsSold} units</td>
                        <td style="font-weight:700; color:var(--success);">$${catRev.toFixed(2)}</td>
                    </tr>
                `;
                }).join('') || '<tr><td colspan="4" style="text-align:center;">No category data</td></tr>';
            }

            // Low stock
            const lowStock = await API.getLowStockAlert(10) || [];
            const lowStockTable = document.getElementById('report-lowstock-table');
            if (lowStockTable) {
                lowStockTable.innerHTML = lowStock.map(b => {
                    const bookId = b.book_id ?? b.BOOK_ID;
                    const title = b.title ?? b.TITLE ?? '';
                    const catName = b.category_name ?? b.CATEGORY_NAME ?? '';
                    const stockQty = Number(b.stock_quantity ?? b.STOCK_QUANTITY) || 0;
                    return `
                    <tr>
                        <td>#${bookId}</td>
                        <td><strong>${escapeHtml(title)}</strong></td>
                        <td>${escapeHtml(catName)}</td>
                        <td>
                            <span class="stock-pill ${stockQty === 0 ? 'stock-out' : 'stock-low'}">
                                ${stockQty} left
                            </span>
                        </td>
                        <td>
                            <button class="btn btn-outline btn-sm" onclick="editBook(${bookId})">Restock</button>
                        </td>
                    </tr>
                `;
                }).join('') || '<tr><td colspan="5" style="text-align:center; color:var(--success);">All inventory stock levels are healthy!</td></tr>';
            }
        } catch (err) {
            console.error('Failed to load reports', err);
        }
    }

    // ------------------------------------------------------------------------
    // 5. System Audit Trail (AUDIT_LOGS table)
    // ------------------------------------------------------------------------
    async function loadAuditLogs() {
        const auditTable = document.getElementById('admin-audit-table-body');
        if (!auditTable) return;

        try {
            auditTable.innerHTML = '<tr><td colspan="6" style="text-align: center; padding: 2rem;">Loading audit trail...</td></tr>';
            const logs = await API.getAuditLogs() || [];

            auditTable.innerHTML = logs.map(l => {
                const logId = l.log_id ?? l.LOG_ID;
                const tblName = l.table_name ?? l.TABLE_NAME ?? '';
                const actType = l.action_type ?? l.ACTION_TYPE ?? '';
                const recId = l.record_id ?? l.RECORD_ID ?? '';
                const chgBy = l.changed_by ?? l.CHANGED_BY ?? '';
                const logTs = l.log_timestamp ?? l.LOG_TIMESTAMP ?? new Date().toISOString();
                return `
                <tr>
                    <td>#${logId}</td>
                    <td><span class="stock-pill" style="background:#e0e7ff; color:#3730a3;">${tblName}</span></td>
                    <td>
                        <span class="stock-pill ${actType === 'INSERT' ? 'stock-in' : (actType === 'DELETE' ? 'stock-out' : 'stock-low')}">
                            ${actType}
                        </span>
                    </td>
                    <td>Record #${escapeHtml(recId)}</td>
                    <td>${escapeHtml(chgBy)}</td>
                    <td style="font-size:0.82rem; color:var(--text-muted);">${new Date(logTs).toLocaleString()}</td>
                </tr>
            `;
            }).join('') || '<tr><td colspan="6" style="text-align:center;">No audit records available.</td></tr>';
        } catch (err) {
            auditTable.innerHTML = `<tr><td colspan="6" style="color:red; text-align:center;">Error: ${err.message}</td></tr>`;
        }
    }

    // Reset database button
    const btnResetDb = document.getElementById('btn-reset-db');
    if (btnResetDb) {
        btnResetDb.addEventListener('click', async () => {
            if (!confirm('Are you sure you want to reset the database simulator to the original initial seed data?')) return;
            try {
                await API.resetDatabase();
                showToast('Database reset to initial seed state successfully!', 'success');
                loadDashboard();
            } catch (err) {
                showToast(err.message, 'error');
            }
        });
    }

    // Auto-load initial tab
    loadDashboard();
});

// Helper
function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}
