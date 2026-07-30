import unittest

from app import tally


class TallyTest(unittest.TestCase):
    def test_counts_rows(self):
        self.assertEqual(tally("data.csv")[0], 3)

    def test_totals_amounts(self):
        self.assertAlmostEqual(tally("data.csv")[1], 20.0)


if __name__ == "__main__":
    unittest.main()
