import unittest

from slugify import slugify, unique_slug


class TestSlugify(unittest.TestCase):
    def test_lowercases_and_hyphenates(self):
        self.assertEqual(slugify("El Confidencial — Portada"), "el-confidencial-portada")

    def test_strips_accents(self):
        self.assertEqual(slugify("Café Gijón"), "cafe-gijon")

    def test_unique_slug_appends_a_counter(self):
        self.assertEqual(unique_slug("Portada", {"portada"}), "portada-2")


if __name__ == "__main__":
    unittest.main()
