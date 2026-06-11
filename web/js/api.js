// Surypus - API Client with JWT auth

const API_BASE = window.location.origin + '/api/v1';

// JWT token management
let authToken = localStorage.getItem('surypus_token');
let authUser = JSON.parse(localStorage.getItem('surypus_user') || 'null');

// Axios interceptor: auto-attach token
axios.interceptors.request.use(function(config) {
    if (authToken) {
        config.headers.Authorization = 'Bearer ' + authToken;
    }
    return config;
});

// Axios interceptor: redirect on 401
axios.interceptors.response.use(
    function(response) { return response; },
    function(error) {
        if (error.response && error.response.status === 401 && !window.location.hash.includes('#login')) {
            clearAuth();
        }
        return Promise.reject(error);
    }
);

function login(username, password) {
    return axios.post(`${API_BASE}/login`, { lrUsername: username, lrPassword: password })
        .then(function(res) {
            authToken = res.data.lAccessToken;
            localStorage.setItem('surypus_token', authToken);
            var user = { id: res.data.lUserId, name: username };
            authUser = user;
            localStorage.setItem('surypus_user', JSON.stringify(user));
            return res;
        });
}

function register(username, password, email) {
    return axios.post(`${API_BASE}/register`, { rrUsername: username, rrPassword: password, rrEmail: email || null })
        .then(function(res) {
            authToken = res.data.lAccessToken;
            localStorage.setItem('surypus_token', authToken);
            var user = { id: res.data.lUserId, name: username };
            authUser = user;
            localStorage.setItem('surypus_user', JSON.stringify(user));
            return res;
        });
}

function clearAuth() {
    authToken = null;
    authUser = null;
    localStorage.removeItem('surypus_token');
    localStorage.removeItem('surypus_user');
}

function logout() {
    clearAuth();
    window.location.reload();
}

function isAuthenticated() {
    return authToken !== null;
}

const api = {
    // Auth API
    auth: {
        login: login,
        register: register,
        logout: logout,
        clearAuth: clearAuth,
        me: () => {
            if (!authToken) return Promise.reject(new Error('Not authenticated'));
            return axios.get(`${API_BASE}/auth/me`);
        },
        isAuthenticated: isAuthenticated,
        getUser: () => authUser
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

    // Bill Templates API
    billTemplates: {
        list: () => axios.get(`${API_BASE}/bill-templates`),
        save: (name, content) => axios.post(`${API_BASE}/bill-templates`, null, { params: { name, content } }),
        delete: (id) => axios.delete(`${API_BASE}/bill-templates/${id}`)
    },

    // Payment API
    payments: {
        list: () => axios.get(`${API_BASE}/payments`),
        get: (id) => axios.get(`${API_BASE}/payments/${id}`),
        create: (data) => axios.post(`${API_BASE}/payments`, data),
        update: (id, data) => axios.put(`${API_BASE}/payments/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/payments/${id}`),
        aging: () => axios.get(`${API_BASE}/payments/aging`)
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
        balance: (params = {}) => axios.get(`${API_BASE}/balance`, { params }),
        entries: {
            list: (params = {}) => axios.get(`${API_BASE}/accounting/entries`, { params }),
            create: (data) => axios.post(`${API_BASE}/accounting/entries`, data)
        },
        generalLedger: (params = {}) => axios.get(`${API_BASE}/accounting/entries`, { params }),
        balanceHistory: (params = {}) => axios.get(`${API_BASE}/accounting/balance-history`, { params })
    },

    // Stock API
    stock: {
        list: (params = {}) => axios.get(`${API_BASE}/stock`, { params }),
        byGoods: (goodsId) => axios.get(`${API_BASE}/stock/goods/${goodsId}`),
        byGoodsAndLocation: (goodsId, locationId) => axios.get(`${API_BASE}/stock/${goodsId}/locations/${locationId}`),
        summary: () => axios.get(`${API_BASE}/stock/summary`),
        valuation: () => axios.get(`${API_BASE}/stock/valuation`),
        movements: {
            list: (params = {}) => axios.get(`${API_BASE}/stock/movements`, { params }),
            byGoods: (goodsId) => axios.get(`${API_BASE}/stock/movements/goods/${goodsId}`)
        },
        createMovement: (data) => axios.post(`${API_BASE}/stock/movements`, data)
    },

    // Lots API
    lots: {
        list: () => axios.get(`${API_BASE}/lots`),
        get: (id) => axios.get(`${API_BASE}/lots/${id}`),
        byGoods: (goodsId) => axios.get(`${API_BASE}/lots/goods/${goodsId}`),
        byLocation: (locationId) => axios.get(`${API_BASE}/lots/location/${locationId}`)
    },

    // Tenants API
    tenants: {
        list: () => axios.get(`${API_BASE}/tenants`),
        get: (id) => axios.get(`${API_BASE}/tenants/${id}`),
        create: (data) => axios.post(`${API_BASE}/tenants`, data)
    },

    // Payroll API
    payroll: {
        employees: {
            list: () => axios.get(`${API_BASE}/payroll/employees`),
            get: (id) => axios.get(`${API_BASE}/payroll/employees/${id}`),
            create: (data) => axios.post(`${API_BASE}/payroll/employees`, data),
            update: (id, data) => axios.put(`${API_BASE}/payroll/employees/${id}`, data),
            delete: (id) => axios.delete(`${API_BASE}/payroll/employees/${id}`)
        },
        salaries: {
            list: () => axios.get(`${API_BASE}/payroll/salaries`),
            byEmployee: (empId) => axios.get(`${API_BASE}/payroll/salary/${empId}`),
            create: (data) => axios.post(`${API_BASE}/payroll/salaries`, data),
            delete: (id) => axios.delete(`${API_BASE}/payroll/salaries/${id}`)
        },
        calculate: (data) => axios.post(`${API_BASE}/payroll/calculate`, data),
        calculateAndSave: (data) => axios.post(`${API_BASE}/payroll/calculate-and-save`, data),
        results: {
            list: () => axios.get(`${API_BASE}/payroll/results`),
            byEmployee: (empId) => axios.get(`${API_BASE}/payroll/results/${empId}`)
        }
    },
    timesheets: {
        list: () => axios.get(`${API_BASE}/timesheets`),
        create: (data) => axios.post(`${API_BASE}/timesheets`, data),
        update: (id, data) => axios.put(`${API_BASE}/timesheets/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/timesheets/${id}`)
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
        create: (data) => axios.post(`${API_BASE}/reports`, data),
        export: (data) => axios.post(`${API_BASE}/reports/export`, data),
        pnl: () => axios.get(`${API_BASE}/reports/pnl`),
        inventory: () => axios.get(`${API_BASE}/reports/inventory`)
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

    // Backup API
    backup: {
        create: () => axios.get(`${API_BASE}/backup`)
    },

    // Document Types API
    documentTypes: {
        list: () => axios.get(`${API_BASE}/document-types`)
    },

    // Users API
    users: {
        list: () => axios.get(`${API_BASE}/users`),
        delete: (id) => axios.delete(`${API_BASE}/users/${id}`)
    },

    // Roles API
    roles: {
        list: () => axios.get(`${API_BASE}/roles`),
        get: (id) => axios.get(`${API_BASE}/roles/${id}`),
        create: (data) => axios.post(`${API_BASE}/roles`, data),
        update: (id, data) => axios.put(`${API_BASE}/roles/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/roles/${id}`)
    },
    permissions: {
        list: () => axios.get(`${API_BASE}/permissions`)
    },
    auditLog: {
        list: (params) => axios.get(`${API_BASE}/audit-log`, { params })
    },

    // CRM API
    crm: {
        deals: {
            list: () => axios.get(`${API_BASE}/crm/deals`),
            get: (id) => axios.get(`${API_BASE}/crm/deals/${id}`),
            create: (data) => axios.post(`${API_BASE}/crm/deals`, data),
            updateStage: (id, stageId) => axios.post(`${API_BASE}/crm/deals/${id}/stage/${stageId}`),
            history: (id) => axios.get(`${API_BASE}/crm/deals/${id}/history`),
            activities: (id) => axios.get(`${API_BASE}/crm/deals/${id}/activities`)
        },
        contacts: {
            list: () => axios.get(`${API_BASE}/crm/contacts`),
            get: (id) => axios.get(`${API_BASE}/crm/contacts/${id}`),
            create: (data) => axios.post(`${API_BASE}/crm/contacts`, data),
            update: (id, data) => axios.put(`${API_BASE}/crm/contacts/${id}`, data),
            delete: (id) => axios.post(`${API_BASE}/crm/contacts/${id}/delete`),
            search: (q) => axios.get(`${API_BASE}/crm/contacts/search/${q}`)
        },
        companies: {
            list: () => axios.get(`${API_BASE}/crm/companies`),
            get: (id) => axios.get(`${API_BASE}/crm/companies/${id}`),
            create: (data) => axios.post(`${API_BASE}/crm/companies`, data),
            update: (id, data) => axios.put(`${API_BASE}/crm/companies/${id}`, data),
            delete: (id) => axios.post(`${API_BASE}/crm/companies/${id}/delete`),
            search: (q) => axios.get(`${API_BASE}/crm/companies/search/${q}`)
        },
        pipeline: {
            forecast: () => axios.get(`${API_BASE}/crm/pipeline`),
            stages: () => axios.get(`${API_BASE}/crm/pipeline/stages`),
            stageRules: (id) => axios.get(`${API_BASE}/crm/pipeline/stages/${id}/rules`),
            refreshForecast: () => axios.post(`${API_BASE}/crm/pipeline/forecast/refresh`)
        }
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

    escapeHtml: (str) => {
        if (!str) return '';
        return String(str).replace(/[&<>"']/g, function(m) {
            return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[m] || m;
        });
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
