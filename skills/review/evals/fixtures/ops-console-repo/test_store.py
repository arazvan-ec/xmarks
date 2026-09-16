import unittest

import store


class TestStore(unittest.TestCase):
    def setUp(self):
        self.db = store.open_db()

    def test_find_by_owner_returns_that_owners_entries(self):
        rows = store.find_by_owner(self.db, "ops")
        self.assertEqual([r[0] for r in rows], [1, 2])

    def test_find_by_owner_is_empty_for_an_unknown_owner(self):
        self.assertEqual(store.find_by_owner(self.db, "nobody"), [])

    def test_entry_returns_one_row(self):
        self.assertEqual(store.entry(self.db, 3)[2], "photo-sync")


if __name__ == "__main__":
    unittest.main()
