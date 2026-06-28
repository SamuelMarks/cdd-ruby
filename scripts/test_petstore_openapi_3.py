#!/usr/bin/env python3
import os
import subprocess
import sys
import shutil
import time
import urllib.request
import urllib.error
import random

scripts_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(scripts_dir, '..'))
sdk_dir = os.path.abspath(os.path.join(project_root, '..', 'cdd-ruby-client-v3'))
petstore_json = os.path.join(project_root, 'spec', 'fixtures', 'petstore_oas3.json')

shutil.rmtree(sdk_dir, ignore_errors=True)

os.chdir(project_root)
if subprocess.run(["bundle", "exec", "ruby", "bin/cdd-ruby", "from_openapi", "to_sdk", "-i", petstore_json, "-o", sdk_dir]).returncode != 0:
    print("Failed to generate SDK for OpenAPI 3.2.0")
    sys.exit(1)

base_path = '/api/v3'
active_port = int(os.environ.get('OAS3_MOCK_PORT', '8081'))
server_ready = False
try:
    req = urllib.request.Request(f"http://127.0.0.1:{active_port}{base_path}/pet/findByStatus?status=available")
    with urllib.request.urlopen(req, timeout=2) as response:
        if response.status == 200:
            server_ready = True
except Exception:
    pass

server_process = None
docker_used = False

if server_ready:
    print(f"Reusing active mock server on port {active_port}")
    port = active_port
else:
    random.seed()
    port = random.randint(8000, 8999)
    container_name = f"cdd_petstore_jvm_v3_{int(time.time())}"

    java_bin = shutil.which('javac')
    python_bin = shutil.which('python3') or shutil.which('python')

    if java_bin:
        print('Starting mock server using JVM...')
        mock_code = """import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

public class MockServerOAS3 {
    public static void main(String[] args) throws Exception {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 8080;
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", port), 0);
        server.createContext("/", new MyHandler());
        server.setExecutor(null);
        server.start();
    }

    static class MyHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange t) throws IOException {
            if (t.getRequestURI().getPath().contains("findByStatus")) {
                String response = "[{\\"id\\": 1, \\"name\\": \\"doggie\\", \\"status\\": \\"available\\"}]";
                t.getResponseHeaders().set("Content-Type", "application/json");
                t.sendResponseHeaders(200, response.length());
                OutputStream os = t.getResponseBody();
                os.write(response.getBytes());
                os.close();
            } else {
                t.sendResponseHeaders(404, 9);
                OutputStream os = t.getResponseBody();
                os.write("Not Found".getBytes());
                os.close();
            }
        }
    }
}
"""
        with open('scripts/MockServerOAS3.java', 'w') as f:
            f.write(mock_code)
        subprocess.run(["javac", "scripts/MockServerOAS3.java"])
        server_process = subprocess.Popen(["java", "-cp", "scripts", "MockServerOAS3", str(port)])
    elif python_bin:
        print('Starting mock server using Python...')
        mock_script = """import sys, json
from http.server import BaseHTTPRequestHandler, HTTPServer
class MockServerRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if 'findByStatus' in self.path:
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps([{"id": 1, "name": "doggie", "status": "available"}]).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found")
HTTPServer(('127.0.0.1', int(sys.argv[1])), MockServerRequestHandler).serve_forever()
"""
        with open('scripts/mock_server_oas3.py', 'w') as f:
            f.write(mock_script)
        server_process = subprocess.Popen([python_bin, "scripts/mock_server_oas3.py", str(port)])
    else:
        print('Attempting to start JVM container...')
        subprocess.run(["docker", "run", "--rm", "-d", "-p", f"{port}:8080", "--name", container_name, "openapitools/openapi-petstore:latest"])
        docker_used = True

    for _ in range(60):
        try:
            req = urllib.request.Request(f"http://127.0.0.1:{port}{base_path}/pet/findByStatus?status=available")
            with urllib.request.urlopen(req) as response:
                if response.status == 200:
                    server_ready = True
                    break
        except Exception:
            pass
        time.sleep(2)

    if not server_ready:
        print('Container failed to respond.')
        if docker_used:
            subprocess.run(["docker", "stop", container_name], stderr=subprocess.DEVNULL)
        else:
            server_process.terminate()
        sys.exit(1)

if os.path.exists(sdk_dir):
    os.chdir(sdk_dir)
    os.makedirs('spec', exist_ok=True)
    with open('spec/client_spec.rb', 'w') as f:
        f.write(f"""require_relative '../lib/client'

RSpec.describe ClientSdk do
  let(:client) {{ ClientSdk.new('http://127.0.0.1:{port}{base_path}') }}

  it 'fetches pets by status' do
    response = client.findPetsByStatus(status: 'available')
    expect(response).to be_an(Array)
  end
end
""")
    with open('Gemfile', 'a+') as f:
        f.seek(0)
        if 'rspec' not in f.read():
            f.write("\ngem 'rspec'\n")
    
    subprocess.run(["bundle", "install"])
    if subprocess.run(["bundle", "exec", "rspec"]).returncode != 0:
        print('RSpec failed!')
        if not (active_port == port and server_ready and docker_used == False and server_process is None):
            if docker_used:
                subprocess.run(["docker", "stop", container_name], stderr=subprocess.DEVNULL)
            else:
                server_process.terminate()
        sys.exit(1)

if not (active_port == port and server_ready and docker_used == False and server_process is None):
    if docker_used:
        subprocess.run(["docker", "stop", container_name], stderr=subprocess.DEVNULL)
    else:
        server_process.terminate()
        server_process.wait()

shutil.rmtree(sdk_dir, ignore_errors=True)

def remove_if_exists(path):
    if os.path.exists(path):
        os.remove(path)

os.chdir(project_root)
if not (active_port == port and server_ready and docker_used == False and server_process is None):
    remove_if_exists('scripts/MockServerOAS3.java')
    remove_if_exists('scripts/MockServerOAS3.class')
    remove_if_exists('scripts/MockServerOAS3$MyHandler.class')
    remove_if_exists('scripts/mock_server_oas3.py')
