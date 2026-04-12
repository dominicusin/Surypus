{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.OpenApi (apiSwaggerSpec) where

import Data.Aeson (Value, object, (.=))

apiSwaggerSpec :: Value
apiSwaggerSpec =
  object
    [ "openapi" .= ("3.0.3" :: String),
      "info"
        .= object
          [ "title" .= ("Surypus ERP API" :: String),
            "version" .= ("0.1.0" :: String),
            "description" .= ("REST API for Surypus ERP/CRM system" :: String)
          ],
      "servers"
        .= ( [ object
                 [ "url" .= ("http://localhost:8080" :: String),
                   "description" .= ("Local server" :: String)
                 ]
             ] ::
               [Data.Aeson.Value]
           ),
      "paths"
        .= object
          [ "/api/v1/health"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Health check" :: String),
                        "responses"
                          .= object
                            [ "200"
                                .= object
                                  [ "description" .= ("OK" :: String)
                                  ]
                            ]
                      ]
                ],
            "/api/v1/health/live"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Liveness probe" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("OK" :: String)]
                            ]
                      ]
                ],
            "/api/v1/health/ready"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Readiness probe" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("OK" :: String)]
                            ]
                      ]
                ],
            "/api/v1/login"
              .= object
                [ "post"
                    .= object
                      [ "summary" .= ("User login" :: String),
                        "requestBody"
                          .= object
                            [ "required" .= (True :: Bool),
                              "content"
                                .= object
                                  [ "application/json"
                                      .= object
                                        [ "schema"
                                            .= object
                                              [ "type" .= ("object" :: String),
                                                "required" .= (["username", "password"] :: [String]),
                                                "properties"
                                                  .= object
                                                    [ "username"
                                                        .= object
                                                          [ "type" .= ("string" :: String)
                                                          ],
                                                      "password"
                                                        .= object
                                                          [ "type" .= ("string" :: String)
                                                          ]
                                                    ]
                                              ]
                                        ]
                                  ]
                            ],
                        "responses"
                          .= object
                            [ "200"
                                .= object
                                  [ "description" .= ("Login successful" :: String)
                                  ],
                              "401"
                                .= object
                                  [ "description" .= ("Invalid credentials" :: String)
                                  ]
                            ]
                      ]
                ],
            "/api/v1/refresh"
              .= object
                [ "post"
                    .= object
                      [ "summary" .= ("Refresh access token" :: String),
                        "requestBody"
                          .= object
                            [ "required" .= (True :: Bool),
                              "content"
                                .= object
                                  [ "application/json"
                                      .= object
                                        [ "schema"
                                            .= object
                                              [ "type" .= ("object" :: String),
                                                "properties"
                                                  .= object
                                                    [ "refreshToken" .= object ["type" .= ("string" :: String)]
                                                    ]
                                              ]
                                        ]
                                  ]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Token refreshed" :: String)],
                              "401" .= object ["description" .= ("Invalid token" :: String)]
                            ]
                      ]
                ],
            "/api/v1/logout"
              .= object
                [ "post"
                    .= object
                      [ "summary" .= ("User logout" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Logged out" :: String)]
                            ]
                      ]
                ],
            "/api/v1/me"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Current user info" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Current user" :: String)],
                              "401" .= object ["description" .= ("Unauthorized" :: String)]
                            ]
                      ]
                ],
            "/api/v1/persons"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List persons" :: String),
                        "parameters"
                          .= object
                            [ "name" .= object ["type" .= ("string" :: String)],
                              "inn" .= object ["type" .= ("string" :: String)],
                              "type" .= object ["type" .= ("integer" :: String)],
                              "status" .= object ["type" .= ("integer" :: String)],
                              "limit" .= object ["type" .= ("integer" :: String)]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("List of persons" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create person" :: String),
                        "requestBody"
                          .= object
                            [ "required" .= (True :: Bool),
                              "content"
                                .= object
                                  [ "application/json"
                                      .= object
                                        [ "schema" .= object ["type" .= ("object" :: String)]
                                        ]
                                  ]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Person created" :: String)],
                              "401" .= object ["description" .= ("Unauthorized" :: String)],
                              "403" .= object ["description" .= ("Forbidden" :: String)]
                            ]
                      ]
                ],
            "/api/v1/persons/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get person by ID" :: String),
                        "parameters"
                          .= object
                            [ "id" .= object ["type" .= ("integer" :: String)]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Person" :: String)]
                            ]
                      ],
                  "put"
                    .= object
                      [ "summary" .= ("Update person" :: String),
                        "parameters"
                          .= object
                            [ "id" .= object ["type" .= ("integer" :: String)]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Person updated" :: String)]
                            ]
                      ],
                  "delete"
                    .= object
                      [ "summary" .= ("Delete person" :: String),
                        "parameters"
                          .= object
                            [ "id" .= object ["type" .= ("integer" :: String)]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Person deleted" :: String)]
                            ]
                      ]
                ],
            "/api/v1/goods"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List goods" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("List of goods" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create goods" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Goods created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/goods/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get goods by ID" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Goods" :: String)]
                            ]
                      ]
                ],
            "/api/v1/locations"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List locations" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("List of locations" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create location" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Location created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/locations/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get location by ID" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Location" :: String)]
                            ]
                      ]
                ],
            "/api/v1/bills"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List bills" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("List of bills" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create bill" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Bill created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/bills/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get bill by ID" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Bill" :: String)]
                            ]
                      ]
                ],
            "/api/v1/bills/{id}/status"
              .= object
                [ "put"
                    .= object
                      [ "summary" .= ("Update bill status" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Status updated" :: String)]
                            ]
                      ]
                ],
            "/api/v1/rbac/roles"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List RBAC roles" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("List of roles" :: String)],
                              "401" .= object ["description" .= ("Unauthorized" :: String)],
                              "403" .= object ["description" .= ("Forbidden" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create RBAC role" :: String),
                        "requestBody"
                          .= object
                            [ "required" .= (True :: Bool),
                              "content"
                                .= object
                                  [ "application/json"
                                      .= object
                                        [ "schema" .= object ["type" .= ("object" :: String)]
                                        ]
                                  ]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Role created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/rbac/grants"
              .= object
                [ "post"
                    .= object
                      [ "summary" .= ("Create permission grant" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Grant created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/rbac/grants/active"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List active grants" :: String),
                        "parameters"
                          .= object
                            [ "principal" .= object ["type" .= ("string" :: String)]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Active grants" :: String)]
                            ]
                      ]
                ],
            "/api/v1/rbac/grants/cleanup"
              .= object
                [ "post"
                    .= object
                      [ "summary" .= ("Cleanup expired grants" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Cleanup completed" :: String)]
                            ]
                      ]
                ],
            "/api/v1/rbac/audit"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("RBAC audit log" :: String),
                        "parameters"
                          .= object
                            [ "limit" .= object ["type" .= ("integer" :: String)]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Audit entries" :: String)]
                            ]
                      ]
                ],
            "/api/v1/audit-log"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("General audit log" :: String),
                        "parameters"
                          .= object
                            [ "limit" .= object ["type" .= ("integer" :: String)]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Audit log entries" :: String)],
                              "403" .= object ["description" .= ("Forbidden" :: String)]
                            ]
                      ]
                ],
            "/api/v1/metrics"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Application metrics" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Metrics data" :: String)]
                            ]
                      ]
                ],
            "/api/v1/persons/search"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Search persons" :: String),
                        "parameters"
                          .= object
                            [ "q" .= object ["type" .= ("string" :: String)]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Search results" :: String)]
                            ]
                      ]
                ],
            "/api/v1/goods/search"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Search goods" :: String),
                        "parameters"
                          .= object
                            [ "q" .= object ["type" .= ("string" :: String)]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Search results" :: String)]
                            ]
                      ]
                ],
            "/api/v1/payments"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List payments" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("List of payments" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create payment" :: String),
                        "requestBody"
                          .= object
                            [ "required" .= (True :: Bool),
                              "content"
                                .= object
                                  [ "application/json"
                                      .= object
                                        [ "schema" .= object ["type" .= ("object" :: String)]
                                        ]
                                  ]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Payment created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/payments/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get payment by ID" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Payment" :: String)]
                            ]
                      ],
                  "put"
                    .= object
                      [ "summary" .= ("Update payment" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Payment updated" :: String)]
                            ]
                      ],
                  "delete"
                    .= object
                      [ "summary" .= ("Delete payment" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Payment deleted" :: String)]
                            ]
                      ]
                ],
            "/api/v1/orders"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List orders" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("List of orders" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create order" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Order created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/orders/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get order by ID" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Order" :: String)]
                            ]
                      ],
                  "put"
                    .= object
                      [ "summary" .= ("Update order" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Order updated" :: String)]
                            ]
                      ],
                  "delete"
                    .= object
                      [ "summary" .= ("Delete order" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Order deleted" :: String)]
                            ]
                      ]
                ],
            "/api/v1/orders/{id}/status"
              .= object
                [ "put"
                    .= object
                      [ "summary" .= ("Update order status" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Status updated" :: String)]
                            ]
                      ]
                ],
            "/api/v1/taxes"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List taxes" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("List of taxes" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create tax" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Tax created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/taxes/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get tax by ID" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Tax" :: String)]
                            ]
                      ],
                  "put"
                    .= object
                      [ "summary" .= ("Update tax" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Tax updated" :: String)]
                            ]
                      ],
                  "delete"
                    .= object
                      [ "summary" .= ("Delete tax" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Tax deleted" :: String)]
                            ]
                      ]
                ],
            "/api/v1/vat/calculate"
              .= object
                [ "post"
                    .= object
                      [ "summary" .= ("Calculate VAT" :: String),
                        "requestBody"
                          .= object
                            [ "required" .= (True :: Bool),
                              "content"
                                .= object
                                  [ "application/json"
                                      .= object
                                        [ "schema" .= object ["type" .= ("object" :: String)]
                                        ]
                                  ]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("VAT calculation result" :: String)]
                            ]
                      ]
                ],
            "/api/v1/vat/rates"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get VAT rates" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("VAT rates" :: String)]
                            ]
                      ]
                ],
            "/api/v1/currencies"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List currencies" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("List of currencies" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create currency" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Currency created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/currencies/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get currency by ID" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Currency" :: String)]
                            ]
                      ],
                  "put"
                    .= object
                      [ "summary" .= ("Update currency" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Currency updated" :: String)]
                            ]
                      ],
                  "delete"
                    .= object
                      [ "summary" .= ("Delete currency" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Currency deleted" :: String)]
                            ]
                      ]
                ],
            "/api/v1/stock"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get stock overview" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Stock overview" :: String)]
                            ]
                      ]
                ],
            "/api/v1/stock/summary"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get stock summary" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Stock summary" :: String)]
                            ]
                      ]
                ],
            "/api/v1/stock/{gid}/locations/{lid}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get stock by goods and location" :: String),
                        "parameters"
                          .= object
                            [ "gid" .= object ["type" .= ("integer" :: String)],
                              "lid" .= object ["type" .= ("integer" :: String)]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Stock item" :: String)]
                            ]
                      ]
                ],
            "/api/v1/stock/goods/{gid}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get stock by goods ID" :: String),
                        "parameters"
                          .= object
                            [ "gid" .= object ["type" .= ("integer" :: String)]
                            ],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Stock by goods" :: String)]
                            ]
                      ]
                ],
            "/api/v1/accounting"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List accounts" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Chart of accounts" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create account" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Account created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/accounting/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get account by ID" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Account" :: String)]
                            ]
                      ],
                  "put"
                    .= object
                      [ "summary" .= ("Update account" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Account updated" :: String)]
                            ]
                      ],
                  "delete"
                    .= object
                      [ "summary" .= ("Delete account" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Account deleted" :: String)]
                            ]
                      ]
                ],
            "/api/v1/accounting/entries"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List accounting entries" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Accounting entries" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create accounting entry" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Entry created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/accounting/entries/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get entry by ID" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Entry" :: String)]
                            ]
                      ],
                  "put"
                    .= object
                      [ "summary" .= ("Update entry" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Entry updated" :: String)]
                            ]
                      ],
                  "delete"
                    .= object
                      [ "summary" .= ("Delete entry" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Entry deleted" :: String)]
                            ]
                      ]
                ],
            "/api/v1/payroll"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get payroll info" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Payroll info" :: String)]
                            ]
                      ]
                ],
            "/api/v1/payroll/employees"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List employees" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Employee list" :: String)]
                            ]
                      ]
                ],
            "/api/v1/payroll/employees/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get employee by ID" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Employee" :: String)]
                            ]
                      ]
                ],
            "/api/v1/payroll/salaries"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List salaries" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Salary list" :: String)]
                            ]
                      ]
                ],
            "/api/v1/payroll/salary/{eid}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get salary by employee ID" :: String),
                        "parameters" .= object ["eid" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Salary" :: String)]
                            ]
                      ]
                ],
            "/api/v1/reports"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List reports" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Report list" :: String)]
                            ]
                      ]
                ],
            "/api/v1/reports/metadata"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get report metadata" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Report metadata" :: String)]
                            ]
                      ]
                ],
            "/api/v1/reports/templates"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List report templates" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Report templates" :: String)]
                            ]
                      ]
                ],
            "/api/v1/reports/{id}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get report by ID" :: String),
                        "parameters" .= object ["id" .= object ["type" .= ("integer" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Report" :: String)]
                            ]
                      ]
                ],
            "/api/v1/reports/jrxml/{name}"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Get JRXML report template" :: String),
                        "parameters" .= object ["name" .= object ["type" .= ("string" :: String)]],
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("JRXML report" :: String)]
                            ]
                      ]
                ],
            "/api/v1/dashboard"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("Dashboard data" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Dashboard" :: String)]
                            ]
                      ]
                ],
            "/api/v1/users"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List users" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("User list" :: String)]
                            ]
                      ]
                ],
            "/api/v1/jobs"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List jobs" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Job list" :: String)]
                            ]
                      ],
                  "post"
                    .= object
                      [ "summary" .= ("Create job" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Job created" :: String)]
                            ]
                      ]
                ],
            "/api/v1/jobs/pending"
              .= object
                [ "get"
                    .= object
                      [ "summary" .= ("List pending jobs" :: String),
                        "responses"
                          .= object
                            [ "200" .= object ["description" .= ("Pending jobs" :: String)]
                            ]
                      ]
                ]
          ]
    ]
