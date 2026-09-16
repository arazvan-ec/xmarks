# Usage

`slugify(title)` lowercases the title, strips accents, replaces every run of
non-alphanumeric characters with a single hyphen, and trims hyphens from both
ends.

`unique_slug(title, taken)` does the same and then appends `-2`, `-3`, … until
the result is not already in `taken`.
