// Surypus - API Client

const API_BASE = window.location.origin + '/api/v1';

const api = {
    // Goods API
    goods: {
        list: (params = {}) => axios.get(`${API_BASE}/goods`, { params }),
        get: (id) => axios.get(`${API_BASE}/goods/${id}`),
        create: (data) => axios.post(`${API_BASE}/goods`, data),
        update: (id, data) => axios.put(`${API_BASE}/goods/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/goods/${id}`),
        searchByBarcode: (code) => axios.get(`${API_BASE}/goods/barcode/${code}`)
    },

    // Person API
    persons: {
        list: (params = {}) => axios.get(`${API_BASE}/persons`, { params }),
        get: (id) => axios.get(`${API_BASE}/persons/${id}`),
        create: (data) => axios.post(`${API_BASE}/persons`, data),
        update: (id, data) => axios.put(`${API_BASE}/persons/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/persons/${id}`)
    },

    // Bill API
    bills: {
        list: (params = {}) => axios.get(`${API_BASE}/bills`, { params }),
        get: (id) => axios.get(`${API_BASE}/bills/${id}`),
        create: (data) => axios.post(`${API_BASE}/bills`, data),
        update: (id, data) => axios.put(`${API_BASE}/bills/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/bills/${id}`)
    },

    // Location API
    locations: {
        list: (params = {}) => axios.get(`${API_BASE}/locations`, { params }),
        get: (id) => axios.get(`${API_BASE}/locations/${id}`),
        create: (data) => axios.post(`${API_BASE}/locations`, data),
        update: (id, data) => axios.put(`${API_BASE}/locations/${id}`, data),
        delete: (id) => axios.delete(`${API_BASE}/locations/${id}`)
    },

    // Finance API
    finance: {
        currencies: {
            list: () => axios.get(`${API_BASE}/finance/currencies`),
            get: (id) => axios.get(`${API_BASE}/finance/currencies/${id}`),
            create: (data) => axios.post(`${API_BASE}/finance/currencies`, data),
            update: (id, data) => axios.put(`${API_BASE}/finance/currencies/${id}`, data)
        },
        accounts: {
            list: () => axios.get(`${API_BASE}/finance/accounts`),
            get: (id) => axios.get(`${API_BASE}/finance/accounts/${id}`),
            balance: (id, date) => axios.get(`${API_BASE}/finance/accounts/${id}/balance`, { params: { date } })
        },
        transactions: {
            list: (params = {}) => axios.get(`${API_BASE}/finance/transactions`, { params }),
            get: (id) => axios.get(`${API_BASE}/finance/transactions/${id}`),
            create: (data) => axios.post(`${API_BASE}/finance/transactions`, data)
        },
        cashflow: {
            get: (locId, startDate, endDate) => axios.get(`${API_BASE}/finance/cashflow`, { 
                params: { loc_id: locId, start_dt: startDate, end_dt: endDate } 
            })
        }
    },

    // Inventory API
    inventory: {
        stock: {
            list: (params = {}) => axios.get(`${API_BASE}/inventory/stock`, { params }),
            get: (goodsId, locId) => axios.get(`${API_BASE}/inventory/stock/${goodsId}/${locId}`)
        },
        lots: {
            list: (goodsId) => axios.get(`${API_BASE}/inventory/lots`, { params: { goods_id: goodsId } })
        },
        movements: {
            list: (params = {}) => axios.get(`${API_BASE}/inventory/movements`, { params })
        }
    },

    // Reports API
    reports: {
        generate: (template, format, params) => axios.post(`${API_BASE}/reports/generate`, {
            template, format, params
        }, { responseType: 'blob' }),
        list: () => axios.get(`${API_BASE}/reports`)
    },

    // Device API
    devices: {
        list: (params = {}) => axios.get(`${API_BASE}/devices`, { params }),
        get: (id) => axios.get(`${API_BASE}/devices/${id}`),
        status: (id) => axios.get(`${API_BASE}/devices/${id}/status`),
        command: (id, cmd) => axios.post(`${API_BASE}/devices/${id}/command`, cmd)
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

    formatMoney: (amount, currency = '₽') => {
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
    }
};

// Export for use in other files
window.api = api;
window.helpers = helpers;
