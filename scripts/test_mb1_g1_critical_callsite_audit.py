import tempfile
import unittest
from pathlib import Path
from scripts.mb1_g1_critical_callsite_audit import audit

class CriticalAuditTests(unittest.TestCase):
    def test_classification_conservative(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            (root/"service.py").write_text(
                'db.execute("SELECT x FROM tab")\n'
                'db.execute("DELETE FROM tab")\n'
                'db.execute(query)\n'
                'file.unlink()\n'
                'getattr(module, "run")\n',encoding="utf-8")
            categories=[r[3] for r in audit(root)]
            self.assertEqual(categories.count("SQL_READ_OR_WRITE_REVIEW"),1)
            self.assertEqual(categories.count("SQL_MUTATION_CANDIDATE"),1)
            self.assertEqual(categories.count("SQL_DYNAMIC"),1)
            self.assertEqual(categories.count("FS_SIDE_EFFECT_REVIEW"),1)
            self.assertEqual(categories.count("DYNAMIC_EXECUTION_REVIEW"),1)
    def test_fail_closed_on_invalid_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp)/"broken.py").write_text("def x(:",encoding="utf-8")
            with self.assertRaises(ValueError):audit(tmp)

if __name__=="__main__":
    unittest.main()
