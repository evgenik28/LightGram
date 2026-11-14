import argparse
import hashlib
import os
from pathlib import Path
import plistlib


def write_build_identity(app, architecture, diagnostics=None):
    app = Path(app)
    path = app / 'Info.plist'
    info = plistlib.loads(path.read_bytes())
    binary = app / info['CFBundleExecutable']
    info['OGLightGramBuildIdentifier'] = hashlib.sha256(binary.read_bytes()).hexdigest()[:16]
    info['OGLightGramBuildArchitecture'] = architecture
    if diagnostics is None:
        diagnostics = info.get('OGLightGramBuildDiagnostics', os.environ.get('LIGHTGRAM_DIAGNOSTICS') == '1')
    info['OGLightGramBuildDiagnostics'] = bool(diagnostics)
    path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY, sort_keys=False))
    return info['OGLightGramBuildIdentifier']


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--architecture', required=True)
    arguments = parser.parse_args()
    print(write_build_identity(arguments.app, arguments.architecture))
