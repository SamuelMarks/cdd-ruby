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
sdk_dir = os.path.abspath(os.path.join(project_root, '..', 'cdd-ruby-client-v3-generated-server'))
server_dir = os.path.abspath(os.path.join(project_root, '..', 'cdd-ruby-server-v3-generated'))
petstore_json = os.path.join(project_root, 'spec', 'fixtures', 'petstore_oas3.json')

shutil.rmtree(sdk_dir, ignore_errors=True)
shutil.rmtree(server_dir, ignore_errors=True)

os.chdir(project_root)
if subprocess.run(["bundle", "exec", "ruby", "bin/cdd-ruby", "from_openapi", "to_sdk", "-i", petstore_json, "-o", sdk_dir]).returncode != 0:
    print("Failed to generate SDK for OpenAPI 3")
    sys.exit(1)

if subprocess.run(["bundle", "exec", "ruby", "bin/cdd-ruby", "from_openapi", "to_server", "-i", petstore_json, "-o", server_dir, "--with-ephemeral", "--tests"]).returncode != 0:
    print("Failed to generate Server for OpenAPI 3")
    sys.exit(1)

os.chdir(server_dir)
if subprocess.run(["bundle", "install"]).returncode != 0:
    print("Failed to install server dependencies")
    sys.exit(1)

print("Running generated server unit tests...")
env = os.environ.copy()
env["EPHEMERAL_DB"] = "true"
if subprocess.run(["bundle", "exec", "ruby", "-e", "Dir.glob('tests/**/*_test.rb').each { |f| require_relative f }"], env=env).returncode != 0:
    print("Failed to run server unit tests for OpenAPI 3")
    sys.exit(1)

random.seed()
port = random.randint(8000, 8999)

print("Attempting to start generated server...")
server_process = subprocess.Popen(["bundle", "exec", "ruby", "server.rb", "-p", str(port), "--ephemeral"], cwd=server_dir)

server_ready = False
base_path = ''
for _ in range(30):
    try:
        req = urllib.request.Request(f"http://127.0.0.1:{port}{base_path}/pet/findByStatus?status=available")
        with urllib.request.urlopen(req) as response:
            if response.status in [200, 401, 404, 501]:
                server_ready = True
                break
    except urllib.error.HTTPError as e:
        if e.code in [200, 401, 404, 501]:
            server_ready = True
            break
    except Exception:
        pass
    time.sleep(2)

if not server_ready:
    print("Generated server failed to respond.")
    server_process.terminate()
    sys.exit(1)

if os.path.exists(sdk_dir):
    os.chdir(sdk_dir)
    os.makedirs('spec', exist_ok=True)
    with open('spec/client_spec.rb', 'w') as f:
        f.write(f"""require_relative '../lib/client'

RSpec.describe ClientSdk do
  let(:client) {{ ClientSdk.new('http://127.0.0.1:{port}{base_path}') }}

  it 'calls the endpoint (which may return 200, 401 or 501)' do
    begin
      response = client.findPetsByStatus(status: 'available')
      expect(['200', '401', '501']).to include(client.last_response.code)
    rescue StandardError => e
      fail "Failed to call endpoint: #{{e.message}}"
    end
  end
end
""")
    with open('Gemfile', 'a+') as f:
        f.seek(0)
        if 'rspec' not in f.read():
            f.write("\ngem 'rspec'\n")
    
    subprocess.run(["bundle", "install"])
    if subprocess.run(["bundle", "exec", "rspec"]).returncode != 0:
        print("RSpec failed!")
        server_process.terminate()
        sys.exit(1)

server_process.terminate()
server_process.wait()
shutil.rmtree(sdk_dir, ignore_errors=True)
shutil.rmtree(server_dir, ignore_errors=True)
