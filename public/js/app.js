// ============================================================================
// ONLINE BOOKSTORE MANAGEMENT SYSTEM
// File: public/js/app.js
// Description: Storefront Client Logic - Catalog, Search, Cart, Checkout, Auth.
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
    // State
    let currentCategoryId = null;
    let currentSort = 'TITLE_ASC';
    let searchQuery = '';
    let minPrice = null;
    let maxPrice = null;
    let appliedPromo = '';

    // DOM Elements
    const booksContainer = document.getElementById('books-grid');
    const catalogCount = document.getElementById('catalog-count');
    const categoryList = document.getElementById('category-list');
    const searchInput = document.getElementById('search-input');
    const sortSelect = document.getElementById('sort-select');
    const minPriceInput = document.getElementById('min-price');
    const maxPriceInput = document.getElementById('max-price');
    const filterBtn = document.getElementById('btn-apply-filters');
    const resetFilterBtn = document.getElementById('btn-reset-filters');

    // Cart Elements
    const cartToggleBtn = document.getElementById('cart-toggle-btn');
    const cartDrawer = document.getElementById('cart-drawer');
    const cartBackdrop = document.getElementById('cart-backdrop');
    const cartCloseBtn = document.getElementById('cart-close-btn');
    const cartItemsList = document.getElementById('cart-items-list');
    const cartBadge = document.getElementById('cart-badge');
    const cartSubtotalEl = document.getElementById('cart-subtotal');
    const cartTaxEl = document.getElementById('cart-tax');
    const cartShippingEl = document.getElementById('cart-shipping');
    const cartDiscountEl = document.getElementById('cart-discount');
    const cartTotalEl = document.getElementById('cart-total');
    const checkoutBtn = document.getElementById('btn-checkout');
    const promoInput = document.getElementById('promo-input');
    const applyPromoBtn = document.getElementById('btn-apply-promo');

    // Auth & Navigation Elements
    const authBtn = document.getElementById('auth-btn');
    const adminLink = document.getElementById('admin-nav-link');
    const authModal = document.getElementById('auth-modal');
    const authModalBackdrop = document.getElementById('auth-backdrop');
    const authCloseBtn = document.getElementById('auth-close-btn');
    const tabLogin = document.getElementById('tab-login');
    const tabRegister = document.getElementById('tab-register');
    const formLogin = document.getElementById('form-login');
    const formRegister = document.getElementById('form-register');

    // Orders Modal
    const ordersModal = document.getElementById('orders-modal');
    const ordersModalBackdrop = document.getElementById('orders-backdrop');
    const ordersCloseBtn = document.getElementById('orders-close-btn');
    const ordersListContainer = document.getElementById('orders-list-container');

    // Checkout Modal
    const checkoutModal = document.getElementById('checkout-modal');
    const checkoutModalBackdrop = document.getElementById('checkout-backdrop');
    const checkoutCloseBtn = document.getElementById('checkout-close-btn');
    const formCheckout = document.getElementById('form-checkout');

    // Book Details Modal
    const bookDetailsModal = document.getElementById('book-details-modal');
    const bookDetailsBackdrop = document.getElementById('book-details-backdrop');
    const bookDetailsCloseBtn = document.getElementById('book-details-close-btn');
    const bookDetailsContent = document.getElementById('book-details-content');

    // ------------------------------------------------------------------------
    // Initialization
    // ------------------------------------------------------------------------
    async function init() {
        updateAuthUI();
        await loadCategories();
        await loadBooks();
        await refreshCart();
        setupEventListeners();
    }

    // ------------------------------------------------------------------------
    // UI Authentication State
    // ------------------------------------------------------------------------
    function updateAuthUI() {
        const user = API.getUser();
        if (user) {
            authBtn.innerHTML = `👤 ${escapeHtml(user.full_name || user.username)}`;
            authBtn.classList.remove('btn-outline');
            authBtn.classList.add('btn-primary');

            if (API.isAdmin()) {
                if (adminLink) adminLink.style.display = 'inline-flex';
            } else {
                if (adminLink) adminLink.style.display = 'none';
            }
        } else {
            authBtn.innerHTML = `Sign In / Register`;
            authBtn.classList.remove('btn-primary');
            authBtn.classList.add('btn-outline');
            if (adminLink) adminLink.style.display = 'none';
        }
    }

    // ------------------------------------------------------------------------
    // Categories
    // ------------------------------------------------------------------------
    async function loadCategories() {
        try {
            const res = await API.getCategories();
            if (res.status === 'SUCCESS' && res.data) {
                categoryList.innerHTML = `
                    <li class="category-item active" data-id="">
                        <span>All Categories</span>
                    </li>
                    ${res.data.map(cat => `
                        <li class="category-item" data-id="${cat.category_id}">
                            <span>${escapeHtml(cat.category_name)}</span>
                        </li>
                    `).join('')}
                `;

                categoryList.querySelectorAll('.category-item').forEach(item => {
                    item.addEventListener('click', () => {
                        categoryList.querySelectorAll('.category-item').forEach(i => i.classList.remove('active'));
                        item.classList.add('active');
                        currentCategoryId = item.getAttribute('data-id') || null;
                        loadBooks();
                    });
                });
            }
        } catch (err) {
            console.error('Failed to load categories', err);
        }
    }

    // ------------------------------------------------------------------------
    // Books Catalog
    // ------------------------------------------------------------------------
    async function loadBooks() {
        try {
            booksContainer.innerHTML = '<div style="grid-column: 1/-1; text-align: center; padding: 3rem;">Loading catalog...</div>';

            const params = {};
            if (searchQuery) params.q = searchQuery;
            if (currentCategoryId) params.category_id = currentCategoryId;
            if (minPrice !== null && minPrice !== '') params.min_price = minPrice;
            if (maxPrice !== null && maxPrice !== '') params.max_price = maxPrice;
            if (currentSort) params.sort_by = currentSort;

            const res = await API.getBooks(params);
            const books = res.data || [];

            catalogCount.textContent = `Showing ${books.length} book${books.length === 1 ? '' : 's'}`;

            if (books.length === 0) {
                booksContainer.innerHTML = `
                    <div style="grid-column: 1/-1; text-align: center; padding: 4rem 1rem; color: var(--text-muted);">
                        <p style="font-size: 1.25rem; font-weight: 600; margin-bottom: 0.5rem;">No books found</p>
                        <p>Try refining your search terms or clearing price filters.</p>
                    </div>
                `;
                return;
            }

            booksContainer.innerHTML = books.map(book => {
                const bookId = book.book_id ?? book.BOOK_ID;
                const title = book.title ?? book.TITLE ?? '';
                const author = book.author ?? book.AUTHOR ?? '';
                const categoryName = book.category_name ?? book.CATEGORY_NAME ?? 'General';
                const price = typeof book.price === 'number' ? book.price : (parseFloat(book.price ?? book.PRICE) || 0);
                const stockQty = typeof book.stock_quantity === 'number' ? book.stock_quantity : (parseInt(book.stock_quantity ?? book.STOCK_QUANTITY, 10) || 0);
                const coverUrl = book.cover_image_url ?? book.COVER_IMAGE_URL ?? 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=600&q=80';
                const rating = typeof book.rating === 'number' ? book.rating : (parseFloat(book.rating ?? book.RATING) || 4.5);
                const stockStatus = book.stock_status ?? book.STOCK_STATUS ?? (stockQty === 0 ? 'Out of Stock' : (stockQty <= 5 ? 'Low Stock' : 'In Stock'));

                let stockClass = 'stock-in';
                if (stockQty === 0) stockClass = 'stock-out';
                else if (stockQty <= 5) stockClass = 'stock-low';

                return `
                    <div class="book-card" data-id="${bookId}">
                        <div class="book-cover-container" onclick="openBookDetails(${bookId})">
                            <img src="${escapeHtml(coverUrl)}"
                                 alt="${escapeHtml(title)}" class="book-cover" onerror="this.src='https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=600&q=80'">
                            <span class="stock-pill ${stockClass}">${escapeHtml(stockStatus)}</span>
                        </div>
                        <div class="book-info">
                            <div class="book-category">${escapeHtml(categoryName)}</div>
                            <div class="book-title" onclick="openBookDetails(${bookId})" title="${escapeHtml(title)}">${escapeHtml(title)}</div>
                            <div class="book-author">by ${escapeHtml(author)}</div>
                            <div class="book-rating">
                                <span>★</span> ${rating.toFixed(1)}
                            </div>
                            <div class="book-card-footer">
                                <div class="book-price">$${price.toFixed(2)}</div>
                                <button class="btn btn-primary btn-sm btn-add-cart" data-id="${bookId}" ${stockQty === 0 ? 'disabled' : ''}>
                                    ${stockQty === 0 ? 'Sold Out' : '+ Cart'}
                                </button>
                            </div>
                        </div>
                    </div>
                `;
            }).join('');

            // Add to Cart handlers
            booksContainer.querySelectorAll('.btn-add-cart').forEach(btn => {
                btn.addEventListener('click', async (e) => {
                    e.stopPropagation();
                    const bookId = btn.getAttribute('data-id');
                    try {
                        const r = await API.addToCart(bookId, 1);
                        showToast(r.message || 'Added to cart!', 'success');
                    } catch (err) {
                        showToast(err.message, 'error');
                    }
                });
            });

        } catch (err) {
            console.error('Error loading books', err);
            booksContainer.innerHTML = `
                <div style="grid-column: 1/-1; text-align: center; padding: 3rem 1rem; color: var(--danger);">
                    <p style="font-size: 1.15rem; font-weight: 700; margin-bottom: 0.5rem;">Failed to load catalog</p>
                    <p style="color: var(--text-muted); font-size: 0.9rem; margin-bottom: 1rem;">${escapeHtml(err.message || 'Please verify the backend server is running.')}</p>
                    <button class="btn btn-outline btn-sm" onclick="location.reload()">Retry Connection</button>
                </div>
            `;
        }
    }

    // ------------------------------------------------------------------------
    // Book Details Modal
    // ------------------------------------------------------------------------
    window.openBookDetails = async function (bookId) {
        try {
            const res = await API.getBookDetails(bookId);
            const book = res.data;
            if (!book) return;

            const bId = book.book_id ?? book.BOOK_ID;
            const title = book.title ?? book.TITLE ?? '';
            const author = book.author ?? book.AUTHOR ?? '';
            const catName = book.category_name ?? book.CATEGORY_NAME ?? 'General';
            const price = Number(book.price ?? book.PRICE) || 0;
            const stockQty = Number(book.stock_quantity ?? book.STOCK_QUANTITY) || 0;
            const coverUrl = book.cover_image_url ?? book.COVER_IMAGE_URL ?? 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=600&q=80';
            const isbn = book.isbn ?? book.ISBN ?? '';
            const pubYear = book.publication_year ?? book.PUBLICATION_YEAR ?? 'N/A';
            const publisher = book.publisher ?? book.PUBLISHER ?? 'Independent';
            const desc = book.description ?? book.DESCRIPTION ?? 'No description provided for this title.';

            bookDetailsContent.innerHTML = `
                <div style="display: flex; gap: 1.5rem; flex-wrap: wrap;">
                    <div style="flex: 0 0 200px; text-align: center;">
                        <img src="${escapeHtml(coverUrl)}" alt="${escapeHtml(title)}"
                             style="width: 100%; max-height: 280px; object-fit: cover; border-radius: var(--radius-sm); box-shadow: var(--shadow);">
                        <div style="margin-top: 1rem; font-weight: 700; font-size: 1.4rem; color: var(--primary);">
                            $${price.toFixed(2)}
                        </div>
                        <div style="margin-top: 0.35rem; font-size: 0.85rem; color: var(--text-muted);">
                            Available Stock: <strong>${stockQty} units</strong>
                        </div>
                    </div>
                    <div style="flex: 1; min-width: 260px;">
                        <div style="font-size: 0.8rem; font-weight: 700; color: var(--primary); text-transform: uppercase;">
                            ${escapeHtml(catName)}
                        </div>
                        <h2 style="font-size: 1.4rem; font-weight: 800; margin: 0.35rem 0;">${escapeHtml(title)}</h2>
                        <p style="color: var(--text-muted); font-size: 0.95rem; margin-bottom: 0.85rem;">
                            By <strong>${escapeHtml(author)}</strong> | Published: ${pubYear} (${escapeHtml(publisher)})
                        </p>
                        <p style="font-size: 0.82rem; color: var(--text-muted); margin-bottom: 1rem;">
                            ISBN: <code>${escapeHtml(isbn)}</code>
                        </p>
                        <div style="font-size: 0.92rem; line-height: 1.6; color: var(--text-main); margin-bottom: 1.5rem; max-height: 140px; overflow-y: auto;">
                            ${escapeHtml(desc)}
                        </div>
                        <div style="display: flex; gap: 1rem; align-items: center;">
                            <input type="number" id="modal-qty-input" value="1" min="1" max="${stockQty}"
                                   style="width: 70px; padding: 0.5rem; border: 1px solid var(--border); border-radius: var(--radius-sm); font-size: 1rem;">
                            <button id="modal-add-cart-btn" class="btn btn-primary" ${stockQty === 0 ? 'disabled' : ''}>
                                ${stockQty === 0 ? 'Out of Stock' : 'Add to Shopping Cart'}
                            </button>
                        </div>
                    </div>
                </div>
            `;

            const modalAddBtn = document.getElementById('modal-add-cart-btn');
            if (modalAddBtn && stockQty > 0) {
                modalAddBtn.addEventListener('click', async () => {
                    const qty = parseInt(document.getElementById('modal-qty-input').value, 10) || 1;
                    try {
                        const r = await API.addToCart(bId, qty);
                        showToast(r.message || 'Added to cart!', 'success');
                        closeBookDetailsModal();
                    } catch (err) {
                        showToast(err.message, 'error');
                    }
                });
            }

            bookDetailsModal.classList.add('active');
            bookDetailsBackdrop.classList.add('active');
        } catch (err) {
            showToast('Failed to load book details: ' + err.message, 'error');
        }
    };

    function closeBookDetailsModal() {
        bookDetailsModal.classList.remove('active');
        bookDetailsBackdrop.classList.remove('active');
    }

    // ------------------------------------------------------------------------
    // Shopping Cart Drawer & Calculations
    // ------------------------------------------------------------------------
    async function refreshCart() {
        try {
            const cartData = await API.getCart();
            const items = cartData.items || [];

            // Update badge
            cartBadge.textContent = cartData.item_count || 0;

            if (items.length === 0) {
                cartItemsList.innerHTML = `
                    <div class="cart-empty">
                        <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">🛒</div>
                        <p style="font-weight: 600; font-size: 1.1rem; color: var(--dark);">Your cart is empty</p>
                        <p style="font-size: 0.9rem;">Browse books and add items to your basket!</p>
                    </div>
                `;
                checkoutBtn.disabled = true;
                cartSubtotalEl.textContent = '$0.00';
                cartTaxEl.textContent = '$0.00';
                cartShippingEl.textContent = '$0.00';
                cartDiscountEl.textContent = '$0.00';
                cartTotalEl.textContent = '$0.00';
                return;
            }

            checkoutBtn.disabled = false;
            cartItemsList.innerHTML = items.map(item => {
                const bookId = item.book_id ?? item.BOOK_ID;
                const title = item.title ?? item.TITLE ?? '';
                const coverUrl = item.cover_image_url ?? item.COVER_IMAGE_URL ?? '';
                const price = Number(item.price ?? item.PRICE) || 0;
                const qty = Number(item.quantity ?? item.QUANTITY) || 1;
                const lineTot = Number(item.line_total ?? item.LINE_TOTAL) || (price * qty);

                return `
                <div class="cart-item">
                    <img src="${escapeHtml(coverUrl)}" alt="${escapeHtml(title)}" class="cart-item-img">
                    <div class="cart-item-details">
                        <div class="cart-item-title" title="${escapeHtml(title)}">${escapeHtml(title)}</div>
                        <div class="cart-item-price">$${price.toFixed(2)} each</div>
                        <div class="cart-item-actions">
                            <div class="qty-control">
                                <button class="qty-btn" onclick="updateCartItemQty(${bookId}, ${qty - 1})">-</button>
                                <span class="qty-display">${qty}</span>
                                <button class="qty-btn" onclick="updateCartItemQty(${bookId}, ${qty + 1})">+</button>
                            </div>
                            <div style="font-weight: 700; font-size: 0.95rem;">$${lineTot.toFixed(2)}</div>
                            <button class="btn-remove-item" onclick="removeCartItem(${bookId})">Remove</button>
                        </div>
                    </div>
                </div>
            `;
            }).join('');

            // Calculate totals matching PKG_ORDER_MGMT & FN_CALCULATE_DISCOUNT
            const subtotal = Number(cartData.subtotal ?? cartData.SUBTOTAL) || 0;
            let discount = 0;

            if (appliedPromo) {
                const code = appliedPromo.trim().toUpperCase();
                if (code === 'BOOKWORM10') discount = Number((subtotal * 0.10).toFixed(2));
                else if (code === 'READ20' && subtotal >= 40.0) discount = Number((subtotal * 0.20).toFixed(2));
                else if (code === 'FREESHIP') discount = 5.00;
                else if (code === 'WELCOME5') discount = 5.00;
                if (discount > subtotal) discount = subtotal;
            }

            const tax = Number((subtotal * 0.05).toFixed(2));
            const shipping = subtotal >= 50.00 ? 0.00 : 5.00;
            const total = Number((subtotal + tax + shipping - discount).toFixed(2));

            cartSubtotalEl.textContent = `$${subtotal.toFixed(2)}`;
            cartTaxEl.textContent = `$${tax.toFixed(2)}`;
            cartShippingEl.textContent = shipping === 0 ? 'FREE' : `$${shipping.toFixed(2)}`;
            cartDiscountEl.textContent = discount > 0 ? `-$${discount.toFixed(2)}` : '$0.00';
            cartTotalEl.textContent = `$${total.toFixed(2)}`;

        } catch (err) {
            console.error('Error refreshing cart', err);
        }
    }

    window.updateCartItemQty = async function (bookId, newQty) {
        try {
            await API.updateCartQty(bookId, newQty);
        } catch (err) {
            showToast(err.message, 'error');
        }
    };

    window.removeCartItem = async function (bookId) {
        try {
            await API.removeFromCart(bookId);
            showToast('Item removed from cart', 'info');
        } catch (err) {
            showToast(err.message, 'error');
        }
    };

    function toggleCart(show) {
        if (show) {
            cartDrawer.classList.add('active');
            cartBackdrop.classList.add('active');
            refreshCart();
        } else {
            cartDrawer.classList.remove('active');
            cartBackdrop.classList.remove('active');
        }
    }

    // ------------------------------------------------------------------------
    // Checkout Flow
    // ------------------------------------------------------------------------
    checkoutBtn.addEventListener('click', () => {
        const user = API.getUser();
        if (!user) {
            showToast('Please sign in or register to complete your order.', 'info');
            openAuthModal();
            return;
        }

        // Pre-fill user data
        document.getElementById('checkout-name').value = user.full_name || '';
        document.getElementById('checkout-phone').value = user.phone || '';
        document.getElementById('checkout-address').value = user.address || '';
        document.getElementById('checkout-promo-display').textContent = appliedPromo || 'None';

        toggleCart(false);
        checkoutModal.classList.add('active');
        checkoutModalBackdrop.classList.add('active');
    });

    formCheckout.addEventListener('submit', async (e) => {
        e.preventDefault();
        const address = document.getElementById('checkout-address').value.trim();
        const phone = document.getElementById('checkout-phone').value.trim();
        const paymentMethod = document.getElementById('checkout-payment-method').value;
        const notes = document.getElementById('checkout-notes').value.trim();

        if (!address) {
            showToast('Please enter your delivery address.', 'error');
            return;
        }

        try {
            const res = await API.checkout({
                shipping_address: address,
                contact_phone: phone,
                payment_method: paymentMethod,
                customer_notes: notes,
                promo_code: appliedPromo
            });

            checkoutModal.classList.remove('active');
            checkoutModalBackdrop.classList.remove('active');
            appliedPromo = '';

            showToast(res.message || 'Order placed successfully!', 'success');
            await loadBooks(); // reload inventory counts
            openOrdersModal(); // open order history
        } catch (err) {
            showToast(err.message, 'error');
        }
    });

    // ------------------------------------------------------------------------
    // User Order History & Status Timeline
    // ------------------------------------------------------------------------
    async function openOrdersModal() {
        const user = API.getUser();
        if (!user) {
            openAuthModal();
            return;
        }

        try {
            const orders = await API.getUserOrders();
            if (orders.length === 0) {
                ordersListContainer.innerHTML = '<div style="text-align: center; padding: 2.5rem; color: var(--text-muted);">You have no order history yet.</div>';
            } else {
                ordersListContainer.innerHTML = orders.map(order => {
                    const statusSteps = ['PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED'];
                    const currentIndex = statusSteps.indexOf(order.order_status);
                    const isCancelled = order.order_status === 'CANCELLED';

                    return `
                        <div style="background: #f8fafc; border: 1px solid var(--border); border-radius: var(--radius-sm); padding: 1.25rem; margin-bottom: 1.25rem;">
                            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem; flex-wrap: wrap; gap: 0.5rem;">
                                <div>
                                    <span style="font-weight: 800; font-size: 1.1rem; color: var(--dark);">Order #${order.order_id}</span>
                                    <span style="font-size: 0.85rem; color: var(--text-muted); margin-left: 0.5rem;">Placed on ${new Date(order.order_date).toLocaleDateString()}</span>
                                </div>
                                <div>
                                    <span class="stock-pill ${isCancelled ? 'stock-out' : (order.order_status === 'DELIVERED' ? 'stock-in' : 'stock-low')}">
                                        ${order.order_status}
                                    </span>
                                </div>
                            </div>

                            <!-- Visual Step Progress Tracker -->
                            ${!isCancelled ? `
                                <div style="display: flex; align-items: center; justify-content: space-between; margin: 1.2rem 0; position: relative;">
                                    ${statusSteps.map((step, idx) => `
                                        <div style="display: flex; flex-direction: column; align-items: center; z-index: 2; flex: 1;">
                                            <div style="width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 0.75rem; font-weight: 700;
                                                        background: ${idx <= currentIndex ? 'var(--primary)' : '#e2e8f0'};
                                                        color: ${idx <= currentIndex ? '#fff' : 'var(--text-muted)'};">
                                                ${idx + 1}
                                            </div>
                                            <span style="font-size: 0.72rem; margin-top: 0.25rem; font-weight: 600; color: ${idx <= currentIndex ? 'var(--primary)' : 'var(--text-muted)'};">
                                                ${step}
                                            </span>
                                        </div>
                                    `).join('')}
                                </div>
                            ` : `
                                <div style="padding: 0.5rem; background: #fee2e2; color: #b91c1c; border-radius: var(--radius-sm); font-size: 0.85rem; margin-bottom: 0.75rem;">
                                    This order was cancelled and inventory stock was automatically restored.
                                </div>
                            `}

                            <!-- Items List -->
                            <div style="border-top: 1px solid var(--border); padding-top: 0.75rem; margin-top: 0.5rem;">
                                ${(order.items || []).map(it => {
                                    const itTitle = it.title ?? it.TITLE ?? '';
                                    const itQty = Number(it.quantity ?? it.QUANTITY) || 1;
                                    const itLineTot = Number(it.line_total ?? it.LINE_TOTAL) || 0;
                                    return `
                                    <div style="display: flex; justify-content: space-between; font-size: 0.9rem; margin-bottom: 0.35rem;">
                                        <span>${escapeHtml(itTitle)} × ${itQty}</span>
                                        <span style="font-weight: 600;">$${itLineTot.toFixed(2)}</span>
                                    </div>
                                    `;
                                }).join('')}
                            </div>

                            <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px dashed var(--border); padding-top: 0.75rem; margin-top: 0.5rem;">
                                <div style="font-size: 0.85rem; color: var(--text-muted);">
                                    Payment: <strong>${order.payment_method ?? order.PAYMENT_METHOD ?? 'CARD'} (${order.payment_status ?? order.PAYMENT_STATUS ?? 'COMPLETED'})</strong>
                                </div>
                                <div style="font-size: 1.15rem; font-weight: 800; color: var(--dark);">
                                    Total: $${(Number(order.total_amount ?? order.TOTAL_AMOUNT) || 0).toFixed(2)}
                                </div>
                            </div>

                            ${['PENDING', 'PROCESSING'].includes(order.order_status ?? order.ORDER_STATUS) ? `
                                <div style="text-align: right; margin-top: 0.75rem;">
                                    <button class="btn btn-outline btn-sm" style="color: var(--danger); border-color: var(--danger);"
                                            onclick="cancelUserOrder(${order.order_id ?? order.ORDER_ID})">
                                        Cancel Order
                                    </button>
                                </div>
                            ` : ''}
                        </div>
                    `;
                }).join('');
            }

            ordersModal.classList.add('active');
            ordersModalBackdrop.classList.add('active');
        } catch (err) {
            showToast('Failed to load orders: ' + err.message, 'error');
        }
    }

    window.cancelUserOrder = async function (orderId) {
        if (!confirm(`Are you sure you want to cancel Order #${orderId}?`)) return;
        try {
            const res = await API.cancelOrder(orderId, 'Customer requested cancellation via portal');
            showToast(res.message || 'Order cancelled successfully.', 'success');
            openOrdersModal();
            loadBooks(); // refresh stock counts
        } catch (err) {
            showToast(err.message, 'error');
        }
    };

    // ------------------------------------------------------------------------
    // Authentication Modal & Profile Handlers
    // ------------------------------------------------------------------------
    function openAuthModal() {
        const user = API.getUser();
        if (user) {
            // Already logged in: show profile & orders
            openOrdersModal();
            return;
        }
        authModal.classList.add('active');
        authModalBackdrop.classList.add('active');
    }

    function closeAuthModal() {
        authModal.classList.remove('active');
        authModalBackdrop.classList.remove('active');
    }

    tabLogin.addEventListener('click', () => {
        tabLogin.classList.add('btn-primary');
        tabLogin.classList.remove('btn-outline');
        tabRegister.classList.remove('btn-primary');
        tabRegister.classList.add('btn-outline');
        formLogin.style.display = 'block';
        formRegister.style.display = 'none';
    });

    tabRegister.addEventListener('click', () => {
        tabRegister.classList.add('btn-primary');
        tabRegister.classList.remove('btn-outline');
        tabLogin.classList.remove('btn-primary');
        tabLogin.classList.add('btn-outline');
        formRegister.style.display = 'block';
        formLogin.style.display = 'none';
    });

    // Quick demo buttons
    document.getElementById('quick-fill-admin').addEventListener('click', () => {
        document.getElementById('login-username').value = 'admin';
        document.getElementById('login-password').value = 'Admin@123';
    });

    document.getElementById('quick-fill-user').addEventListener('click', () => {
        document.getElementById('login-username').value = 'johndoe';
        document.getElementById('login-password').value = 'User@123';
    });

    formLogin.addEventListener('submit', async (e) => {
        e.preventDefault();
        const u = document.getElementById('login-username').value.trim();
        const p = document.getElementById('login-password').value;

        try {
            const res = await API.login(u, p);
            showToast(res.message || 'Signed in successfully!', 'success');
            closeAuthModal();
            updateAuthUI();
            refreshCart();
        } catch (err) {
            showToast(err.message, 'error');
        }
    });

    formRegister.addEventListener('submit', async (e) => {
        e.preventDefault();
        const username = document.getElementById('reg-username').value.trim();
        const email = document.getElementById('reg-email').value.trim();
        const password = document.getElementById('reg-password').value;
        const fullName = document.getElementById('reg-fullname').value.trim();
        const phone = document.getElementById('reg-phone').value.trim();
        const address = document.getElementById('reg-address').value.trim();

        try {
            const res = await API.register({
                username, email, password,
                full_name: fullName,
                phone, address, role_id: 2
            });
            showToast(res.message || 'Registration successful! Signing in...', 'success');
            await API.login(username, password);
            closeAuthModal();
            updateAuthUI();
        } catch (err) {
            showToast(err.message, 'error');
        }
    });

    // ------------------------------------------------------------------------
    // Search, Filters, Promo Codes
    // ------------------------------------------------------------------------
    function setupEventListeners() {
        // Search
        let debounceTimer;
        searchInput.addEventListener('input', (e) => {
            clearTimeout(debounceTimer);
            debounceTimer = setTimeout(() => {
                searchQuery = e.target.value.trim();
                loadBooks();
            }, 300);
        });

        // Sort
        sortSelect.addEventListener('change', (e) => {
            currentSort = e.target.value;
            loadBooks();
        });

        // Price Filters
        filterBtn.addEventListener('click', () => {
            minPrice = minPriceInput.value;
            maxPrice = maxPriceInput.value;
            loadBooks();
        });

        resetFilterBtn.addEventListener('click', () => {
            minPriceInput.value = '';
            maxPriceInput.value = '';
            minPrice = null;
            maxPrice = null;
            searchQuery = '';
            searchInput.value = '';
            currentCategoryId = null;
            categoryList.querySelectorAll('.category-item').forEach(i => i.classList.remove('active'));
            const first = categoryList.querySelector('.category-item[data-id=""]');
            if (first) first.classList.add('active');
            loadBooks();
        });

        // Cart Drawer
        cartToggleBtn.addEventListener('click', () => toggleCart(true));
        cartCloseBtn.addEventListener('click', () => toggleCart(false));
        cartBackdrop.addEventListener('click', () => toggleCart(false));

        // Promo
        applyPromoBtn.addEventListener('click', () => {
            const val = promoInput.value.trim().toUpperCase();
            if (!val) return;
            const validPromos = ['BOOKWORM10', 'READ20', 'FREESHIP', 'WELCOME5'];
            if (!validPromos.includes(val)) {
                showToast('Invalid coupon code. Try BOOKWORM10, READ20, or FREESHIP.', 'error');
                return;
            }
            appliedPromo = val;
            showToast(`Coupon "${val}" applied successfully!`, 'success');
            refreshCart();
        });

        // Modals close buttons
        authBtn.addEventListener('click', openAuthModal);
        authCloseBtn.addEventListener('click', closeAuthModal);
        authModalBackdrop.addEventListener('click', closeAuthModal);

        ordersCloseBtn.addEventListener('click', () => {
            ordersModal.classList.remove('active');
            ordersModalBackdrop.classList.remove('active');
        });
        ordersModalBackdrop.addEventListener('click', () => {
            ordersModal.classList.remove('active');
            ordersModalBackdrop.classList.remove('active');
        });

        checkoutCloseBtn.addEventListener('click', () => {
            checkoutModal.classList.remove('active');
            checkoutModalBackdrop.classList.remove('active');
        });
        checkoutModalBackdrop.addEventListener('click', () => {
            checkoutModal.classList.remove('active');
            checkoutModalBackdrop.classList.remove('active');
        });

        bookDetailsCloseBtn.addEventListener('click', closeBookDetailsModal);
        bookDetailsBackdrop.addEventListener('click', closeBookDetailsModal);

        // Global events
        window.addEventListener('cart-updated', () => refreshCart());
        window.addEventListener('auth-changed', () => updateAuthUI());
    }

    // Helper: HTML sanitization
    function escapeHtml(str) {
        if (!str) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    // Run
    init();
});
