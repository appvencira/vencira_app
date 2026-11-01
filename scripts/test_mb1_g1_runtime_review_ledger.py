import tempfile
import unittest
from pathlib import Path
from scripts.mb1_g1_runtime_review_ledger import scan

class LedgerTests(unittest.TestCase):
    def test_runtime_scopes_and_categories(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            (root/"service.py").write_text(
                "def write(db):\n    db.execute('SELECT 1')\n    db.save()\n    getattr(db, 'run')\n",encoding="utf-8")
            (root/"test_service.py").write_text("x.save()\n",encoding="utf-8")
            files,rows=scan(root)
            self.assertEqual(files,2)
            self.assertEqual(len(rows),3)
            self.assertEqual({r["category"] for r in rows},
                             {"SQL_REVIEW","ORM_REVIEW","DYNAMIC_REVIEW"})
            self.assertTrue(all(r["review_status"]=="PENDING" for r in rows))
            self.assertTrue(all(r["scope"]=="write" for r in rows))
    def test_invalid_root_rejected(self):
        with self.assertRaises(ValueError):
            scan("/nonexistent-g1-test-directory")
    def test_syntax_error_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp)/"broken.py").write_text("def broken(:",encoding="utf-8")
            with self.assertRaisesRegex(ValueError,"G1_PARSE_OR_READ_ERROR"):
                scan(tmp)

if __name__=="__main__":
    unittest.main()
