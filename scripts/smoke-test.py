#!/usr/bin/env python3
"""Business smoke test; --staff requires an approved, controlled staff URL."""
import argparse
import datetime
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import uuid


def local_test(tag, report_dir):
    """Use the same built image IDs for isolated tests; never load repository .env."""
    report = Path(report_dir)
    report.mkdir(parents=True, exist_ok=True)
    if (report / 'local-test.json').exists():
        raise ValueError('Choose a new report directory; existing evidence is preserved')
    images = {}
    for tier in ['api', 'web']:
        info = json.loads(subprocess.check_output(
            ['docker', 'image', 'inspect', f'clinicflow-{tier}:{tag}'], text=True))[0]
        assert info['Architecture'] == 'amd64' and info['Os'] == 'linux'
        assert info['Config']['User'] == '10001:10001'
        if tier == 'api':
            assert info['Size'] < 200_000_000, 'API image exceeds 200 MB'
        images[tier] = {k: info[k] for k in ['Id', 'Architecture', 'Os', 'Size']}
        images[tier]['User'] = info['Config']['User']
    existing = subprocess.check_output(['docker', 'ps', '-aq'], text=True).splitlines()
    project = 'clinicflow-p26-' + uuid.uuid4().hex[:10]
    result = {'images': images, 'project': project,
              'started_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'status': 'FAIL', 'cleanup': 'not attempted'}
    with tempfile.TemporaryDirectory(prefix='clinicflow-p26-') as temporary:
        root = Path(temporary)
        api_env = {'APP_ENV': 'local', 'DB_HOST': 'db', 'DB_NAME': 'clinicflow',
                   'DB_USER': 'synthetic_app', 'DB_PASSWORD': secrets.token_hex(32)}
        services = {'db': {'image': 'mysql:8.4', 'platform': 'linux/amd64',
            'environment': {'MYSQL_ROOT_PASSWORD': secrets.token_hex(32),
                'MYSQL_DATABASE': 'clinicflow', 'MYSQL_USER': api_env['DB_USER'],
                'MYSQL_PASSWORD': api_env['DB_PASSWORD']},
            'tmpfs': ['/var/lib/mysql'],
            'healthcheck': {'test': ['CMD', 'mysqladmin', 'ping', '-h', 'localhost', '--silent'],
                'interval': '3s', 'timeout': '3s', 'retries': 60}}}
        for name, tier in [('api', 'api'), ('web', 'web'), ('public', 'web')]:
            services[name] = {'image': images[tier]['Id'], 'platform': 'linux/amd64',
                'read_only': True, 'cap_drop': ['ALL'], 'tmpfs': ['/tmp:mode=1777'],
                'environment': api_env if tier == 'api' else {
                    'API_URL': 'http://api:5000', 'LOCAL_STAFF_ACCESS': '1' if name == 'web' else '0'}}
        services['api']['depends_on'] = {'db': {'condition': 'service_healthy'}}
        config = root / 'compose.json'
        config.write_text(json.dumps({'services': services}))
        config.chmod(0o600)
        compose = ['docker', 'compose', '--env-file', os.devnull, '--project-directory',
                   temporary, '-p', project, '-f', str(config)]

        def run(arguments, input_text=None):
            subprocess.run(compose + arguments, input=input_text, text=True, check=True)

        try:
            run(['up', '-d', '--no-build', '--wait'])
            for _ in range(2):
                run(['exec', '-T', 'api', 'python', 'init_db.py'])
            run(['exec', '-T', 'api', 'python', '-'], "import app; assert len(app.query('SELECT id FROM clinics')) == 3; print('PASS: three seed clinics after two initializations')")
            for name in ['web', 'public']:
                # Extend the existing business smoke instead of duplicating assertions.
                run(['exec', '-T', 'api', 'python', '-', f'http://{name}:8080'] +
                    (['--staff'] if name == 'web' else []), Path(__file__).read_text())
                run(['exec', '-T', name, 'nginx', '-t', '-c', '/tmp/nginx.conf'])
            run(['exec', '-T', 'api', 'python', '-'], CONTAINER_CHECKS)
            run(['exec', '-T', 'api', 'python', '-m', 'pip', 'check'])
            for name in ['api', 'web', 'public']:
                container = subprocess.check_output(compose + ['ps', '-q', name], text=True).strip()
                state = json.loads(subprocess.check_output(['docker', 'inspect', container], text=True))[0]
                assert state['HostConfig']['ReadonlyRootfs']
                assert 'ALL' in state['HostConfig']['CapDrop']
            result['status'] = 'PASS'
        finally:
            run(['down', '--volumes', '--remove-orphans'])
            result['cleanup'] = 'PASS: only this random project removed; TemporaryDirectory removes credentials'
            remaining = set(subprocess.check_output(['docker', 'ps', '-aq'], text=True).splitlines())
            assert set(existing) <= remaining, 'A pre-existing container disappeared'
            result['preexisting_containers_preserved'] = True
            result['finished_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            (report / 'local-test.json').write_text(json.dumps(result, indent=2) + '\n')
    print('PASS: isolated local image tests and cleanup; image IDs:', json.dumps(images))


CONTAINER_CHECKS = r"""
import os, ssl, urllib.request
from pathlib import Path
import app, init_db
assert Path('/app/schema.sql').is_file()
ssl.create_default_context(cafile='/app/certs/global-bundle.pem')
assert os.getuid() == 10001
for name in ['web', 'public']:
    for path in ['/health', '/healthz']:
        with urllib.request.urlopen(f'http://{name}:8080{path}', timeout=10) as r:
            assert r.status == 200
    for method in ['GET', 'HEAD']:
        with urllib.request.urlopen(urllib.request.Request(f'http://{name}:8080/', method=method), timeout=10) as r:
            assert r.headers['Server'] == 'nginx'
            for key, value in [('X-Content-Type-Options', 'nosniff'), ('X-Frame-Options', 'DENY'), ('Referrer-Policy', 'no-referrer')]:
                assert r.headers[key] == value
# Exercise PyMySQL's RSA dependency path without exposing a password.
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from pymysql._auth import sha2_rsa_encrypt
key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
pub = key.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
assert len(sha2_rsa_encrypt(b'synthetic-only', b'01234567890123456789', pub)) == 256
app.APP_ENV = 'dev'
os.environ['APP_ENV'] = 'dev'
os.environ['DB_AUTH_MODE'] = 'password'
os.environ.pop('DB_SSL_CA', None)
for operation in [app.get_conn, init_db.main]:
    try:
        operation()
    except ValueError as error:
        assert 'DB_SSL_CA' in str(error)
    else:
        raise AssertionError('AWS mode accepted missing CA')
os.environ['DB_SSL_CA'] = '/app/certs/global-bundle.pem'
os.environ.pop('DB_PASSWORD', None)
try:
    app.get_conn()
except KeyError as error:
    assert error.args == ('DB_PASSWORD',)
else:
    raise AssertionError('API accepted missing password')
try:
    init_db.main()
except ValueError as error:
    assert 'DB_PASSWORD' in str(error)
else:
    raise AssertionError('init accepted missing password')
print('PASS: health compatibility, headers, schema/CA, nonroot, RSA dependency, missing CA/password refusal')
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('url', nargs='?')
    parser.add_argument('--local-images', metavar='TAG')
    parser.add_argument('--report-dir', default='docs/evidence/phase-2.6/final')
    parser.add_argument('--staff', action='store_true', help='Verify schedule and status changes through controlled access')
    args = parser.parse_args()
    if args.local_images:
        return local_test(args.local_images, args.report_dir)
    if not args.url:
        parser.error('url or --local-images TAG is required')
    base = args.url.rstrip('/')

    def request(path, method='GET', body=None, expected=200):
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(base + path, data=data, method=method,
                                     headers={'Content-Type': 'application/json'})
        try:
            response = urllib.request.urlopen(req, timeout=30)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            payload = response.read()
            assert response.status == expected, f'{method} {path}: expected {expected}, got {response.status}'
            return json.loads(payload) if payload.startswith((b'{', b'[')) else payload

    request('/healthz')
    clinics = request('/api/clinics')
    assert clinics, 'No seed clinics'
    clinic = clinics[0]['id']
    date = (datetime.date.today() + datetime.timedelta(days=60)).isoformat()
    query = f'?clinic_id={clinic}&date={date}'
    slots = request('/api/slots' + query)
    free = next((s['hour'] for s in slots if s['available']), None)
    assert free is not None, 'No free test slot (use a disposable database)'
    booking = {'clinic_id': clinic, 'slot_date': date, 'slot_hour': free,
               'patient_name': 'Synthetic-' + uuid.uuid4().hex[:8], 'mobile': '0000000000'}
    booking_id = request('/api/bookings', 'POST', booking, 201)['id']
    request('/api/bookings', 'POST', booking, 409)
    assert not next(s for s in request('/api/slots' + query) if s['hour'] == free)['available']
    if args.staff:
        rows = request('/api/bookings' + query)
        row = next(r for r in rows if r['id'] == booking_id)
        assert all(row[k] == booking[k] for k in booking), 'Schedule does not match booking'
        for status in ['attended', 'cancelled']:
            request(f'/api/bookings/{booking_id}', 'PATCH', {'status': status})
            assert next(r for r in request('/api/bookings' + query) if r['id'] == booking_id)['status'] == status
        assert next(s for s in request('/api/slots' + query) if s['hour'] == free)['available']
        print('PASS: healthz, clinics, slots, booking, duplicate 409, schedule, attended, cancelled, released slot')
    else:
        request('/schedule.html', expected=403)
        request('/api/bookings' + query, expected=403)
        request(f'/api/bookings/{booking_id}', 'PATCH', {'status': 'cancelled'}, 403)
        print('PASS: public booking flow and staff access denied; synthetic booking remains in disposable DB')


if __name__ == '__main__':
    main()
