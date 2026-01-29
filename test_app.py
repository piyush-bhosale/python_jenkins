import unittest
from app import add_numbers, subtract_numbers

class TestApp(unittest.TestCase):

    def test_add(self):
        self.assertEqual(add_numbers(2, 3), 5)

    def test_subtract(self):
        self.assertEqual(subtract_numbers(5, 3), 2)

if __name__ == "__main__":
    unittest.main()
