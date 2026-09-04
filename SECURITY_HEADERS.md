# Security Headers Policy

This document describes the security headers used in Surypus and best practices for secure configuration.

## What Are Security Headers?

Security headers are HTTP response headers that instruct browsers and clients how to behave securely. They help protect against common web attacks like XSS, clickjacking, and data injection.

## Recommended Security Headers

### Essential Headers

| Header | Purpose | Recommended Value |
|--------|---------|-------------------|
| `Strict-Transport-Security` | Forces HTTPS | `max-age=31536000; includeSubDomains` |
| `Content-Security-Policy` | Prevents XSS and data injection | `default-src 'self'` |
| `X-Content-Type-Options` | Prevents MIME sniffing | `nosniff` |
| `X-Frame-Options` | Prevents clickjacking | `DENY` |
| `X-XSS-Protection` | Enables XSS filter | `1; mode=block` |
| `Referrer-Policy` | Controls referrer information | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | Controls browser features | `geolocation=(), microphone=(), camera=()` |
| `Cache-Control` | Controls caching | `no-store, no-cache, must-revalidate` |

### CORS Headers

| Header | Purpose | Recommended Value |
|--------|---------|-------------------|
| `Access-Control-Allow-Origin` | Whitelist origins | Specify exact origins, not `*` |
| `Access-Control-Allow-Methods` | Allowed methods | `GET, POST, PUT, DELETE, OPTIONS` |
| `Access-Control-Allow-Headers` | Allowed headers | `Content-Type, Authorization` |
| `Access-Control-Expose-Headers` | Expose headers to client | `X-Request-Id, X-RateLimit-Remaining` |

### Content Security Policy

A strong CSP is critical for XSS protection:

```http
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'
```

**Explanation:**
- `default-src 'self'` - Only load from same origin
- `script-src 'self' 'unsafe-inline' 'unsafe-eval'` - Allow inline scripts and eval (needed for some apps)
- `style-src 'self' 'unsafe-inline'` - Allow inline styles
- `img-src 'self' data:` - Allow images and data URIs
- `frame-ancestors 'none'` - Prevent clickjacking
- `base-uri 'self'` - Prevent base tag injection
- `form-action 'self'` - Restrict form submissions

### HSTS (HTTP Strict Transport Security)

```http
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

**Explanation:**
- `max-age=31536000` - Cache for 1 year (31,536,000 seconds)
- `includeSubDomains` - Apply to all subdomains
- `preload` - Allow listing in browser HSTS preload lists

### Permissions Policy

```http
Permissions-Policy: geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()
```

**Explanation:**
- Disables features the app doesn't need
- Prevents potential sensor-based attacks

### Cache Control

```http
Cache-Control: no-store, no-cache, must-revalidate
Pragma: no-cache
Expires: 0
```

**Explanation:**
- Prevents sensitive data from being cached

## Implementation Examples

### Haskell/Yesod

```haskell
-- In web app configuration
securityHeaders :: Middleware
securityHeaders app req sendResponse = do
    let headers = [
            ("Strict-Transport-Security", "max-age=31536000; includeSubDomains"),
            ("Content-Security-Policy", "default-src 'self'"),
            ("X-Content-Type-Options", "nosniff"),
            ("X-Frame-Options", "DENY"),
            ("X-XSS-Protection", "1; mode=block"),
            ("Referrer-Policy", "strict-origin-when-cross-origin"),
            ("Permissions-Policy", "geolocation=(), microphone=(), camera=()")
          ]
    app req $ \resp -> sendResponse $ setHeaders headers resp
```

### Nginx

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Content-Security-Policy "default-src 'self'" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
```

### Apache

```apache
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
Header always set Content-Security-Policy "default-src 'self'"
Header always set X-Content-Type-Options "nosniff"
Header always set X-Frame-Options "DENY"
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"
```

## Testing Security Headers

### Using curl

```bash
curl -I https://surypus.dev
```

Look for the security headers in the response.

### Using securityheaders.com

Visit [https://securityheaders.com/](https://securityheaders.com/) and enter your URL to get a graded report.

### Using Mozilla Observatory

Visit [https://observatory.mozilla.org/](https://observatory.mozilla.org/) for comprehensive testing.

## Content Security Policy Testing

Before deploying CSP, test in report-only mode:

```http
Content-Security-Policy-Report-Only: default-src 'self'; report-uri /csp-report
```

Then implement a report endpoint to collect violations before enforcing.

## Security Headers Checklist

- [ ] Strict-Transport-Security configured
- [ ] Content-Security-Policy configured
- [ ] X-Content-Type-Options: nosniff
- [ ] X-Frame-Options: DENY
- [ ] X-XSS-Protection: 1; mode=block
- [ ] Referrer-Policy set
- [ ] Permissions-Policy set
- [ ] CORS properly restricted
- [ ] Cache-Control for sensitive pages
- [ ] HSTS preload eligible (optional)

## Common Issues

### CSP Blocking Legitimate Resources

If CSP breaks functionality:
1. Check the browser console for CSP violation reports
2. Add specific origins to allowed sources
3. Use nonce or hash-based matching for inline scripts
4. Test in report-only mode before enforcing

### HSTS and Development

In development environments, HSTS can cause issues:
- Don't set HSTS in development
- Use environment-specific configuration
- Consider shorter max-age for testing

### CORS Preflight Requests

CORS preflight (OPTIONS) requests must be handled:
- Return correct headers for OPTIONS requests
- Don't block OPTIONS in firewall rules
- Set appropriate cache headers for preflight

## Related Resources

- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [MDN Web Security](https://developer.mozilla.org/en-US/docs/Web/Security)
- [CSP Evaluator](https://csp-evaluator.withgoogle.com/)
- [securityheaders.com](https://securityheaders.com/)

---

*Last updated: 2026-09-04*
