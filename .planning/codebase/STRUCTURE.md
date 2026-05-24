# Codebase Structure

**Analysis Date:** 2026-05-24

## Directory Layout

```
/ (project root)
├── stack.yaml                              # Stack resolver LTS-22.21 (GHC 9.6.5)
├── Surypus.cabal                           # Main library package (220 modules exposed)
├── config.yaml                             # Dolt SQL server config (port 34789)
├── AGENTS.md                               # Agent instructions (bd issue tracking)
│
├── surypus-common/                         # Shared types & Servant API definitions
│   ├── surypus-common.cabal
│   └── src/Surypus/
│       ├── Types.hs                        # Re-export module
│       ├── Api.hs                          # Servant API type definitions
│       ├── Codecs.hs                       # JSON codecs
│       └── Types/                          # Domain-specific types (Bill, Person, Goods, etc.)
│           ├── Auth.hs
│           ├── Bill.hs
│           ├── Common.hs
│           ├── Goods.hs
│           ├── Legacy.hs
│           ├── Payment.hs
│           ├── Person.hs
│           └── Stock.hs
│
├── surypus-api/                            # REST API Backend package
│   ├── surypus-api.cabal
│   ├── app/Main.hs                         # Production entry point (Warp port 3000)
│   ├── src/Main.hs                         # Alternative entry point
│   ├── test/                               # API tests
│   └── src/Surypus/
│       ├── API/                            # Servant route handlers
│       │   ├── Server.hs                   # Main Servant server (apiServer function)
│       │   ├── Auth.hs                     # Auth endpoints
│       │   ├── Dashboard.hs               # Dashboard endpoints
│       │   ├── CRM.hs                     # CRM endpoints
│       │   ├── Persons.hs                 # Person endpoints
│       │   ├── Goods.hs                   # Goods endpoints
│       │   ├── Bills.hs                   # Bill endpoints
│       │   ├── Orders.hs                  # Orders endpoints
│       │   ├── Payment.hs                 # Payment endpoints
│       │   ├── Classifiers.hs             # Russian classifier endpoints
│       │   ├── Reports.hs                 # Reports endpoints
│       │   ├── Workflow.hs                # Workflow endpoints
│       │   ├── Notifications.hs           # Notification endpoints
│       │   ├── Integrations.hs            # Integration endpoints
│       │   ├── AI.hs                      # AI endpoints
│       │   ├── Logger.hs                  # Request logging
│       │   ├── GraphQL.hs                 # GraphQL proxy
│       │   ├── Production.hs              # Production endpoints
│       │   └── Bridge/AuthBridge.hs       # Auth bridge to shared types
│       ├── DAL/                            # API-specific data access
│       │   ├── Queries.hs                 # Database queries
│       │   ├── Mutations.hs               # Database mutations
│       │   ├── Repository.hs              # Repository pattern
│       │   ├── Database.hs                # Database access
│       │   └── Classifiers.hs             # Classifier queries
│       ├── JWT/Token.hs                    # JWT token handling
│       ├── PDF.hs                          # PDF generation
│       └── AI/
│           ├── OpenAI.hs                   # OpenAI integration
│           └── Anthropic.hs                # Anthropic integration
│
├── surypus-api-core/                       # Core API surface re-export
│   ├── surypus-api-core.cabal
│   └── src/Surypus/API/Core.hs            # Re-exports API.Root, API.Server, API.Types
│
├── surypus-api-shim/                       # API Shim for migration compatibility
│   ├── surypus-api-shim.cabal
│   └── src/Surypus/APIShim/Server.hs      # Wraps apiServer with RBACShim
│
├── surypus-frontend/                       # Reflex FRP frontend (GHCJS)
│   ├── surypus-frontend.cabal
│   └── src/Surypus/Frontend/
│       ├── Pages/
│       │   ├── Bills.hs
│       │   ├── Payments.hs
│       │   ├── Dashboard.hs
│       │   └── Stock.hs
│       ├── Components/
│       │   ├── Table.hs
│       │   └── Navigation.hs
│       └── API/Client.hs                  # API client (Servant client)
│
├── src/                                    # Main library source (Surypus package)
│   ├── Surypus.hs                          # Aggregator re-export
│   │
│   ├── Surypus/                            # Core framework
│   │   ├── Core.hs                         # Exports DAL.Database, DAL.EventStore, WebSocket
│   │   ├── CoreTypes.hs                    # Decimal, NonNeg refined types
│   │   ├── JWT.hs                          # JWT auth (development-grade)
│   │   ├── RBAC.hs                         # Permission data types & check
│   │   ├── RBAC/Store.hs                   # In-memory RBAC store
│   │   ├── Metrics.hs                      # STM-based metrics
│   │   ├── Error.hs                        # AppError ADT
│   │   ├── Validation.hs                   # Validation utilities
│   │   ├── Refined.hs                      # Refined type helpers
│   │   ├── RefreshTokenRepo.hs             # Refresh token handling
│   │   ├── WebSocket.hs                   # Room-based WebSocket handler
│   │   ├── WebSocket/Integration.hs        # WebSocket integration bridge
│   │   ├── WebSocket/RedisPublisher.hs     # Redis pub/sub for WebSocket
│   │   ├── AI.hs                           # AI integration types
│   │   ├── Database/Pool.hs               # Database pool config (stub)
│   │   ├── Domain/
│   │   │   ├── RBACCanon/                  # RBAC Canon (algebraic model)
│   │   │   │   ├── Types.hs                # Canon, Role, Permission types
│   │   │   │   ├── Algebra.hs              # Algebraic operations
│   │   │   │   ├── Model.hs                # Domain model
│   │   │   │   ├── Domain.hs               # Domain capabilities
│   │   │   │   ├── API.hs                  # API surface
│   │   │   │   └── Migration.hs            # SQL migration generation (V001-V040)
│   │   │   ├── Observability/
│   │   │   │   ├── Types.hs               # Observability types
│   │   │   │   ├── Domain.hs               # Observability domain
│   │   │   │   └── API.hs                  # Observability API
│   │   │   ├── Config/Config.hs            # Runtime configuration
│   │   │   └── Concurrency/Domain.hs       # Concurrency domain types
│   │   ├── Foreign/QML.hs                  # QML foreign interface
│   │   ├── API/
│   │   │   ├── AuthMiddleware.hs           # WAI auth middleware
│   │   │   ├── Authorization.hs            # Authorization helpers
│   │   │   └── MetricsMiddleware.hs         # WAI metrics middleware
│   │   ├── Reports/
│   │   │   ├── Templates.hs                # Report templates
│   │   │   └── Conversion/
│   │   │       ├── CrystalTypes.hs          # Crystal report types
│   │   │       └── CrystalToPdfSlave.hs     # Crystal → PDF conversion
│   │   ├── App/Main.hs                     # RBAC migration generator entry point
│   │   └── Infra/SqlGen/DSL.hs             # SQL generation DSL
│   │
│   │
│   ├── API/                                # API layer (Scotty-based integration server)
│   │   ├── API.hs                          # APIEndpoint, APILog types
│   │   ├── Server.hs                       # Scotty server (runApp)
│   │   ├── Types.hs                        # API types
│   │   ├── V1.hs                           # API v1 route definitions
│   │   ├── GraphQL/Proxy.hs                # GraphQL proxy
│   │   └── Integration/
│   │       ├── REST.hs                     # Integration REST API (IntegrationAPIConfig)
│   │       └── BankStatement.hs            # Bank statement integration API
│   │
│   ├── DAL/                                # Data Access Layer
│   │   ├── DAL.hs                          # Re-export aggregator
│   │   ├── Database.hs                     # Hasql pool wrapper (Pool, acquirePool)
│   │   ├── Types.hs                        # ALL shared domain types (~965 lines)
│   │   ├── DB.hs                           # DB access
│   │   ├── EventStore.hs                   # Event sourcing (append, query, replay)
│   │   ├── Procedures.hs                   # Stored procedures
│   │   ├── Production.hs                   # Production data access
│   │   ├── Agent.hs                        # Agent data access
│   │   ├── Attachment.hs                   # Attachment storage
│   │   ├── Document.hs                     # Document storage
│   │   ├── File.hs                         # File operations
│   │   ├── Blockchain.hs                   # Blockchain integration
│   │   └── Repository/
│   │       └── RBAC.hs                     # RBAC repository
│   │
│   ├── Service/                            # Service layer
│   │   ├── Service.hs                      # Service typeclass & ServiceM monad
│   │   ├── InventoryService.hs             # Inventory domain service
│   │   ├── BillService.hs                  # Bill domain service
│   │   ├── CurrencyService.hs              # Currency service
│   │   ├── PayrollService.hs               # Payroll service
│   │   ├── Orchestrator.hs                 # Service orchestrator
│   │   ├── Workflow.hs                     # Workflow domain types
│   │   ├── WorkflowEngine.hs               # Workflow engine
│   │   ├── Templates/Template.hs           # Template service
│   │   └── UI/                             # UI widgets (Desktop, Dialog, Editor, Menu, Viewer, Widget)
│   │
│   ├── Core/                               # Core services
│   │   ├── Core.hs                         # Aggregator
│   │   ├── Services/Accounting.hs          # Accounting core service
│   │   ├── Accounting/
│   │   │   ├── ReadModel.hs                # Accounting read model
│   │   │   ├── Cache.hs                    # Accounting cache
│   │   │   └── RedisCache.hs               # Redis-based cache
│   │   └── Payroll/Calculation.hs          # Payroll calculation
│   │
│   ├── Infrastructure/                     # Infrastructure backends
│   │   ├── Infrastructure.hs              # Aggregator
│   │   ├── EventStore/
│   │   │   ├── Accounting.hs               # Accounting event store
│   │   │   ├── Inventory.hs                # Inventory event store
│   │   │   └── CRM.hs                      # CRM event store
│   │   ├── WebSocket/InventoryBroadcast.hs  # Inventory WebSocket broadcasts
│   │   ├── Redis/TaskQueue.hs              # Redis-backed task queue
│   │   ├── FileStorage.hs                  # File storage
│   │   ├── Serializer.hs                   # Data serialization
│   │   ├── Encryption.hs                   # Basic encryption
│   │   ├── EncryptionAdvanced.hs           # Advanced encryption
│   │   ├── Backup.hs                       # Backup operations
│   │   ├── BackupManager.hs                # Backup manager
│   │   ├── EmailSender.hs                  # Email sending
│   │   ├── Notification.hs                # Notification system
│   │   └── Migration.hs                    # Migration support
│   │
│   ├── Integration/                        # External integrations
│   │   ├── Integration.hs                 # Aggregator
│   │   ├── API/
│   │   │   ├── API.hs                      # Integration API
│   │   │   ├── ExternalAPI.hs              # External API client
│   │   │   ├── EventStore.hs               # Integration event store
│   │   │   ├── EventBusAdvanced.hs         # Advanced event bus
│   │   │   └── EventProcessor.hs           # Event processing
│   │   ├── Adapter.hs                      # Integration adapter
│   │   ├── BankStatement.hs               # Bank statement processing
│   │   ├── EDI/EDI.hs                      # EDI integration
│   │   ├── Hub/Integration.hs              # Integration hub
│   │   ├── Health.hs                       # Health checks
│   │   ├── ImportExport.hs                 # Import/export
│   │   ├── Webhook.hs                      # Webhook handling
│   │   └── Sync.hs                         # Synchronization
│   │
│   ├── External/                           # External system integrations
│   │   ├── EGAIS.hs                        # EGAIS (Russian alcohol system)
│   │   ├── EGais/EGais.hs                  # EGAIS detailed implementation
│   │   ├── VETIS.hs                        # VETIS (Russian veterinary system)
│   │   ├── Jasper/Jasper.hs                # JasperReports integration
│   │   ├── Pentaho/Pentaho.hs              # Pentaho integration
│   │   └── UHTT/UhttStore.hs              # UHTT store integration
│   │
│   ├── Domain/Accounting/Events.hs         # Accounting domain events
│   │
│   │
│   ├── Finance.hs                          # Finance aggregator
│   ├── Finance/                            # Finance domain (21 modules)
│   │   ├── Accounting.hs                   # Double-entry accounting
│   │   ├── Account.hs                      # Chart of accounts
│   │   ├── Ledger.hs                       # General ledger
│   │   ├── Journal.hs                      # Journal entries
│   │   ├── Tax.hs                          # Tax calculation (VAT)
│   │   ├── TaxInvoice.hs                   # Tax invoices
│   │   ├── Bank.hs                         # Bank operations
│   │   ├── BankAccount.hs                  # Bank accounts
│   │   ├── Asset.hs                        # Fixed assets
│   │   ├── ExchangeRate.hs                 # Currency exchange rates
│   │   ├── Currency.hs                     # Currency definitions
│   │   ├── DebitNote.hs                    # Debit notes
│   │   ├── CreditNote.hs                   # Credit notes
│   │   ├── AccPlan.hs                      # Chart of accounts plan
│   │   ├── AccTurn2.hs                     # Account turnover
│   │   ├── AccSheet2.hs                    # Balance sheet
│   │   ├── AccMask.hs                      # Account masking
│   │   ├── AccturnDiffs.hs                 # Turnover differences
│   │   ├── SheetDiffs.hs                   # Sheet differences
│   │   ├── OpKindEx.hs                     # Operation kind extensions
│   │   └── Types.hs                        # Finance types
│   │
│   ├── Inventory.hs                        # Inventory aggregator
│   ├── Inventory/                          # Inventory domain (34 modules)
│   │   ├── Inventory.hs                    # Core inventory
│   │   ├── InventoryEx.hs                  # Inventory extensions
│   │   ├── Stock.hs                        # Stock tracking (StockFlags, mkStock)
│   │   ├── StockOp.hs                      # Stock operations
│   │   ├── StockOps.hs                     # Stock operation types
│   │   ├── Goods.hs                        # Goods/items registry
│   │   ├── GoodsEx.hs                      # Goods extensions
│   │   ├── GoodsLoc.hs                     # Goods by location
│   │   ├── GoodsReceipt.hs                 # Goods receipt
│   │   ├── GoodsTaxEx.hs                   # Goods tax extensions
│   │   ├── Warehouse.hs                    # Warehouse definitions
│   │   ├── WarehouseOps.hs                 # Warehouse operations
│   │   ├── Location.hs                     # Locations
│   │   ├── LocationEx.hs                   # Location extensions
│   │   ├── LocationEx2.hs                  # Location extensions v2
│   │   ├── Lot.hs                          # Lot tracking
│   │   ├── Barcode.hs                      # Barcode management
│   │   ├── Category.hs                     # Categories
│   │   ├── Brand.hs                        # Brands
│   │   ├── Manufacturer.hs                  # Manufacturers
│   │   ├── Unit.hs                         # Units of measure
│   │   ├── UnitEx.hs                       # Unit extensions
│   │   ├── Region.hs                       # Regions
│   │   ├── City.hs                         # Cities
│   │   ├── Country.hs                      # Countries
│   │   ├── Article.hs                      # Articles
│   │   ├── Tag2.hs                         # Tags v2
│   │   ├── TagValue.hs                     # Tag values
│   │   ├── TagObject.hs                    # Tag-object associations
│   │   ├── ObjectType.hs                   # Object type classification
│   │   ├── Operations.hs                   # Inventory operations
│   │   ├── StyloQ.hs                       # StyloQ integration
│   │   ├── Types.hs                        # Inventory types
│   │   └── Quality/QCert.hs                # Quality certificates
│   │
│   ├── Commerce.hs                         # Commerce aggregator
│   ├── Commerce/                           # Commerce domain (43 modules)
│   │   ├── Commerce.hs                     # Core commerce
│   │   ├── Orders/Order.hs                 # Sales orders
│   │   ├── Orders/Quote.hs                 # Quotes
│   │   ├── Orders/Quotation.hs             # Quotations
│   │   ├── Orders/Preorder.hs              # Pre-orders
│   │   ├── BillLine.hs                     # Bill lines
│   │   ├── BillStatusEx.hs                 # Bill status extensions
│   │   ├── BillTaxDiffs.hs                 # Bill tax differences
│   │   ├── Invoice.hs                      # Invoices
│   │   ├── AdvanceBill.hs                  # Advance bills
│   │   ├── AdvanceInvoice.hs               # Advance invoices
│   │   ├── ServiceBill.hs                  # Service bills
│   │   ├── RetBill.hs                      # Retail bills
│   │   ├── Shipment.hs                     # Shipments
│   │   ├── Return.hs                       # Returns
│   │   ├── Contract.hs                     # Contracts
│   │   ├── Discount.hs                     # Discounts
│   │   ├── Promo.hs                        # Promotions
│   │   ├── Bonus.hs                        # Bonus programs
│   │   ├── BonusPoints.hs                  # Bonus points
│   │   ├── Loyalty.hs                      # Loyalty programs
│   │   ├── GiftCard.hs                     # Gift cards
│   │   ├── Combo.hs                        # Combos/bundles
│   │   ├── Bundle.hs                       # Product bundles
│   │   ├── Package.hs                      # Packages
│   │   ├── Price.hs                        # Pricing
│   │   ├── PriceList.hs                    # Price lists
│   │   ├── PriceRule.hs                    # Price rules
│   │   ├── PriceByAgent.hs                 # Agent-specific pricing
│   │   ├── PriceByQtty.hs                  # Quantity-based pricing
│   │   ├── PriceByTime.hs                  # Time-based pricing
│   │   ├── Payment.hs                      # Payments
│   │   ├── PaymentCard.hs                  # Payment cards
│   │   ├── CashOperation.hs               # Cash operations
│   │   ├── CashRegister.hs                # Cash registers
│   │   ├── CashSessionTemp.hs             # Cash session temps
│   │   ├── MarketPlace/MarketPlace.hs      # Marketplace integration
│   │   ├── Procurement/Procurement.hs      # Procurement
│   │   ├── Visits/Visit.hs                 # Visits
│   │   ├── Notes/Comment.hs                # Comments
│   │   └── Payments/                       # Payment subdomain (CashOperation, CashRegister, PaymentCard, Payment)
│   │
│   ├── HR.hs                               # HR aggregator
│   ├── HR/                                 # Human Resources (14 modules)
│   │   ├── Types.hs                        # HR types
│   │   ├── Person.hs                       # Persons
│   │   ├── PersonEx.hs                     # Person extensions
│   │   ├── Employee.hs                     # Employees
│   │   ├── Salary.hs                       # Salary management
│   │   ├── Operations.hs                   # HR operations
│   │   ├── Position.hs                     # Positions
│   │   ├── Events.hs                       # HR events
│   │   ├── RelationsManager.hs             # Relationship management
│   │   ├── Relation.hs                     # Relations
│   │   ├── Address.hs                      # Addresses
│   │   ├── Contact.hs                      # Contacts
│   │   ├── Activity.hs                     # Activities
│   │   └── Goals/Goal.hs                   # Goals/OKRs
│   │
│   ├── CRM.hs                              # CRM aggregator
│   ├── CRM/                                # CRM (7 modules)
│   │   ├── Types.hs                        # CRM types
│   │   ├── Contact.hs                      # Contacts
│   │   ├── Company.hs                      # Companies
│   │   ├── Deal.hs                         # Deals
│   │   ├── Pipeline.hs                     # Sales pipelines
│   │   └── Activity.hs                     # Activities
│   │
│   ├── Production.hs                       # Production aggregator
│   ├── Production/                         # Production/manufacturing (16 modules)
│   │   ├── Production.hs                   # Core production
│   │   ├── Types.hs                        # Production types
│   │   ├── TechCard.hs                     # Tech cards/routing
│   │   ├── TechIssue.hs                    # Tech issues
│   │   ├── WorkOrder.hs                    # Work orders
│   │   ├── Task.hs                         # Tasks
│   │   ├── JobSystem.hs                    # Job system
│   │   ├── JobQueue.hs                     # Job queue
│   │   ├── Queue.hs                        # Queues
│   │   ├── Project.hs                      # Projects
│   │   ├── MRP.hs                          # Material requirements planning
│   │   ├── Activity.hs                     # Activities
│   │   ├── Service.hs                      # Services
│   │   ├── ServiceManager.hs               # Service management
│   │   ├── Scheduling/Cron.hs              # Cron scheduling
│   │   └── Components/Component.hs          # Components/BOM
│   │
│   ├── Retail.hs                           # Retail aggregator
│   ├── Retail/                             # Retail (6 modules)
│   │   ├── CashRegister.hs                 # POS cash registers
│   │   ├── CashSessionTemp.hs              # Cash sessions
│   │   ├── Terminal.hs                     # POS terminals
│   │   ├── Scale.hs                        # Scales
│   │   ├── Device/Scale.hs                 # Scale device driver
│   │   └── Receipts/SmartReceipt.hs        # Smart receipts
│   │
│   ├── Logistics/                          # Logistics (5 modules)
│   │   ├── Warehouse.hs                    # Warehouses
│   │   ├── Receipt.hs                      # Receipts
│   │   ├── Route.hs                        # Routes
│   │   ├── Transfer.hs                     # Transfers
│   │   └── Transport/Transport.hs          # Transport
│   │
│   ├── Reports/                            # Reporting (3 modules)
│   │   ├── Report.hs                       # Report definitions
│   │   ├── Service.hs                      # Report service
│   │   └── Jasper.hs                       # JasperReports integration
│   │
│   ├── Analytics/                          # Analytics (4 modules)
│   │   ├── Analytics.hs                    # Core analytics
│   │   ├── Chart.hs                        # Charts
│   │   ├── Dashboard.hs                    # Dashboards
│   │   ├── Export.hs                       # Export
│   │   └── Prediction.hs                   # Predictions
│   │
│   ├── System/                             # System utilities (45+ modules)
│   │   ├── Auth.hs                         # Authentication
│   │   ├── Config.hs                       # Configuration
│   │   ├── Logger.hs                       # Logging
│   │   ├── Metrics.hs                      # Metrics
│   │   ├── MetricsCollector.hs             # Metrics collection
│   │   ├── MetricsExport.hs                # Metrics export
│   │   ├── Monitoring.hs                   # Monitoring
│   │   ├── HealthCheck.hs                  # Health checks
│   │   ├── Cache.hs                        # Caching
│   │   ├── Session.hs                      # Session management
│   │   ├── Secrets.hs                      # Secrets management
│   │   ├── Audit.hs                        # Auditing
│   │   ├── AuditComplete.hs                # Complete audit trail
│   │   ├── AccessControl.hs                # Access control
│   │   ├── RateLimiter.hs                  # Rate limiting (basic)
│   │   ├── RateLimiterAdvanced.hs           # Rate limiting (advanced)
│   │   ├── CircuitBreaker*.hs              # ~12 Circuit Breaker variants
│   │   ├── Scheduler.hs                    # Scheduling
│   │   ├── JobQueue.hs                     # Job queue
│   │   ├── Jobs.hs                         # Jobs
│   │   ├── SchedulerJob.hs                 # Scheduled jobs
│   │   ├── Discovery.hs                    # Service discovery
│   │   ├── LoadBalancer.hs                 # Load balancing
│   │   ├── Retry.hs                        # Retry logic
│   │   ├── Tracing.hs                      # Distributed tracing
│   │   ├── Validation.hs                   # Validation
│   │   ├── Validator.hs                    # Validator
│   │   ├── Version.hs                      # Versioning
│   │   ├── Config.hs                       # App configuration
│   │   ├── Configuration.hs                # Configuration management
│   │   ├── Settings.hs                     # Settings
│   │   ├── Sequence.hs                     # Sequence generators
│   │   ├── Event.hs                        # Events
│   │   ├── Alert.hs                        # Alerting
│   │   ├── ClockSync.hs                    # Clock synchronization
│   │   ├── Hardware.hs                     # Hardware abstraction
│   │   ├── Cron.hs                         # Cron expressions
│   │   ├── Counter.hs                      # Counters
│   │   └── Transform.hs                    # Data transformation
│   │   └── Codes/ExtCode.hs                # External codes
│   │
│   ├── Shared/                             # Shared utilities
│   │   ├── Filter.hs                       # Filter helpers
│   │   ├── Grid.hs                         # Grid/grid view
│   │   ├── World.hs                        # World definitions
│   │   ├── Common/Conflict.hs              # Conflict resolution
│   │   ├── Export/Exporter.hs              # Export utility
│   │   └── Mesh/ServiceMesh.hs             # Service mesh
│   │
│   ├── EventBus.hs                         # In-memory event bus
│   ├── Kafka/Producer.hs                   # Kafka producer
│   ├── DomainFinance.hs                    # Finance domain re-export
│   ├── Domain.hs                           # (conceptual modules aggregated here)
│   │
│   │
│   ├── MultiTenancy/                       # Multi-tenancy (2 modules)
│   │   ├── TenantConfig.hs                 # Tenant configuration
│   │   └── Isolation.hs                    # Data isolation
│   │
│   ├── Security/Quantum/Crypto.hs          # Quantum-resistant cryptography
│   ├── Science/ML/                         # Machine learning (3 modules)
│   │   ├── DemandForecasting.hs            # Demand forecasting
│   │   ├── Features.hs                     # ML features
│   │   └── Helical.hs                      # Helical ML model
│   │
│   ├── Messaging/                          # Messaging (2 modules)
│   │   ├── Communication.hs                # Communication
│   │   └── Message.hs                      # Message types
│   │
│   ├── Tech/                               # Technical documentation (2 modules)
│   │   ├── TechCard.hs                     # Tech cards
│   │   └── TechIssue.hs                    # Tech issues
│   │
│   ├── DigitalTwin/TwinSystem.hs           # Digital twin system
│   ├── HyperIntelligence/                  # Hyper-intelligence (2 modules)
│   │   ├── NeuralInterface.hs              # Neural interface
│   │   └── HolographicUI.hs                # Holographic UI
│   ├── Consciousness/DigitalConsciousness.hs  # Digital consciousness
│   ├── AGI/AGIIntegration.hs               # AGI integration
│   ├── Agents/Agent.hs                     # Agent system
│   ├── AI/                                 # AI (2 modules)
│   │   ├── AgentFlow.hs                    # Agent workflow
│   │   └── DecisionEngine.hs               # Decision engine
│   │
│   │   # Conceptual / cosmological modules (~80 directories)
│   │   # Each contains one .hs module: Absolute*, Cosmic*, Eternal*,
│   │   # Infinite*, Quantum*, etc.
│   ├── Absolute/                           # AbsoluteSystems
│   ├── AbsoluteBeyond/
│   ├── AbsoluteEnlightenmentPt2/
│   ├── ... (80+ similar directories)
│   └── Transcendence.hs
│
├── test/                                   # Main test suite (64 files)
│   ├── Test.hs                             # Test runner
│   ├── Main.hs                             # Alternative test runner
│   ├── Runner.hs                           # Test runner
│   ├── App.hs                              # Test application
│   ├── TestHelpers.hs                      # Shared test helpers
│   ├── TestFixtures.hs                     # Shared test fixtures
│   ├── MoreAssertLike.hs                   # Custom assertions
│   ├── MakeTest.hs                         # Test generation
│   ├── MakeTestSeed.hs                     # Test seed data
│   ├── QuickCheckInvariantsSpec.hs         # QuickCheck property tests
│   │
│   ├── DAL/                                # DAL tests
│   │   ├── DBSpec.hs
│   │   ├── TypesSpec.hs
│   │   ├── EventStoreSpec.hs
│   │   ├── FixturesSpec.hs
│   │   ├── Fixtures.hs
│   │   └── IntegrationSpec.hs
│   │
│   ├── Domain/                             # Domain tests
│   │   ├── TypesSpec.hs
│   │   ├── PersonSpec.hs
│   │   ├── BillSpec.hs
│   │   ├── GoodsSpec.hs
│   │   ├── LocationSpec.hs
│   │   ├── DocumentSpec.hs
│   │   ├── CRMSpec.hs
│   │   ├── HRSpec.hs
│   │   ├── HRPropertySpec.hs
│   │   ├── PayrollSpec.hs
│   │   ├── JobSpec.hs
│   │   ├── ProductionSpec.hs
│   │   └── ProductionPropertySpec.hs
│   │
│   ├── Inventory/                          # Inventory tests
│   │   ├── StockSpec.hs
│   │   ├── GoodsSpec.hs
│   │   └── WarehouseSpec.hs
│   │
│   ├── API/                                # API tests
│   │   ├── ServerSpec.hs
│   │   ├── HealthSpec.hs
│   │   ├── RBACSpec.hs
│   │   ├── SwaggerSpec.hs
│   │   └── ProcurementSpec.hs
│   │
│   ├── Integration/                        # Integration tests
│   │   ├── CrudSpec.hs
│   │   ├── NegativeSpec.hs
│   │   ├── PerformanceSpec.hs
│   │   ├── PoolSpec.hs
│   │   ├── ValidationSpec.hs
│   │   ├── PropertySpec.hs
│   │   └── InventoryLifecycleSpec.hs
│   │
│   ├── Phase2Phase3/                       # Phase 2/3 cross-phase tests
│   │   ├── AccountingEventsSpec.hs
│   │   ├── AccountingEventStoreSpec.hs
│   │   ├── AccountingReadModelSpec.hs
│   │   ├── ReadModelCacheSpec.hs
│   │   └── AcceptanceSpec.hs
│   │
│   ├── HR/                                 # HR tests
│   │   ├── PersonSpec.hs
│   │   └── OperationsSpec.hs
│   │
│   ├── DB/RepositoriesSpec.hs              # Database repository tests
│   ├── ConfigSpec.hs                       # Configuration tests
│   ├── ConcurrencySpec.hs                  # Concurrency tests
│   ├── ObservabilitySpec.hs               # Observability tests
│   ├── RBACSpec.hs                         # RBAC tests
│   ├── RBACCanonSpec.hs                    # RBAC Canon tests
│   ├── RBACFixtures.hs                     # RBAC test fixtures
│   ├── MigrationDryRunSpec.hs              # Migration dry-run tests
│   ├── NewtypeGuardsTest.hs                # Newtype guard tests
│   ├── APITests.hs                         # Additional API tests
│   ├── AdditionalTests.hs                  # Extra tests
│   └── QuickCheck/Invariants.hs            # QuickCheck invariants
│
└── sql/migrations/                         # Generated SQL migrations
    └── V*__rbac_*.generated.sql            # 40 migration files
```

## Directory Purposes

**`surypus-common/` — Shared Types & API Definitions:**
- Purpose: Types and Servant API definitions shared between backend and frontend — the cross-package contract
- Contains: Domain types (Bill, Person, Goods, Payment, Stock, Auth), Servant API type definitions, JSON codecs
- Key files: `src/Surypus/Types.hs`, `src/Surypus/Api.hs`, `src/Surypus/Codecs.hs`

**`surypus-api/` — REST API Backend:**
- Purpose: Production REST API server — route handlers, JWT auth, data access
- Contains: Servant-based route handlers (Persons, Goods, Bills, Orders, etc.), DAL queries/mutations, JWT token handling, PDF generation, AI integrations (OpenAI, Anthropic)
- Key files: `app/Main.hs` (entry point), `src/Surypus/API/Server.hs`, `src/Surypus/API/Auth.hs`

**`surypus-api-core/` — API Core Re-export:**
- Purpose: Thin re-export layer for staged migration compatibility
- Contains: `Surypus.API.Core` which re-exports `API.Root`, `API.Server`, `API.Types`

**`surypus-api-shim/` — API Compatibility Shim:**
- Purpose: Bridging layer for V1→V2 API migration, wrapping `apiServer` with `RBACShim`
- Contains: `Surypus.APIShim.Server` with shim wrapper functions

**`surypus-frontend/` — Reflex FRP Frontend:**
- Purpose: Web frontend built with Reflex/Reflex-DOM compiled via GHCJS
- Contains: Pages (Bills, Payments, Dashboard, Stock), Components (Table, Navigation), API client
- Key files: `src/Surypus/Frontend/Pages/Dashboard.hs`, `API/Client.hs`

**`src/Surypus/` — Core Framework:**
- Purpose: Central shared framework — types, auth, networking, infrastructure
- Contains: CoreTypes, JWT, RBAC, WebSocket, Metrics, Error, Domain models (RBACCanon, Observability, Config, Concurrency), App/Main entry, SQL generation DSL, API middleware, reports, reports conversion (Crystal)
- Key files: `CoreTypes.hs`, `JWT.hs`, `RBAC.hs`, `WebSocket.hs`, `Error.hs`, `Domain/RBACCanon/Migration.hs`

**`src/DAL/` — Data Access Layer:**
- Purpose: All database access — the single gateway to persistent storage
- Contains: Hasql pool wrapper, EventStore (event sourcing), all shared domain types, DB query procedures, attachments, documents, blockchain interop
- Key files: `Database.hs`, `Types.hs` (~965 lines), `EventStore.hs`, `DB.hs`

**`src/Service/` — Business Service Layer:**
- Purpose: Typed service orchestration with error handling via `ServiceM` monad
- Contains: Service typeclass, domain services (Inventory, Bill, Currency, Payroll), Workflow definitions, UI widgets (Desktop, Dialog, Editor, Menu, Viewer, Widget)
- Key files: `Service.hs`, `InventoryService.hs`, `WorkflowEngine.hs`, `Orchestrator.hs`

**`src/Infrastructure/` — Infrastructure Backends:**
- Purpose: Concrete implementations of infrastructure concerns (pluggable)
- Contains: EventStore per domain (Accounting, Inventory, CRM), Redis task queue, WebSocket broadcast, file storage, encryption (basic + advanced), serialization, backup, email, notifications, migrations

**`src/Integration/` — External Integration Layer:**
- Purpose: Integration with external systems
- Contains: Integration API, webhooks, EDI, integration hub, bank statement processing, import/export, sync, health checks, event bus

**`src/External/` — External Government Systems:**
- Purpose: Integration with Russian government systems
- Contains: EGAIS (alcohol), VETIS (veterinary), JasperReports, Pentaho, UHTT store

**`src/Finance/` — Accounting & Finance Domain:**
- Purpose: Full double-entry accounting system
- Contains: Chart of accounts, ledger, journal, tax (VAT), bank accounts, fixed assets, exchange rates, balance sheet, account turnover, debit/credit notes, invoices

**`src/Inventory/` — Inventory Management Domain:**
- Purpose: Complete inventory management
- Contains: Stock tracking, goods registry, warehouses, locations, lots, barcodes, categories, brands, manufacturers, units of measure, quality certificates, tags, StyloQ integration

**`src/Commerce/` — Commerce Domain (43 modules):**
- Purpose: Full commerce lifecycle — orders, pricing, payments, returns, loyalty
- Contains: Sales orders, quotes, invoices, shipments, returns, contracts, discounts, promotions, bonuses, loyalty, gift cards, bundles, price lists/rules, marketplace, procurement, cash operations, POS

**`src/HR/` — Human Resources:**
- Purpose: HR management
- Contains: Persons, employees, salary, positions, operations, events, relationships, addresses, contacts, activities, goals

**`src/Production/` — Production/Manufacturing:**
- Purpose: Production planning and execution
- Contains: Tech cards, work orders, tasks, MRP, job queue, scheduling/cron, components/BOM, projects, services

**`src/System/` — System Infrastructure (45+ modules):**
- Purpose: Infrastructure utilities — auth, config, logging, metrics, monitoring, rate limiting, circuit breakers, scheduling, discovery, load balancing, retry, tracing, validation, caching, auditing, secrets, sessions
- Contains: ~12 CircuitBreaker variants, RateLimiter (basic + advanced), HealthCheck, Metrics, Monitoring, Scheduler, JobQueue, Discovery, LoadBalancer, Tracing, Secrets, Audit

**`test/` — Test Suite:**
- Purpose: Hspec + QuickCheck tests organized by domain
- Contains: Unit tests per domain (DAL, Domain, Inventory, HR, API), integration tests (Crud, Negative, Performance, InventoryLifecycle), cross-phase tests (Phase2Phase3), property-based tests (QuickCheck)

## Key File Locations

**Entry Points:**
- `surypus-api/app/Main.hs`: Production API server entry (Warp port 3000)
- `src/Surypus/App/Main.hs`: RBAC migration generator (generates SQL to `sql/migrations/`)
- `src/API/Server.hs` (`runApp`): Scotty integration server entry

**Configuration:**
- `stack.yaml`: Stack resolver (LTS-22.21) and package list
- `Surypus.cabal`: Main library module list and dependencies
- `config.yaml`: Dolt SQL server configuration (port 34789)
- `surypus-api/surypus-api.cabal`: API package deps (Servant, Hasql, JWT, WebSockets)

**Core Logic:**
- `src/Surypus/CoreTypes.hs`: Refined types (Decimal, NonNeg)
- `src/Surypus/JWT.hs`: JWT auth (development-grade)
- `src/Surypus/RBAC.hs`: Permission system (30+ permissions)
- `src/Surypus/WebSocket.hs`: Real-time event broadcasting
- `src/Surypus/Error.hs`: App error hierarchy
- `src/DAL/EventStore.hs`: Event sourcing engine
- `src/DAL/Types.hs`: All shared domain types (~965 lines)
- `src/Finance/Accounting.hs`: Double-entry accounting engine
- `src/Inventory/Stock.hs`: Stock tracking

**Testing:**
- `test/Test.hs`: Main test runner
- `test/Runner.hs`: Alternative test runner
- `test/QuickCheckInvariantsSpec.hs`: Property-based tests

## Naming Conventions

**Files:**
- **Haskell source**: PascalCase module name matching directory path (e.g., `Finance/Accounting.hs`)
- **Top-level aggregators**: PascalCase matching directory name (e.g., `Finance.hs` aggregates `Finance/`)
- **Test files**: PascalCase with `Spec` suffix (e.g., `StockSpec.hs`, `PersonSpec.hs`)
- **Cabal packages**: kebab-case (e.g., `surypus-api`, `surypus-common`)
- **SQL migrations**: `V###__description.generated.sql` (e.g., `V001__rbac_basic_schema.generated.sql`)

**Directories:**
- **Domain directories**: PascalCase singular nouns (e.g., `Finance`, `Inventory`, `Commerce`, `HR`, `CRM`)
- **Top-level layer dirs**: Single uppercase acronym where applicable (`API`, `DAL`, `HR`, `AI`, `ML`)
- **Conceptual module dirs**: PascalCase compound words (e.g., `AbsoluteEnlightenmentPt2`, `EternalPerfectionV2`, `InfiniteTranscendence`)

**Modules:**
- **Top-level**: Single uppercase name (`Surypus`, `Core`, `EventBus`)
- **Framework**: `Surypus.*` hierarchy (`Surypus.JWT`, `Surypus.RBAC`, `Surypus.Domain.*`)
- **DAL**: `DAL.*` (`DAL.Database`, `DAL.EventStore`)
- **API**: `API.*` (`API.Server`, `API.Integration.REST`)
- **Domain**: Single uppercase domain name + module hierarchy (`Finance.Accounting`, `Inventory.Stock`)
- **Service**: `Service.*` (`Service.Service`, `Service.InventoryService`)
- **Infrastructure**: `Infrastructure.*` (`Infrastructure.EventStore.*`, `Infrastructure.Redis.*`)
- **External**: `External.*` (`External.EGAIS`, `External.VETIS`)
- **Integration**: `Integration.*` (`Integration.API.*`, `Integration.EDI`)

## Where to Add New Code

**New Feature:**
- Primary code: `src/<Domain>/` (e.g., `src/Finance/`, `src/Inventory/`, `src/Commerce/`)
- API endpoint: `surypus-api/src/Surypus/API/<Name>.hs`
- Service orchestration: `src/Service/<Name>Service.hs`
- DAL access: `src/DAL/` or `surypus-api/src/Surypus/DAL/`
- Tests: `test/<Domain>/<Name>Spec.hs`

**New Component/Module:**
- Core framework type: `src/Surypus/<Name>.hs`
- Domain module: `src/<Domain>/<Name>.hs`
- Shared types: `surypus-common/src/Surypus/Types/<Name>.hs` (must be in its own cabal)
- Infrastructure backend: `src/Infrastructure/<Name>.hs` or `src/Infrastructure/<Category>/<Name>.hs`

**Utilities:**
- Shared helpers: `src/Shared/<Name>.hs` or `src/Shared/<Category>/<Name>.hs`
- System utilities: `src/System/<Name>.hs`

**Integration with external system:**
- New external system: `src/External/<System>/<Name>.hs`
- Webhook/inbound integration: `src/Integration/<Name>.hs` or `src/Integration/API/<Name>.hs`

**Frontend:**
- New page: `surypus-frontend/src/Surypus/Frontend/Pages/<Name>.hs`
- New component: `surypus-frontend/src/Surypus/Frontend/Components/<Name>.hs`

## Special Directories

**`.beads/`:**
- Purpose: Issue tracking database (Dolt-based beads issue tracker)
- Generated: Yes
- Committed: Yes

**`.dolt/`:**
- Purpose: Dolt data directory (PostgreSQL-compatible version-controlled database)
- Generated: Yes (runtime)
- Committed: No (gitignored)

**`sql/migrations/`:**
- Purpose: Generated SQL migration files from RBAC Canon DSL
- Generated: Yes (by `Surypus.App.Main`)
- Committed: Yes (checked in artifacts)

**`.doltcfg/`:**
- Purpose: Dolt server configuration directory
- Generated: Yes (runtime)
- Committed: No (gitignored)

---

*Structure analysis: 2026-05-24*
