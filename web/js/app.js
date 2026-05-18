// Surypus - Main Application

class App {
    constructor() {
        this.currentPage = 'dashboard';
        this.modal = null;
        this.toast = null;
        
        this.init();
    }

    init() {
        // Initialize Bootstrap components
        this.modal = new bootstrap.Modal(document.getElementById('modal'));
        this.toast = new bootstrap.Toast(document.getElementById('toast'));
        
        // Setup navigation
        this.setupNavigation();
        
        // Load default page
        this.loadPage('dashboard');
        
        console.log('Surypus initialized');
    }

    setupNavigation() {
        // Handle nav links
        document.querySelectorAll('[data-page]').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const page = e.target.closest('[data-page]').dataset.page;
                this.loadPage(page);
            });
        });
    }

    async loadPage(pageName) {
        this.currentPage = pageName;
        
        // Update active nav
        document.querySelectorAll('[data-page]').forEach(link => {
            link.classList.remove('active');
            if (link.dataset.page === pageName) {
                link.classList.add('active');
            }
        });
        
        // Load page content
        const content = document.getElementById('content');
        content.innerHTML = this.getLoadingHTML();
        
        try {
            const pageContent = await this.renderPage(pageName);
            content.innerHTML = pageContent;
            this.initPageScripts(pageName);
        } catch (error) {
            content.innerHTML = this.getErrorHTML(error.message);
        }
    }

    async renderPage(pageName) {
        switch(pageName) {
            case 'dashboard':
                return this.renderDashboard();
            case 'goods-list':
                return this.renderGoodsList();
            case 'persons-list':
                return this.renderPersonsList();
            case 'bills-list':
                return this.renderBillsList();
            case 'locations':
                return this.renderLocations();
            case 'cashflow':
                return this.renderCashflow();
            case 'stock':
                return this.renderStock();
            case 'inventory':
                return this.renderInventory();
            default:
                return this.renderPlaceholder(pageName);
        }
    }

    // ==================== Dashboard ====================
    async renderDashboard() {
        const app = this;
        const container = document.createElement('div');
        container.innerHTML = `
            <h1 class="h3 mb-4">Главная панель</h1>
            <div id="dashboardLoading" class="text-center py-5">
                <div class="spinner-border" role="status"></div>
                <p class="mt-2">Загрузка данных...</p>
            </div>
            <div id="dashboardContent" style="display:none">
                <div class="dashboard-stats" id="kpiCards"></div>
                <div class="row">
                    <div class="col-md-6">
                        <div class="card">
                            <div class="card-header"><i class="bi bi-graph-up"></i> Выручка по месяцам</div>
                            <div class="card-body"><canvas id="revenueChart"></canvas></div>
                        </div>
                    </div>
                    <div class="col-md-6">
                        <div class="card">
                            <div class="card-header"><i class="bi bi-pie-chart"></i> Статусы заказов</div>
                            <div class="card-body"><canvas id="ordersChart"></canvas></div>
                        </div>
                    </div>
                </div>
                <div class="row mt-3">
                    <div class="col-12">
                        <div class="card">
                            <div class="card-header"><i class="bi bi-bar-chart"></i> Остатки по категориям</div>
                            <div class="card-body"><canvas id="stockChart"></canvas></div>
                        </div>
                    </div>
                </div>
            </div>
            <div id="dashboardError" style="display:none" class="alert alert-danger"></div>
        `;

        setTimeout(() => this.loadDashboardData(container), 0);
        return container.innerHTML;
    }

    async loadDashboardData(container) {
        try {
            const [kpi, revenue, orders] = await Promise.all([
                api.dashboard.stats(),
                axios.get('/api/v1/dashboard/revenue'),
                axios.get('/api/v1/dashboard/orders')
            ]);

            document.getElementById('dashboardLoading').style.display = 'none';
            document.getElementById('dashboardContent').style.display = 'block';

            this.renderKPICards(kpi.data);
            this.renderRevenueChart(revenue.data);
            this.renderOrdersChart(orders.data);
        } catch (err) {
            document.getElementById('dashboardLoading').style.display = 'none';
            const errEl = document.getElementById('dashboardError');
            errEl.style.display = 'block';
            errEl.textContent = 'Ошибка загрузки: ' + (err.message || 'неизвестная ошибка');
        }
    }

    renderKPICards(kpi) {
        const cards = [
            { label: 'Выручка', value: helpers.formatMoney(kpi.kpiRevenue || 0), cls: '' },
            { label: 'Заказы', value: (kpi.kpiOrders || 0).toLocaleString(), cls: 'success' },
            { label: 'Товаров', value: (kpi.kpiActiveGoods || 0).toLocaleString(), cls: 'warning' },
            { label: 'Контрагентов', value: (kpi.kpiPartners || 0).toLocaleString(), cls: 'info' }
        ];
        document.getElementById('kpiCards').innerHTML = cards.map(c =>
            `<div class="stat-card ${c.cls}"><div class="stat-value">${c.value}</div><div class="stat-label">${c.label}</div></div>`
        ).join('');
    }

    renderRevenueChart(data) {
        const canvas = document.getElementById('revenueChart');
        if (!canvas || !data || !data.length) return;
        new Chart(canvas, {
            type: 'line',
            data: {
                labels: data.map(d => d.rpMonth),
                datasets: [{
                    label: 'Выручка',
                    data: data.map(d => d.rpRevenue),
                    borderColor: '#0d6efd',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: { responsive: true, plugins: { legend: { display: false } } }
        });
    }

    renderOrdersChart(data) {
        const canvas = document.getElementById('ordersChart');
        if (!canvas || !data || !data.length) return;
        new Chart(canvas, {
            type: 'doughnut',
            data: {
                labels: data.map(d => d.osStatus),
                datasets: [{
                    data: data.map(d => d.osCount),
                    backgroundColor: ['#198754', '#ffc107', '#dc3545', '#0d6efd', '#6f42c1']
                }]
            },
            options: { responsive: true, plugins: { legend: { position: 'bottom' } } }
        });
    }

    // ==================== Goods ====================
    async renderGoodsList() {
        return `
            <div class="d-flex justify-content-between align-items-center mb-4">
                <h1 class="h3">Товары</h1>
                <button class="btn btn-primary" onclick="app.showGoodsForm()">
                    <i class="bi bi-plus-lg"></i> Добавить товар
                </button>
            </div>
            
            <div class="card">
                <div class="card-body">
                    <div class="row mb-3">
                        <div class="col-md-4">
                            <div class="search-box">
                                <i class="bi bi-search"></i>
                                <input type="text" class="form-control" placeholder="Поиск по наименованию..." id="goodsSearch">
                            </div>
                        </div>
                        <div class="col-md-3">
                            <select class="form-select" id="goodsGroupFilter">
                                <option value="">Все группы</option>
                                <option value="1">Электроника</option>
                                <option value="2">Продукты</option>
                                <option value="3">Канцтовары</option>
                            </select>
                        </div>
                        <div class="col-md-2">
                            <button class="btn btn-outline-primary w-100" onclick="app.searchGoods()">
                                <i class="bi bi-search"></i> Найти
                            </button>
                        </div>
                    </div>
                    
                    <div class="table-responsive">
                        <table class="table table-hover" id="goodsTable">
                            <thead>
                                <tr>
                                    <th>Код</th>
                                    <th>Наименование</th>
                                    <th>Группа</th>
                                    <th>Остаток</th>
                                    <th>Цена</th>
                                    <th>Штрихкод</th>
                                    <th>Действия</th>
                                </tr>
                            </thead>
                            <tbody id="goodsTableBody">
                                ${this.getLoadingRowHTML()}
                            </tbody>
                        </table>
                    </div>
                    
                    <nav>
                        <ul class="pagination justify-content-end">
                            <li class="page-item disabled">
                                <a class="page-link" href="#">Предыдущая</a>
                            </li>
                            <li class="page-item active">
                                <a class="page-link" href="#">1</a>
                            </li>
                            <li class="page-item">
                                <a class="page-link" href="#">2</a>
                            </li>
                            <li class="page-item">
                                <a class="page-link" href="#">Следующая</a>
                            </li>
                        </ul>
                    </nav>
                </div>
            </div>
        `;
    }

    async searchGoods() {
        const searchTerm = document.getElementById('goodsSearch').value;
        const tbody = document.getElementById('goodsTableBody');
        
        try {
            const response = await api.goods.list({ search: searchTerm });
            tbody.innerHTML = this.renderGoodsRows(response.data.data || []);
        } catch (error) {
            this.showError('Ошибка поиска: ' + error.message);
        }
    }

    renderGoodsRows(goods) {
        if (goods.length === 0) {
            return '<tr><td colspan="7" class="text-center">Товары не найдены</td></tr>';
        }
        
        return goods.map(g => `
            <tr>
                <td>${g.goodsCode || '-'}</td>
                <td>${g.goodsName?.unName256 || '-'}</td>
                <td>-</td>
                <td>-</td>
                <td>-</td>
                <td>${g.goodsBarcode || '-'}</td>
                <td>
                    <button class="btn btn-sm btn-outline-primary" onclick="app.editGoods(${g.goodsId})">
                        <i class="bi bi-pencil"></i>
                    </button>
                    <button class="btn btn-sm btn-outline-danger" onclick="app.deleteGoods(${g.goodsId})">
                        <i class="bi bi-trash"></i>
                    </button>
                </td>
            </tr>
        `).join('');
    }

    showGoodsForm(id = null) {
        const title = id ? 'Редактирование товара' : 'Новый товар';
        document.getElementById('modalTitle').textContent = title;
        document.getElementById('modalBody').innerHTML = `
            <form id="goodsForm">
                <div class="row">
                    <div class="col-md-6">
                        <div class="mb-3">
                            <label class="form-label">Наименование *</label>
                            <input type="text" class="form-control" name="name" required>
                        </div>
                    </div>
                    <div class="col-md-6">
                        <div class="mb-3">
                            <label class="form-label">Артикул</label>
                            <input type="text" class="form-control" name="code">
                        </div>
                    </div>
                </div>
                <div class="row">
                    <div class="col-md-6">
                        <div class="mb-3">
                            <label class="form-label">Группа</label>
                            <select class="form-select" name="parentId">
                                <option value="">Выберите группу</option>
                            </select>
                        </div>
                    </div>
                    <div class="col-md-6">
                        <div class="mb-3">
                            <label class="form-label">Штрихкод</label>
                            <input type="text" class="form-control" name="barcode">
                        </div>
                    </div>
                </div>
                <div class="row">
                    <div class="col-md-4">
                        <div class="mb-3">
                            <label class="form-label">Цена</label>
                            <input type="number" class="form-control" name="price" step="0.01">
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="mb-3">
                            <label class="form-label">Единица измерения</label>
                            <select class="form-select" name="unitId">
                                <option value="1">шт</option>
                                <option value="2">кг</option>
                                <option value="3">л</option>
                            </select>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="mb-3">
                            <label class="form-label">Ставка НДС</label>
                            <select class="form-select" name="taxGroupId">
                                <option value="0">Без НДС</option>
                                <option value="1">10%</option>
                                <option value="2">20%</option>
                            </select>
                        </div>
                    </div>
                </div>
            </form>
        `;
        
        document.getElementById('modalSave').onclick = () => this.saveGoods(id);
        this.modal.show();
    }

    async saveGoods(id) {
        const form = document.getElementById('goodsForm');
        if (!form.checkValidity()) {
            form.reportValidity();
            return;
        }
        
        const formData = new FormData(form);
        const data = Object.fromEntries(formData);
        
        try {
            if (id) {
                await api.goods.update(id, data);
            } else {
                await api.goods.create(data);
            }
            this.modal.hide();
            this.showSuccess('Товар сохранён');
            this.loadPage('goods-list');
        } catch (error) {
            this.showError('Ошибка сохранения: ' + error.message);
        }
    }

    // ==================== Persons ====================
    async renderPersonsList() {
        return `
            <div class="d-flex justify-content-between align-items-center mb-4">
                <h1 class="h3">Контрагенты</h1>
                <button class="btn btn-primary" onclick="app.showPersonForm()">
                    <i class="bi bi-plus-lg"></i> Добавить контрагента
                </button>
            </div>
            
            <div class="card">
                <div class="card-body">
                    <div class="row mb-3">
                        <div class="col-md-4">
                            <div class="search-box">
                                <i class="bi bi-search"></i>
                                <input type="text" class="form-control" placeholder="Поиск..." id="personSearch">
                            </div>
                        </div>
                        <div class="col-md-3">
                            <select class="form-select" id="personKindFilter">
                                <option value="">Все виды</option>
                                <option value="1">Поставщики</option>
                                <option value="2">Покупатели</option>
                                <option value="3">Сотрудники</option>
                            </select>
                        </div>
                    </div>
                    
                    <div class="table-responsive">
                        <table class="table table-hover">
                            <thead>
                                <tr>
                                    <th>Наименование</th>
                                    <th>Вид</th>
                                    <th>Телефон</th>
                                    <th>Email</th>
                                    <th>ИНН</th>
                                    <th>Действия</th>
                                </tr>
                            </thead>
                            <tbody id="personsTableBody">
                                <tr>
                                    <td>ООО "Поставщик"</td>
                                    <td>Поставщик</td>
                                    <td>+7 495 123-45-67</td>
                                    <td>info@supplier.ru</td>
                                    <td>1234567890</td>
                                    <td>
                                        <button class="btn btn-sm btn-outline-primary"><i class="bi bi-pencil"></i></button>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        `;
    }

    showPersonForm() {
        document.getElementById('modalTitle').textContent = 'Новый контрагент';
        document.getElementById('modalBody').innerHTML = `
            <form id="personForm">
                <div class="mb-3">
                    <label class="form-label">Наименование *</label>
                    <input type="text" class="form-control" name="name" required>
                </div>
                <div class="mb-3">
                    <label class="form-label">Вид контрагента</label>
                    <select class="form-select" name="kind">
                        <option value="1">Поставщик</option>
                        <option value="2">Покупатель</option>
                        <option value="3">Сотрудник</option>
                    </select>
                </div>
                <div class="mb-3">
                    <label class="form-label">Телефон</label>
                    <input type="text" class="form-control" name="phone">
                </div>
                <div class="mb-3">
                    <label class="form-label">Email</label>
                    <input type="email" class="form-control" name="email">
                </div>
                <div class="mb-3">
                    <label class="form-label">ИНН</label>
                    <input type="text" class="form-control" name="inn">
                </div>
                <div class="mb-3">
                    <label class="form-label">КПП</label>
                    <input type="text" class="form-control" name="kpp">
                </div>
                <div class="mb-3">
                    <label class="form-label">Адрес</label>
                    <textarea class="form-control" name="address" rows="2"></textarea>
                </div>
            </form>
        `;
        
        document.getElementById('modalSave').onclick = () => this.savePerson();
        this.modal.show();
    }

    // ==================== Bills ====================
    async renderBillsList() {
        return `
            <div class="d-flex justify-content-between align-items-center mb-4">
                <h1 class="h3">Документы</h1>
                <div>
                    <button class="btn btn-success" onclick="app.showBillForm('receipt')">
                        <i class="bi bi-plus-lg"></i> Приход
                    </button>
                    <button class="btn btn-danger" onclick="app.showBillForm('issue')">
                        <i class="bi bi-plus-lg"></i> Расход
                    </button>
                </div>
            </div>
            
            <div class="card">
                <div class="card-header">
                    <ul class="nav nav-tabs card-header-tabs">
                        <li class="nav-item">
                            <a class="nav-link active" href="#">Все</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="#">Приходы</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="#">Расходы</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="#">Оплаты</a>
                        </li>
                    </ul>
                </div>
                <div class="card-body">
                    <div class="row mb-3">
                        <div class="col-md-3">
                            <input type="date" class="form-control" id="billDateFrom" value="${helpers.formatDate(new Date()).split('.')[2]}-01-01">
                        </div>
                        <div class="col-md-3">
                            <input type="date" class="form-control" id="billDateTo" value="${helpers.formatDate(new Date())}">
                        </div>
                        <div class="col-md-3">
                            <select class="form-select" id="billOpFilter">
                                <option value="">Все операции</option>
                                <option value="1">Приход товара</option>
                                <option value="2">Расход товара</option>
                                <option value="9">Оплата</option>
                            </select>
                        </div>
                    </div>
                    
                    <div class="table-responsive">
                        <table class="table table-hover">
                            <thead>
                                <tr>
                                    <th>Дата</th>
                                    <th>№</th>
                                    <th>Операция</th>
                                    <th>Контрагент</th>
                                    <th>Склад</th>
                                    <th>Сумма</th>
                                    <th>Оплата</th>
                                    <th>Статус</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr>
                                    <td>${helpers.formatDate(new Date())}</td>
                                    <td>001234</td>
                                    <td>Приход товара</td>
                                    <td>ООО "Поставщик"</td>
                                    <td>Основной склад</td>
                                    <td>${helpers.formatMoney(50000)}</td>
                                    <td>${helpers.formatMoney(50000)}</td>
                                    <td><span class="badge bg-success">Проведён</span></td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        `;
    }

    // ==================== Locations ====================
    async renderLocations() {
        return `
            <div class="d-flex justify-content-between align-items-center mb-4">
                <h1 class="h3">Склады</h1>
                <button class="btn btn-primary" onclick="app.showLocationForm()">
                    <i class="bi bi-plus-lg"></i> Добавить склад
                </button>
            </div>
            
            <div class="row">
                <div class="col-md-4">
                    <div class="card">
                        <div class="card-body">
                            <h5 class="card-title">Основной склад</h5>
                            <p class="card-text text-muted">
                                <i class="bi bi-geo-alt"></i> г. Москва, ул. Примерная, 1<br>
                                <i class="bi bi-telephone"></i> +7 495 123-45-67
                            </p>
                            <span class="badge bg-success">Активен</span>
                        </div>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="card">
                        <div class="card-body">
                            <h5 class="card-title">Склад 2</h5>
                            <p class="card-text text-muted">
                                <i class="bi bi-geo-alt"></i> г. Санкт-Петербург<br>
                                <i class="bi bi-telephone"></i> +7 812 987-65-43
                            </p>
                            <span class="badge bg-success">Активен</span>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    // ==================== Cash Flow ====================
    async renderCashflow() {
        return `
            <h1 class="h3 mb-4">Денежный поток</h1>
            
            <div class="row mb-4">
                <div class="col-md-12">
                    <div class="card">
                        <div class="card-body">
                            <div class="row">
                                <div class="col-md-3">
                                    <label class="form-label">Дата с</label>
                                    <input type="date" class="form-control" id="cfDateFrom" value="${helpers.formatDate(new Date()).split('.')[2]}-01-01">
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">Дата по</label>
                                    <input type="date" class="form-control" id="cfDateTo" value="${helpers.formatDate(new Date())}">
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">Склад</label>
                                    <select class="form-select" id="cfLocFilter">
                                        <option value="">Все склады</option>
                                        <option value="1">Основной склад</option>
                                    </select>
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">&nbsp;</label>
                                    <button class="btn btn-primary w-100" onclick="app.loadCashFlow()">
                                        <i class="bi bi-search"></i> Показать
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="row">
                <div class="col-md-12">
                    <div class="card">
                        <div class="card-header">Движение денежных средств</div>
                        <div class="card-body">
                            <div class="table-responsive">
                                <table class="table table-hover">
                                    <thead>
                                        <tr>
                                            <th>Дата</th>
                                            <th>Приход</th>
                                            <th>Расход</th>
                                            <th>Остаток</th>
                                        </tr>
                                    </thead>
                                    <tbody id="cashflowTable">
                                        <tr>
                                            <td>${helpers.formatDate(new Date())}</td>
                                            <td class="text-success">${helpers.formatMoney(50000)}</td>
                                            <td class="text-danger">${helpers.formatMoney(30000)}</td>
                                            <td>${helpers.formatMoney(200000)}</td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    // ==================== Stock ====================
    async renderStock() {
        return `
            <h1 class="h3 mb-4">Остатки на складе</h1>
            
            <div class="card">
                <div class="card-body">
                    <div class="row mb-3">
                        <div class="col-md-4">
                            <input type="text" class="form-control" placeholder="Поиск по товару...">
                        </div>
                        <div class="col-md-3">
                            <select class="form-select">
                                <option value="">Все склады</option>
                                <option value="1">Основной склад</option>
                            </select>
                        </div>
                        <div class="col-md-2">
                            <button class="btn btn-outline-primary w-100">Найти</button>
                        </div>
                    </div>
                    
                    <div class="table-responsive">
                        <table class="table table-hover">
                            <thead>
                                <tr>
                                    <th>Товар</th>
                                    <th>Код</th>
                                    <th>Остаток</th>
                                    <th>Цена</th>
                                    <th>Стоимость</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr>
                                    <td>Товар А</td>
                                    <td>001</td>
                                    <td>100 шт</td>
                                    <td>${helpers.formatMoney(500)}</td>
                                    <td>${helpers.formatMoney(50000)}</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        `;
    }

    // ==================== Inventory ====================
    async renderInventory() {
        return `
            <div class="d-flex justify-content-between align-items-center mb-4">
                <h1 class="h3">Инвентаризация</h1>
                <button class="btn btn-primary">
                    <i class="bi bi-plus-lg"></i> Новая инвентаризация
                </button>
            </div>
            
            <div class="card">
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-hover">
                            <thead>
                                <tr>
                                    <th>Дата</th>
                                    <th>Склад</th>
                                    <th>Статус</th>
                                    <th>Товаров</th>
                                    <th>Отклонение</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr>
                                    <td>${helpers.formatDate(new Date())}</td>
                                    <td>Основной склад</td>
                                    <td><span class="badge bg-warning">В процессе</span></td>
                                    <td>150</td>
                                    <td class="text-warning">-2 500 ₽</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        `;
    }

    // ==================== Placeholder ====================
    renderPlaceholder(pageName) {
        return `
            <div class="text-center py-5">
                <i class="bi bi-gear" style="font-size: 64px; color: #ccc;"></i>
                <h3 class="mt-3">Страница "${pageName}"</h3>
                <p class="text-muted">Раздел в разработке</p>
            </div>
        `;
    }

    // ==================== Helpers ====================
    initPageScripts(pageName) {
        // Initialize any page-specific scripts
        if (pageName === 'goods-list') {
            this.loadGoods();
        }
    }

    async loadGoods() {
        const tbody = document.getElementById('goodsTableBody');
        if (!tbody) return;
        
        try {
            const response = await api.goods.list();
            tbody.innerHTML = this.renderGoodsRows(response.data.data || []);
        } catch (error) {
            tbody.innerHTML = `<tr><td colspan="7" class="text-danger">Ошибка загрузки: ${error.message}</td></tr>`;
        }
    }

    // ==================== UI Helpers ====================
    getLoadingHTML() {
        return `
            <div class="loading">
                <div class="spinner"></div>
            </div>
        `;
    }

    getLoadingRowHTML() {
        return '<tr><td colspan="7" class="text-center"><div class="spinner-border spinner-border-sm"></div> Загрузка...</td></tr>';
    }

    getErrorHTML(message) {
        return `
            <div class="alert alert-danger">
                <i class="bi bi-exclamation-triangle"></i> Ошибка: ${message}
            </div>
        `;
    }

    showSuccess(message) {
        document.getElementById('toastTitle').textContent = 'Успех';
        document.getElementById('toastBody').textContent = message;
        document.getElementById('toast').classList.remove('bg-danger');
        document.getElementById('toast').classList.add('bg-success');
        this.toast.show();
    }

    showError(message) {
        document.getElementById('toastTitle').textContent = 'Ошибка';
        document.getElementById('toastBody').textContent = message;
        document.getElementById('toast').classList.remove('bg-success');
        document.getElementById('toast').classList.add('bg-danger');
        this.toast.show();
    }
}

// Initialize app
const app = new App();
