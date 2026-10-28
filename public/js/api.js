// ============================================================================
// ONLINE BOOKSTORE MANAGEMENT SYSTEM
// File: public/js/api.js
// Description: Central REST API Client and Application State Store.
// ============================================================================

const API = {
    baseUrl: '',

    // ------------------------------------------------------------------------
    // Session State Management
    // ------------------------------------------------------------------------
    getUser() {
        const raw = localStorage.getItem('bookstore_user');
        try {
            return raw ? JSON.parse(raw) : null;
        } catch (e) {
            return null;
        }
    },

    setUser(user) {
        if (user) {
            localStorage.setItem('bookstore_user', JSON.stringify(user));
        } else {
            localStorage.removeItem('bookstore_user');
        }
        window.dispatchEvent(new CustomEvent('auth-changed', { detail: user }));
    },

    getUserId() {
        const user = this.getUser();
        return user ? user.user_id : 1002; // default fallback demo user
    },

    isAdmin() {
        const user = this.getUser();
        return user && (user.role_name === 'ADMIN' || user.role_id === 1);
    },

    // ------------------------------------------------------------------------
    // HTTP Request Wrapper
    // ------------------------------------------------------------------------
    async request(endpoint, options = {}) {
        const url = `${this.baseUrl}${endpoint}`;
        const headers = {
            'Content-Type': 'application/json',
            ...(options.headers || {})
        };

        const user = this.getUser();
        if (user && user.user_id) {
            headers['Authorization'] = `Bearer ${user.user_id}`;
        }

        try {
            const res = await fetch(url, {
                ...options,
                headers
            });
            const data = await res.json();
            if (!res.ok) {
                throw new Error(data.message || `Request failed with status ${res.status}`);
            }
            return data;
        } catch (err) {
            console.error(`API Error [${endpoint}]:`, err);
            throw err;
        }
    },

    // ------------------------------------------------------------------------
    // User Authentication & Profile (PKG_USER_MGMT)
    // ------------------------------------------------------------------------
    async register(userData) {
        const res = await this.request('/api/auth/register', {
            method: 'POST',
            body: JSON.stringify(userData)
        });
        return res;
    },

    async login(username, password) {
        const res = await this.request('/api/auth/login', {
            method: 'POST',
            body: JSON.stringify({ username, password })
        });
        if (res.status === 'SUCCESS' && res.user) {
            this.setUser(res.user);
        }
        return res;
    },

    logout() {
        this.setUser(null);
    },

    async getProfile() {
        return await this.request('/api/auth/profile');
    },

    async updateProfile(profileData) {
        const res = await this.request('/api/auth/profile', {
            method: 'PUT',
            body: JSON.stringify(profileData)
        });
        // Update cached session
        const current = this.getUser();
        if (current) {
            this.setUser({ ...current, ...profileData });
        }
        return res;
    },

    async changePassword(oldPassword, newPassword) {
        return await this.request('/api/auth/change-password', {
            method: 'POST',
            body: JSON.stringify({ old_password: oldPassword, new_password: newPassword })
        });
    },

    // ------------------------------------------------------------------------
    // Book Management (PKG_BOOK_MGMT)
    // ------------------------------------------------------------------------
    async getCategories() {
        return await this.request('/api/categories');
    },

    async getBooks(params = {}) {
        const queryStr = new URLSearchParams(params).toString();
        return await this.request(`/api/books?${queryStr}`);
    },

    async getBookDetails(bookId) {
        return await this.request(`/api/books/${bookId}`);
    },

    async addBook(bookData) {
        return await this.request('/api/books', {
            method: 'POST',
            body: JSON.stringify(bookData)
        });
    },

    async updateBook(bookId, bookData) {
        return await this.request(`/api/books/${bookId}`, {
            method: 'PUT',
            body: JSON.stringify(bookData)
        });
    },

    async deleteBook(bookId, hardDelete = false) {
        return await this.request(`/api/books/${bookId}?hard=${hardDelete}`, {
            method: 'DELETE'
        });
    },

    // ------------------------------------------------------------------------
    // Shopping Cart (PKG_CART_MGMT)
    // ------------------------------------------------------------------------
    async getCart() {
        const res = await this.request('/api/cart');
        return res.data;
    },

    async addToCart(bookId, quantity = 1) {
        const res = await this.request('/api/cart', {
            method: 'POST',
            body: JSON.stringify({ book_id: bookId, quantity })
        });
        window.dispatchEvent(new CustomEvent('cart-updated'));
        return res;
    },

    async updateCartQty(bookId, quantity) {
        const res = await this.request(`/api/cart/${bookId}`, {
            method: 'PUT',
            body: JSON.stringify({ quantity })
        });
        window.dispatchEvent(new CustomEvent('cart-updated'));
        return res;
    },

    async removeFromCart(bookId) {
        const res = await this.request(`/api/cart/${bookId}`, {
            method: 'DELETE'
        });
        window.dispatchEvent(new CustomEvent('cart-updated'));
        return res;
    },

    async clearCart() {
        const res = await this.request('/api/cart', {
            method: 'DELETE'
        });
        window.dispatchEvent(new CustomEvent('cart-updated'));
        return res;
    },

    // ------------------------------------------------------------------------
    // Order Management (PKG_ORDER_MGMT)
    // ------------------------------------------------------------------------
    async checkout(orderData) {
        const res = await this.request('/api/orders/checkout', {
            method: 'POST',
            body: JSON.stringify(orderData)
        });
        window.dispatchEvent(new CustomEvent('cart-updated'));
        return res;
    },

    async getUserOrders() {
        const res = await this.request('/api/orders');
        return res.data;
    },

    async getAllOrders() {
        const res = await this.request('/api/orders/all');
        return res.data;
    },

    async getOrderDetails(orderId) {
        const res = await this.request(`/api/orders/${orderId}`);
        return res.data;
    },

    async updateOrderStatus(orderId, status) {
        return await this.request(`/api/orders/${orderId}/status`, {
            method: 'PUT',
            body: JSON.stringify({ status })
        });
    },

    async cancelOrder(orderId, reason) {
        return await this.request(`/api/orders/${orderId}/cancel`, {
            method: 'POST',
            body: JSON.stringify({ reason })
        });
    },

    // ------------------------------------------------------------------------
    // Analytics & Reporting (PKG_REPORTS)
    // ------------------------------------------------------------------------
    async getDashboardSummary() {
        const res = await this.request('/api/reports/dashboard');
        return res.data;
    },

    async getBestsellers(limit = 10) {
        const res = await this.request(`/api/reports/bestsellers?limit=${limit}`);
        return res.data;
    },

    async getSalesTrends() {
        const res = await this.request('/api/reports/sales-trends');
        return res.data;
    },

    async getCategoryPerformance() {
        const res = await this.request('/api/reports/categories');
        return res.data;
    },

    async getLowStockAlert(threshold = 10) {
        const res = await this.request(`/api/reports/low-stock?threshold=${threshold}`);
        return res.data;
    },

    async getAuditLogs() {
        const res = await this.request('/api/audit-logs');
        return res.data;
    },

    // ------------------------------------------------------------------------
    // PL/SQL Source Files & Simulation Reset
    // ------------------------------------------------------------------------
    async getSqlFiles() {
        return await this.request('/api/plsql/files');
    },

    async resetDatabase() {
        return await this.request('/api/plsql/reset', { method: 'POST' });
    }
};

// ----------------------------------------------------------------------------
// Global UI Toast Notifications
// ----------------------------------------------------------------------------
function showToast(message, type = 'info') {
    let container = document.getElementById('toast-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'toast-container';
        container.className = 'toast-container';
        document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `
        <span>${type === 'success' ? '✓' : (type === 'error' ? '✕' : 'ℹ')}</span>
        <span>${message}</span>
    `;

    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateY(10px)';
        toast.style.transition = 'all 0.3s ease';
        setTimeout(() => toast.remove(), 300);
    }, 3500);
}
