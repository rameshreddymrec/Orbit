import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, unquote
import urllib.request

class ProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        query_params = parse_qs(parsed_path.query)
        
        if 'url' in query_params:
            target_url = unquote(query_params['url'][0])
        else:
            self.send_error(400, "Missing 'url' parameter")
            return
        
        try:
            print(f"Proxying: {target_url}", flush=True)
            
            req = urllib.request.Request(
                target_url,
                headers={
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                    'Accept': 'application/json, text/plain, */*',
                    'Referer': 'https://www.jiosaavn.com/',
                    'Origin': 'https://www.jiosaavn.com',
                }
            )
            
            with urllib.request.urlopen(req, timeout=10) as response:
                data = response.read()
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(data)
                
                print(f"Success! Returned {len(data)} bytes", flush=True)
                
        except Exception as e:
            print(f"Error: {e}", flush=True)
            self.send_error(500, f"Proxy error: {str(e)}")
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def log_message(self, format, *args):
        pass

if __name__ == '__main__':
    PORT = 3000
    server = HTTPServer(('127.0.0.1', PORT), ProxyHandler)
    print(f"BlackHole Proxy Server running on http://localhost:{PORT}", flush=True)
    print(f"Ready to proxy requests!", flush=True)
    sys.stdout.flush()
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped", flush=True)
        server.shutdown()
