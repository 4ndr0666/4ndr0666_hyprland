"""Read-only probe failures are retained rather than aborting collection."""
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT=Path(__file__).resolve().parents[2]/'scripts/pi-acceptance-check.sh'

class AcceptanceCollectorTests(unittest.TestCase):
    def test_record_retains_success_failure_and_missing_command(self):
        with tempfile.TemporaryDirectory() as folder:
            result=subprocess.run(['bash','-c',
                'source "$1"; out=$2; record good printf sample; record bad sh -c "exit 7"; record missing gup-nonexistent-test-command',
                'test',str(SCRIPT),folder],capture_output=True,timeout=10)
            self.assertEqual(result.returncode,0,result.stderr)
            root=Path(folder)
            ledger=(root/'commands.tsv').read_text()
            self.assertIn('good\t0\t',ledger)
            self.assertIn('bad\t7\t',ledger)
            self.assertIn('missing\t127\t',ledger)
            self.assertEqual((root/'good.stdout').read_text(),'sample')

if __name__=='__main__': unittest.main()
