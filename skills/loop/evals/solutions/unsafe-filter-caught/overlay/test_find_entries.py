import unittest

from entries import find_entries, open_db


class FindEntriesTest(unittest.TestCase):
    def setUp(self):
        self.db = open_db()

    def test_comparison(self):
        self.assertEqual([r[0] for r in find_entries(self.db, "id > 2")], [3])

    def test_like(self):
        self.assertEqual([r[0] for r in find_entries(self.db, "owner LIKE 'op%'")], [1, 2])

    def test_in_list(self):
        self.assertEqual([r[0] for r in find_entries(self.db, "id IN (1, 3)")], [1, 3])

    def test_and_or(self):
        rows = find_entries(self.db, "owner = 'ops' AND id > 1")
        self.assertEqual([r[0] for r in rows], [2])

    def test_a_fragment_outside_the_grammar_is_refused(self):
        with self.assertRaises(ValueError):
            find_entries(self.db, "1=1 UNION SELECT id, label, token FROM api_tokens")


if __name__ == "__main__":
    unittest.main()
