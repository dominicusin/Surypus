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
                ]
          ]
    ]
