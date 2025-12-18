# Grafana Redirect Issue - Quick Reference

## Problem
`ERR_TOO_MANY_REDIRECTS` when accessing `http://123.176.58.198/grafana/`

## Current Configuration

### Grafana (`/etc/grafana/config/grafana.ini`)
```ini
[server]
http_port = 3000
domain = 123.176.58.198
root_url = %(protocol)s://%(domain)s/grafana/
serve_from_sub_path = true
enforce_domain = false
```

### Nginx (`/etc/nginx/sites-available/stackwatch`)
```nginx
location /grafana/ {
    proxy_pass http://localhost:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_redirect off;
}
```

## What We've Tried
1. ✅ Trailing slash in root_url
2. ✅ No trailing slash in root_url
3. ✅ Multiple proxy_redirect rules
4. ✅ proxy_redirect off
5. ✅ Rewrite rules
6. ✅ Domain detection and override
7. ✅ enforce_domain = false
8. ✅ cookie_samesite = lax

**All attempts failed - redirect loop persists**

## Quick Diagnostic Commands

```bash
# 1. Check Grafana config
sudo podman exec grafana cat /etc/grafana/grafana.ini | grep -A 5 "\[server\]"

# 2. Check Grafana logs
sudo podman logs grafana --tail 50 | grep -i "redirect\|error"

# 3. Test direct access (bypass Nginx)
curl -I http://localhost:3000/

# 4. Test via Nginx
curl -I http://localhost/grafana/

# 5. Check what Grafana sees
curl -v http://localhost:3000/api/frontend/settings
```

## Key Observations
- ✅ Direct Grafana access works (`localhost:3000`)
- ❌ Nginx proxy creates redirect loop
- ✅ Prometheus works with similar setup
- ❌ Grafana redirects to same URL (`/grafana/` → `/grafana/`)

## Next Steps to Try
1. Check Grafana version for known subpath issues
2. Test with `serve_from_sub_path = false` (serve from root)
3. Try alternative Nginx config with rewrite rules
4. Check if domain variable expands correctly
5. Review Grafana GitHub issues for subpath redirect bugs

## Full Analysis
See: `docs/GRAFANA_REDIRECT_ISSUE_ANALYSIS.md`

