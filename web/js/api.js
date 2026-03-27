// Surypus - API Client (Updated to match actual API routes)

const API_BASE = window.location.origin + '/api/v1';

const api = {
    // Auth API
    auth: {
        login: (username, password) => axios.post(`${API_BASE}/login`, { lrUsername: username, lrPassword: password }),
        logout: () => axios.post(`${API_BASE}/auth/logout`),
        me: () => axios.get(`${API_BASE}/auth/me`)
    },

    // Goods API
    goods: {
        list: (params = {}) => axios.get(`${API_BASE}/goods`, { params }),
        get: (id) => axios.get(`${API_BASE}/goods/${id}`),
        create: (data) => axios.post(`${API_BASE}/goods`, data),
        update: (id, data) => axios.put(`${API_BASE}/goods/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/goods/${id}`),
        prices: () => axios.get(`${API_BASE}/goods/prices`),
        pricesByGoods: (id) => axios.get(`${API_BASE}/goods/${id}/prices`),
        createPrice: (data) => axios.post(`${API_BASE}/goods/prices`, data),
        top: (limit = 10) => axios.get(`${API_BASE}/goods/top`, { params: { limit } }),
        lowStock: () => axios.get(`${API_BASE}/goods/low-stock`)
    },

    // Person API
    persons: {
        list: (params = {}) => axios.get(`${API_BASE}/persons`, { params }),
        get: (id) => axios.get(`${API_BASE}/persons/${id}`),
        search: (query) => axios.get(`${API_BASE}/persons/search/${query}`),
        create: (data) => axios.post(`${API_BASE}/persons`, data),
        update: (id, data) => axios.put(`${API_BASE}/persons/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/persons/${id}`)
    },

    // Bill API
    bills: {
        list: (params = {}) => axios.get(`${API_BASE}/bills`, { params }),
        get: (id) => axios.get(`${API_BASE}/bills/${id}`),
        create: (data) => axios.post(`${API_BASE}/bills`, data),
        updateStatus: (id, status) => axios.put(`${API_BASE}/bills/${id}/status`, null, { params: { status } }),
        delete: (id) => axios.delete(`${API_BASE}/bills/${id}`)
    },

    // Order API
    orders: {
        list: (params = {}) => axios.get(`${API_BASE}/orders`, { params }),
        get: (id) => axios.get(`${API_BASE}/orders/${id}`),
        create: (data) => axios.post(`${API_BASE}/orders`, data),
        updateStatus: (id, status) => axios.put(`${API_BASE}/orders/${id}/status`, null, { params: { status } }),
        delete: (id) => axios.delete(`${API_BASE}/orders/${id}`)
    },

    // Payment API
    payments: {
        list: () => axios.get(`${API_BASE}/payments`),
        get: (id) => axios.get(`${API_BASE}/payments/${id}`),
        create: (data) => axios.post(`${API_BASE}/payments`, data),
        update: (id, data) => axios.put(`${API_BASE}/payments/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/payments/${id}`)
    },

    // Location API
    locations: {
        list: () => axios.get(`${API_BASE}/locations`),
        get: (id) => axios.get(`${API_BASE}/locations/${id}`),
        create: (data) => axios.post(`${API_BASE}/locations`, data),
        update: (id, data) => axios.put(`${API_BASE}/locations/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/locations/${id}`)
    },

    // Tax API
    taxes: {
        list: () => axios.get(`${API_BASE}/taxes`),
        get: (id) => axios.get(`${API_BASE}/taxes/${id}`),
        create: (data) => axios.post(`${API_BASE}/taxes`, data),
        update: (id, data) => axios.put(`${API_BASE}/taxes/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/taxes/${id}`)
    },

    // Currency API
    currencies: {
        list: () => axios.get(`${API_BASE}/currencies`),
        get: (id) => axios.get(`${API_BASE}/currencies/${id}`),
        create: (data) => axios.post(`${API_BASE}/currencies`, data),
        update: (id, data) => axios.put(`${API_BASE}/currencies/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/currencies/${id}`)
    },

    // Accounting API
    accounting: {
        accounts: {
            list: () => axios.get(`${API_BASE}/accounting/accounts`),
            get: (id) => axios.get(`${API_BASE}/accounting/accounts/${id}`),
            create: (data) => axios.post(`${API_BASE}/accounting/accounts`, data),
            update: (id, data) => axios.put(`${API_BASE}/accounting/accounts/${id}`, data),
            delete: (id) => axios.delete(`${API_BASE}/accounting/accounts/${id}`)
        },
        entries: {
            list: () => axios.get(`${API_BASE}/accounting/entries`),
            get: (id) => axios.get(`${API_BASE}/accounting/entries/${id}`),
            create: (data) => axios.post(`${API_BASE}/accounting/entries`, data),
            update: (id, data) => axios.put(`${API_BASE}/accounting/entries/${id}`, data),
            delete: (id) => axios.delete(`${API_BASE}/accounting/entries/${id}`)
        }
    },

    // Stock API
    stock: {
        list: (params = {}) => axios.get(`${API_BASE}/stock`, { params }),
        byGoods: (goodsId) => axios.get(`${API_BASE}/stock/goods/${goodsId}`),
        byGoodsAndLocation: (goodsId, locationId) => axios.get(`${API_BASE}/stock/${goodsId}/locations/${locationId}`),
        summary: () => axios.get(`${API_BASE}/stock/summary`)
    },

    // Payroll API
    payroll: {
        employees: {
            list: () => axios.get(`${API_BASE}/payroll/employees`),
            get: (id) => axios.get(`${API_BASE}/payroll/employees/${id}`)
        },
        salaries: {
            list: () => axios.get(`${API_BASE}/payroll/salaries`),
            byEmployee: (empId) => axios.get(`${API_BASE}/payroll/salary/${empId}`)
        }
    },

    // Units API
    units: {
        list: () => axios.get(`${API_BASE}/units`)
    },

    // Dashboard API
    dashboard: {
        stats: () => axios.get(`${API_BASE}/dashboard`)
    },

    // Sales API
    sales: {
        summary: (days = 30, limit = 100) => axios.get(`${API_BASE}/sales/summary`, { params: { days, limit } })
    },

    // Reports API
    reports: {
        list: () => axios.get(`${API_BASE}/reports`),
        get: (id) => axios.get(`${API_BASE}/reports/${id}`),
        metadata: () => axios.get(`${API_BASE}/reports/metadata`),
        jrxml: (name) => axios.get(`${API_BASE}/reports/jrxml/${name}`),
        create: (data) => axios.post(`${API_BASE}/reports`, data)
    },

    // Jobs API
    jobs: {
        list: () => axios.get(`${API_BASE}/jobs`),
        pending: () => axios.get(`${API_BASE}/jobs/pending`),
        create: (data) => axios.post(`${API_BASE}/jobs`, data)
    },

    // Health API
    health: {
        check: () => axios.get(`${API_BASE}/health`),
        live: () => axios.get(`${API_BASE}/health/live`),
        ready: () => axios.get(`${API_BASE}/health/ready`)
    },

    // Document Types API
    documentTypes: {
        list: () => axios.get(`${API_BASE}/document-types`)
    },

    // Users API
    users: {
        list: () => axios.get(`${API_BASE}/users`)
    },

    // Roles API
    roles: {
        list: () => axios.get(`${API_BASE}/roles`)
    }
};

// Helper functions
const helpers = {
    formatDate: (date) => {
        if (!date) return '-';
        const d = new Date(date);
        return d.toLocaleDateString('ru-RU');
    },

    formatDateTime: (date) => {
        if (!date) return '-';
        const d = new Date(date);
        return d.toLocaleString('ru-RU');
    },

    formatMoney: (amount, currency = 'RUB') => {
        if (amount === null || amount === undefined) return '-';
        return new Intl.NumberFormat('ru-RU', {
            style: 'currency',
            currency: currency
        }).format(amount);
    },

    formatNumber: (num) => {
        if (num === null || num === undefined) return '-';
        return new Intl.NumberFormat('ru-RU').format(num);
    },

    truncate: (str, length = 50) => {
        if (!str) return '';
        return str.length > length ? str.substring(0, length) + '...' : str;
    },

    debounce: (func, wait) => {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    },

    // API error handler
    handleApiError: (error) => {
        if (error.response) {
            const { status, data } = error.response;
            switch (status) {
                case 401: return 'Unauthorized. Please login.';
                case 403: return 'Access denied.';
                case 404: return 'Resource not found.';
                case 429: return 'Rate limit exceeded. Please wait.';
                case 500: return 'Server error. Please try again.';
                default: return data?.error || `Error: ${status}`;
            }
        }
        return 'Network error. Please check your connection.';
    }
};

// Export for use in other files
window.api = api;
window.helpers = helpers;
