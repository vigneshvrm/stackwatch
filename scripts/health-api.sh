#!/bin/bash
#
# STACKWATCH: Health API Server
# Simple HTTP server wrapper around health-check.sh
# Returns JSON status for /api/health endpoint
#
# Usage: ./health-api.sh [port]
# Default port: 8888

set -euo pipefail

PORT=${1:-8888}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_CHECK_SCRIPT="${SCRIPT_DIR}/health-check.sh"

# Check if health-check.sh exists
if [[ ! -f "${HEALTH_CHECK_SCRIPT}" ]]; then
    echo "Error: health-check.sh not found at ${HEALTH_CHECK_SCRIPT}" >&2
    exit 1
fi

# Make sure health-check.sh is executable
chmod +x "${HEALTH_CHECK_SCRIPT}" 2>/dev/null || true

# Function to run health check and return JSON
run_health_check() {
    local healthy=0
    local unhealthy=0
    local warnings=0
    local status="nominal"
    
    # Run health check and capture output
    local output
    output=$("${HEALTH_CHECK_SCRIPT}" 2>&1) || local exit_code=$?
    
    # Parse health check results
    if echo "${output}" | grep -q "Overall Status: HEALTHY"; then
        healthy=$(echo "${output}" | grep -oP "Healthy: \K\d+" || echo "0")
        unhealthy=$(echo "${output}" | grep -oP "Unhealthy: \K\d+" || echo "0")
        warnings=$(echo "${output}" | grep -oP "Warnings: \K\d+" || echo "0")
        status="nominal"
    elif echo "${output}" | grep -q "Overall Status: UNHEALTHY"; then
        healthy=$(echo "${output}" | grep -oP "Healthy: \K\d+" || echo "0")
        unhealthy=$(echo "${output}" | grep -oP "Unhealthy: \K\d+" || echo "0")
        warnings=$(echo "${output}" | grep -oP "Warnings: \K\d+" || echo "0")
        if [[ ${unhealthy} -gt 0 ]]; then
            status="critical"
        else
            status="degraded"
        fi
    else
        # If we can't parse, check exit code
        if [[ ${exit_code:-0} -ne 0 ]]; then
            status="critical"
        else
            status="degraded"
        fi
    fi
    
    # Determine status based on unhealthy count
    if [[ ${unhealthy} -gt 0 ]]; then
        status="critical"
    elif [[ ${warnings} -gt 0 ]]; then
        status="degraded"
    else
        status="nominal"
    fi
    
    # Return JSON
    cat <<EOF
{
  "status": "${status}",
  "healthy": ${healthy},
  "unhealthy": ${unhealthy},
  "warnings": ${warnings},
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Simple HTTP server using netcat or Python
if command -v python3 &> /dev/null; then
    # Use Python HTTP server
    python3 <<PYTHON_EOF
import http.server
import socketserver
import json
import subprocess
import sys
from datetime import datetime

class HealthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/health' or self.path == '/health':
            # Run health check
            try:
                result = subprocess.run(
                    ['${HEALTH_CHECK_SCRIPT}'],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                # Parse results
                healthy = 0
                unhealthy = 0
                warnings = 0
                status = 'nominal'
                
                output = result.stdout + result.stderr
                
                if 'Overall Status: HEALTHY' in output:
                    import re
                    healthy_match = re.search(r'Healthy: (\d+)', output)
                    unhealthy_match = re.search(r'Unhealthy: (\d+)', output)
                    warnings_match = re.search(r'Warnings: (\d+)', output)
                    
                    healthy = int(healthy_match.group(1)) if healthy_match else 0
                    unhealthy = int(unhealthy_match.group(1)) if unhealthy_match else 0
                    warnings = int(warnings_match.group(1)) if warnings_match else 0
                    
                    if unhealthy > 0:
                        status = 'critical'
                    elif warnings > 0:
                        status = 'degraded'
                    else:
                        status = 'nominal'
                elif 'Overall Status: UNHEALTHY' in output or result.returncode != 0:
                    import re
                    unhealthy_match = re.search(r'Unhealthy: (\d+)', output)
                    warnings_match = re.search(r'Warnings: (\d+)', output)
                    
                    unhealthy = int(unhealthy_match.group(1)) if unhealthy_match else 1
                    warnings = int(warnings_match.group(1)) if warnings_match else 0
                    
                    if unhealthy > 0:
                        status = 'critical'
                    else:
                        status = 'degraded'
                
                response = {
                    'status': status,
                    'healthy': healthy,
                    'unhealthy': unhealthy,
                    'warnings': warnings,
                    'timestamp': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
                }
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                error_response = {
                    'status': 'error',
                    'message': str(e),
                    'timestamp': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
                }
                self.wfile.write(json.dumps(error_response).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

if __name__ == '__main__':
    try:
        with socketserver.TCPServer(('', ${PORT}), HealthHandler) as httpd:
            print(f'Health API server running on port ${PORT}')
            print('Access at: http://localhost:${PORT}/api/health')
            httpd.serve_forever()
    except KeyboardInterrupt:
        print('\nShutting down health API server...')
        sys.exit(0)
PYTHON_EOF
else
    echo "Error: python3 is required to run the health API server" >&2
    exit 1
fi

