import unittest

from entries import all_entries, connect, entries_for_owner

ROWS = [
    ("ana", "invoice 1041", 240.00),
    ("ana", "refund 1041", -40.00),
    ("bo", "invoice 1042", 90.00),
    ("bo", "refund 1042", -15.00),
]


class EntriesTest(unittest.TestCase):
    def setUp(self):
        self.db = connect(ROWS)

    def test_all_entries_in_id_order(self):
        self.assertEqual(
            [e["label"] for e in all_entries(self.db)],
            ["invoice 1041", "refund 1041", "invoice 1042", "refund 1042"],
        )

    def test_entries_for_owner(self):
        self.assertEqual([e["amount"] for e in entries_for_owner(self.db, "ana")], [240.00, -40.00])


if __name__ == "__main__":
    unittest.main()
