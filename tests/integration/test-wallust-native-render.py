#!/usr/bin/env python3
"""Real Wallust 3.5.2 renderer gate; no GUI, user config or mocked renderer."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary', required=True, type=Path)
    parser.add_argument('--evidence', type=Path)
    args = parser.parse_args()
    binary = args.binary.resolve()
    evidence = args.evidence
    if evidence:
        evidence.mkdir(parents=True, exist_ok=True)
    commands = []
    def run(label, argv, env=None):
        result = subprocess.run([str(x) for x in argv], env=env, capture_output=True, timeout=120)
        commands.append(dict(label=label, argv=[str(x) for x in argv], exit_code=result.returncode,
                             stdout_sha256=hashlib.sha256(result.stdout).hexdigest(),
                             stderr_sha256=hashlib.sha256(result.stderr).hexdigest()))
        if evidence:
            (evidence / (label + '.stdout')).write_bytes(result.stdout)
            (evidence / (label + '.stderr')).write_bytes(result.stderr)
        return result
    version = run('version', [binary, '--version'])
    assert version.returncode == 0 and re.match(rb'wallust 3\.5\.2(?:\s|$)', version.stdout), 'Wrong native test renderer version'
    with tempfile.TemporaryDirectory(prefix='wallust native profile ') as directory:
        home = Path(directory)
        config = home / '.config'
        shutil.copytree(ROOT / 'config', config, symlinks=True)
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_CACHE_HOME=str(home / '.cache'),
                   XDG_DATA_HOME=str(home / '.local/share'), XDG_STATE_HOME=str(home / '.local/state'))
        manifest = config / 'wallust/wallust.toml'
        original = manifest.read_text()
        parsed = tomllib.loads(original)
        # A successful render must create fresh files rather than passing by
        # inspecting committed sample colors. Existing unrelated files stay in
        # this explicitly disposable private test profile only.
        outputs = {}
        for name, template in parsed['templates'].items():
            target = template['target']
            assert target.startswith('~/.config/') and '..' not in Path(target).parts
            output = home / target[2:]
            assert output.resolve().is_relative_to(home.resolve())
            if output.exists():
                assert output.is_file() and not output.is_symlink()
                output.unlink()
            outputs[name] = output
        image = config / 'hypr/wallpaper_effects/.wallpaper_current'
        assert parsed['palette'] == 'saliencedark'
        manifest.write_text(re.sub(r'(?m)^palette\s*=.*$', 'palette = "salience"', original))
        negative = run('invalid-palette-negative-control', [binary, 'run', '-s', image], env)
        assert negative.returncode != 0 and b'unknown variant `salience`' in negative.stderr
        assert not any(path.exists() for path in outputs.values())
        manifest.write_text(original)
        actual = run('render', [binary, 'run', '-s', image], env)
        assert actual.returncode == 0, actual.stderr.decode(errors='replace')
        rendered = {}
        for name, output in outputs.items():
            assert output.is_file() and output.stat().st_size > 0, name
            content = output.read_bytes()
            assert b'{{' not in content and b'}}' not in content, name
            rendered[name] = dict(target=parsed['templates'][name]['target'], sha256=hashlib.sha256(content).hexdigest(), bytes=len(content))
        assert len(rendered) == 7
        report = dict(renderer=version.stdout.decode().strip(), binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                      commands=commands, rendered=rendered, scope='Native host renderer/config/template compatibility; no ARM or GUI acceptance claim')
        if evidence:
            (evidence / 'native-render.json').write_text(json.dumps(report, indent=2) + '\n')
        print('Real Wallust 3.5.2 render: 7 fresh outputs verified; invalid palette negative control rejected.')

if __name__ == '__main__':
    main()
