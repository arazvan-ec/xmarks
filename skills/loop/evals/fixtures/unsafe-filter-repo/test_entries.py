import unittest

from entries import find_by_owner, open_db


class EntriesTest(unittest.TestCase):
    def setUp(self):
        self.db = open_db()

    def test_find_by_owner_returns_that_owners_rows(self):
        rows = find_by_owner(self.db, "ops")
        self.assertEqual([r[0] for r in rows], [1, 2])

    def test_find_by_owner_unknown_owner_is_empty(self):
        self.assertEqual(find_by_owner(self.db, "nobody"), [])


if __name__ == "__main__":
    unittest.main()
