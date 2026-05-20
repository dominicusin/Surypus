---
phase: 15-qml-desktop-skeleton
reviewed: 2026-05-20T12:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - suryus-api/src/Surypus/JWT/Token.hs
  - suryus-api/src/Surypus/API/Server.hs
  - qml/Main.qml
  - qml/LoginPanel.qml
  - qml/api/surypusapiclient.h
  - qml/api/surypusapiclient.cpp
  - qml/main.cpp
  - qml/CMakeLists.txt
  - packaging/AppImage/package-appimage.sh
findings:
  critical: 6
  warning: 6
  info: 3
  total: 15
status: issues_found
---

# Phase 15: Code Review Report — QML Desktop Skeleton

**Reviewed:** 2026-05-20T12:00:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed 9 source files spanning Haskell (JWT auth, API server), QML/C++ (desktop client), and shell packaging. Found **6 critical** and **6 warning** issues.

The most severe problems are:
1. **JWT security**: Hardcoded fallback secret + `read` on untrusted claims = forged tokens and server crashes
2. **QML type resolution**: Inline `Component` IDs are used as if they were QML types — the application will crash on any page navigation
3. **Callback dispatch bug**: Concurrent API calls to the same path with different HTTP methods will lose callbacks
4. **Packaging gap**: `LoginPanel.qml` omitted from `QML_FILES`, making it unavailable in production builds

---

## Critical Issues

### CR-01: Hardcoded JWT signing secret fallback [SECURITY]

**File:** `suryus-api/src/Surypus/JWT/Token.hs:61`
**Issue:** `getSigningKey` falls back to the well-known string `"dev-secret-change-in-production"` when the `SURYPUS_JWT_SECRET` environment variable is not set. Any attacker who knows this string can forge valid JWT tokens and impersonate any user. This is a critical authentication bypass vulnerability if this code is deployed without setting the env var.

**Fix:** Replace the fallback with an explicit error that aborts startup:
```haskell
getSigningKey :: IO LBS.ByteString
getSigningKey = do
  mbSecret <- lookupEnv "SURYPUS_JWT_SECRET"
  case mbSecret of
    Nothing -> error "FATAL: SURYPUS_JWT_SECRET environment variable is not set"
    Just s  -> pure $ LBS.fromStrict $ TE.encodeUtf8 $ T.pack s
```
Alternatively, generate a random key at first startup and persist it.

---

### CR-02: `read` on untrusted JWT claim throws runtime exception [CRASH]

**File:** `suryus-api/src/Surypus/JWT/Token.hs:116`
**Issue:** `read $ T.unpack uid` will throw a `Prelude.read: no parse` exception if the `sub` claim contains non-numeric data (e.g., `"null"`, `"undefined"`, or a crafted string from a forged JWT). Since `verifyToken` uses `const True` for audience/issuer validation (WR-02), an attacker with the secret can craft a JWT with a non-numeric `sub` and crash the server.

**Fix:** Use `readMaybe` from `Text.Read`:
```haskell
import Text.Read (readMaybe)
...
case mbUid of
  Just uid -> case readMaybe (T.unpack uid) of
    Just uidInt ->
      pure $ Right $ UserClaims
        { ucUserId = uidInt
        , ucUsername = fromMaybe "" mbName
        , ucRoles = fromMaybe [] mbRole
        }
    Nothing -> pure $ Left "Invalid token: sub claim is not a valid integer"
  _ -> pure $ Left "Invalid token: missing or invalid sub claim"
```

---

### CR-03: Signing failure returns error text as token [BUG]

**File:** `suryus-api/src/Surypus/JWT/Token.hs:81-84`
**Issue:** When `signClaims` fails, the `Left` branch converts the JWT error to a `Text` string and returns it as if it were a valid token:
```haskell
Left jwtErr -> pure $ T.pack $ show jwtErr
```
The caller (`handleLogin` in Server.hs) treats this as a valid JWT token and returns it in `LoginResponse`. The client receives a garbage error message as the token. This is a type-level logic error — the error should propagate as an exception or HTTP 500.

**Fix:** Throw an error or return `Left` from `generateToken`:
```haskell
generateToken :: Pool -> User -> IO Text
generateToken _pool user = do
  now <- getCurrentTime
  let uid = T.pack $ show $ userId user
  secret <- getSigningKey
  result <- runJOSE @JWTError $ do ...
  case result of
    Left jwtErr -> throwIO $ userError $ "JWT signing failed: " ++ show jwtErr
    Right signedJWT -> pure $ TE.decodeUtf8 $ LBS.toStrict $ encodeCompact signedJWT
```

---

### CR-04: Callback key collision across HTTP methods [BUG]

**File:** `qml/Main.qml:65-71`
**Issue:** The `callApi` function stores callbacks keyed by `method:path`, but `onRequestSucceeded` matches any HTTP method for the given path, then **deletes all four method keys** (GET, POST, PUT, DELETE). If two concurrent requests hit the same path with different methods, the first response will delete the second request's callback, causing it to be silently dropped.

Sequence of failure:
1. `callApi("GET", "/dashboard", ...)` → stores callback at `apiCallbacks["GET:/dashboard"]`
2. `callApi("POST", "/dashboard", { ... })` → stores callback at `apiCallbacks["POST:/dashboard"]`
3. GET response arrives → `onRequestSucceeded("/dashboard", ...)` looks up `"GET:/dashboard"`, finds it, invokes it, then **deletes all four keys**
4. POST response arrives → callback is gone → **silently dropped**

**Fix:** Look up and delete only the matching method+path key:
```qml
function onRequestSucceeded(path, response) {
    var obj = response.toVariant()
    if (typeof obj !== "object") obj = { data: obj }
    // Search for the actual method that was used
    for (var prefix of ["GET:", "POST:", "PUT:", "DELETE:"]) {
        var key = prefix + path
        var cb = apiCallbacks[key]
        if (cb) {
            delete apiCallbacks[key]
            if (cb.onSuccess) cb.onSuccess(obj)
            return
        }
    }
}
```
And similarly in `onRequestFailed`. The key takeaway: only delete the exact key that matched, not all four.

---

### CR-05: QML type resolution failure — inline Component IDs used as type names [CRASH]

**File:** `qml/Main.qml:647, 725, 826, 1026, 1060, 1269, 1427, 1529, 1633, 1786, 1883, 2042`
**Issue:** The code defines reusable UI elements as `Component { id: navItem }`, `Component { id: statCard }`, `Component { id: dashboardPage }`, etc., but then attempts to use them as QML type names: `NavigationItem { ... }`, `StatCard { ... }`, `DashboardPage {}`, `jobsPage { ... }` (line 1638 property), `hrPage { ... }` (line 1638), `productionPage { ... }`, `reportsPage { ... }`, `settingsPage { ... }`.

In QML, `Component { id: someName }` does **not** register `someName` as a reusable type. It only creates a Component object referenceable via `Loader { sourceComponent: someName }` or `someName.createObject(parent)`. Using `SomeName {}` as a type requires either:
- A `SomeName.qml` file in the import path
- A C++ type registered via `qmlRegisterType`

None of the types `NavigationItem`, `StatCard`, `DashboardPage`, `jobsPage` (as type), etc. exist as QML files or registered types. This will cause the QML engine to throw a reference error at runtime when any page navigation occurs.

**Fix (option 1):** Use `Loader` with `sourceComponent` — replace inline usage with Loader pattern:
```qml
// Instead of:
NavigationItem { icon: "📋"; text: "Обзор"; selected: true }

// Use:
Loader {
    sourceComponent: navItem
    // Properties need to be set on the loaded item
    onItemChanged: {
        if (item) {
            item.icon = "📋"
            item.text = "Обзор"
            item.selected = true
        }
    }
}
```

**Fix (option 2, better):** Extract each component into its own `.qml` file:
- `qml/NavigationItem.qml`
- `qml/StatCard.qml`
- `qml/DashboardPage.qml`
- etc.

Then list them in `QML_FILES` in CMakeLists.txt.

The code at line 1010 (`contentStack.push(documentPage)`) is correct because it passes the Component object by ID. Only the `SomeName {}` pattern is broken.

---

### CR-06: LoginPanel.qml missing from QML_FILES [PRODUCTION BUG]

**File:** `qml/CMakeLists.txt:19-21`
**Issue:** `LoginPanel.qml` is loaded at line 562 of `Main.qml` as a QML type (`LoginPanel { ... }`), but it is **not listed** in `qt_add_qml_module(QML_FILES ...)`. With Qt 6's resource system, only listed files are compiled into the binary. `LoginPanel.qml` will work during development (when the filesystem is available) but will fail to resolve in an AppImage or production deployment.

Additionally, `LoginPanel.qml` is also not listed as a `QML_FILES` entry.

**Fix:** Add LoginPanel.qml (and any other QML files that are used as types) to the `QML_FILES` list:
```cmake
qt_add_qml_module(surypus-dashboard
    URI SurypusDashboard
    VERSION 1.0
    QML_FILES
        Main.qml
        LoginPanel.qml
        components/Components.qml
)
```
If individual component files are created (per CR-05 Fix option 2), list those here too.

---

## Warnings

### WR-01: Missing "Bearer " prefix validation in auth middleware

**File:** `suryus-api/src/Surypus/API/Server.hs:76`
**Issue:** The auth middleware uses `BS.drop 7 hdr` to strip the `"Bearer "` prefix from the Authorization header, but does not verify the prefix exists. If a client sends `"Token xyz"` or `"Basic abc"` as the header, `BS.drop 7` will corrupt the token value, potentially causing misleading error messages or authentication bypass in edge cases.

**Fix:** Check for the prefix:
```haskell
Just hdr -> do
  let hdrStr = TE.decodeUtf8 hdr
  case T.stripPrefix "Bearer " hdrStr of
    Nothing -> respond $ W.responseLBS status401 [("Content-Type","text/plain")] "Invalid authorization header format"
    Just tok -> JWT.verifyToken tok >>= \case
      Left _  -> respond $ W.responseLBS status401 [("Content-Type","text/plain")] "Invalid token"
      Right _ -> app req respond
```

---

### WR-02: JWT verification accepts any audience/issuer

**File:** `suryus-api/src/Surypus/JWT/Token.hs:93`
**Issue:** `defaultJWTValidationSettings (const True)` disables audience (`aud`) and issuer (`iss`) validation. Combined with the fallback dev secret (CR-01), any token signed with that secret will pass verification regardless of intended audience. This undermines JWT security boundaries in multi-service deployments.

**Fix:** Validate the audience claim against a known value:
```haskell
let config = defaultJWTValidationSettings $ \_ -> True
-- In production, replace with:
-- let expectedAudience = "surypus-api"
--     config = defaultJWTValidationSettings (== expectedAudience)
```

---

### WR-03: HTTP default URL transmits token in cleartext

**File:** `qml/api/surypusapiclient.cpp:8`
**Issue:** The default base URL is `http://localhost:3000/api/v1` — using **HTTP** not HTTPS. The JWT bearer token is transmitted in cleartext for every API request. If the user connects to a remote server or if localhost traffic is intercepted, the token can be stolen.

**Fix:** Default to HTTPS:
```cpp
, m_baseUrl("https://localhost:3000/api/v1")
```
Or better, accept a URL at construction time and make HTTPS the documented default.

---

### WR-04: No wget prerequisite check in packaging script

**File:** `packaging/AppImage/package-appimage.sh:23`
**Issue:** Only `cmake` presence is checked at line 14. The `download_if_missing` function uses `wget` at line 24 but if `wget` is not installed, the script will fail with a confusing error.

**Fix:** Add a wget check at the top of the script:
```bash
command -v wget >/dev/null 2>&1 || { echo "ERROR: wget required for downloading linuxdeploy"; exit 1; }
```

---

### WR-05: AppImage output filename glob mismatch

**File:** `packaging/AppImage/package-appimage.sh:75-76`
**Issue:** The script tries to move `Surypus_ERP-*.AppImage` but the linuxdeploy output filename is typically derived from the desktop file or cmake project name. The cmake project is named `SurypusDashboard`, not `Surypus_ERP`. The first glob will likely produce no match, and the second glob `*.AppImage` may move unexpected files.

**Fix:** Use a deterministic output path. Set the `OUTPUT` variable in linuxdeploy or move the specific known filename:
```bash
# Either set the AppImage filename explicitly in linuxdeploy, or:
mv -v "$BUILD_DIR"/surypus-dashboard-*.AppImage "$OUTPUT_DIR/" 2>/dev/null || true
```

---

### WR-06: No `nullptr` check on `QNetworkReply*` return value

**File:** `qml/api/surypusapiclient.cpp:98, 132, 138, 145, 152`
**Issue:** `makeRequest` can return `nullptr` if the method string is not recognized (currently only "GET", "POST", "PUT", "DELETE" are handled — line 50 `return nullptr;`). The callers immediately dereference the return value via `connect(reply, ...)`, which would segfault on a null pointer. While the currently exposed QML methods only use recognized methods, any future `Q_INVOKABLE` method using an unrecognized verb will crash.

**Fix:** Assert or guard at the call site:
```cpp
QNetworkReply *reply = makeRequest("POST", "/login", jsonBody);
if (!reply) {
    emit loginFailed("Failed to create request");
    return;
}
connect(reply, &QNetworkReply::finished, ...);
```

---

## Info

### IN-01: LoginPanel `loginSucceeded` signal parameter unused by parent

**File:** `qml/Main.qml:563-567`
**Issue:** The `LoginPanel` component declares `signal loginSucceeded(string token)` and propagates the token from `ApiClient.onLoginSucceeded`. However, the parent handler in `Main.qml` ignores the token:
```qml
onLoginSucceeded: {
    appStack.replace(mainContentPage)
    loadInitialData()
}
```
The token is available from the `ApiClient` singleton (it emits its own signal), but the `LoginPanel` signal parameter is silently dropped. Consider removing the parameter if it's truly unused, or passing it for explicit chain-of-trust.

---

### IN-02: Token expiry hardcoded at 3600 seconds

**File:** `suryus-api/src/Surypus/JWT/Token.hs:79`
**Issue:** Token expiry is hardcoded as `addUTCTime 3600 now` and also hardcoded as `3600` in `Server.hs:206`. This should be configurable (from environment or config). Consider reading `JWT_EXPIRY_SECONDS` from the environment or using a configuration value.

---

### IN-03: Old `qml/main.qml` and `src/Surypus/JWT.hs` stub files remain

**File:** `qml/main.qml`
**File:** `src/Surypus/JWT.hs`
**Issue:** The old `main.qml` (lowercase, using XMLHttpRequest directly) and the old `Surypus.JWT` stub module (using fake tokens) remain in the codebase alongside the new implementations. While not harmful, they create confusion about which code is active. The old `main.qml` is never loaded (the `main.cpp` loads `Main.qml`). Consider removing dead files to reduce maintenance surface area.

---

## Summary

| Severity | Count | Key Areas |
|----------|-------|-----------|
| Critical | 6 | JWT hardcoded secret, `read` crash, error-as-token bug, callback collision, QML type resolution, missing QML file |
| Warning  | 6 | Bearer prefix, JWT audience validation, HTTP default, missing wget check, filename glob, null pointer guard |
| Info     | 3 | Unused signal param, hardcoded expiry, dead files |

**Most impactful issue:** CR-01 + CR-02 together mean an attacker with knowledge of the dev JWT secret (or without one, since there's a hardcoded fallback) can forge tokens with arbitrary `sub` values. A malicious `sub` containing non-numeric text causes a runtime crash via `read`. This is a full authentication bypass + denial of service vulnerability.

**Recommended immediate actions:**
1. Fix CR-01 (remove hardcoded fallback)
2. Fix CR-02 (use `readMaybe`)
3. Fix CR-03 (proper error propagation)
4. Fix CR-04 (callback dispatch logic)
5. Fix CR-05 and CR-06 (QML type architecture + packaging)

---

_Reviewed: 2026-05-20T12:00:00Z_
_Reviewer: gsd-code-reviewer (agent)_
_Depth: standard_
