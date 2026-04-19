---
name: python-code
description: Providers guidelines on writing Python code. Use whenever writing Python code.
---



## General Guidelines

- Use functional, declarative programming.
- Avoid classes unless necessary. Using classes for Request and Response validation is fine, and using Pydantic classes is fine, and using classes which mainly hold data is fine. But classes with lots of methods should instead be functions.
- Never use `os.getenv(...)` or `os.environ.get(...)`. Use `os.environ[...]`
- Only use environment variables for secrets or things which genuinely depend on production vs staging vs local. Never use environment variables for things like toggling between models or timeouts.
- Avoid using `try: except:` blocks.
- Avoid `isinstance(...)`.
- We are using Python 3.13 so you can use type annotations. Try to avoid deprecated type annotations like `typing.List`, `typing.Dict` etc. instead prefer `list`, `dict`
- Do not use `__init__.py` files, they are not necessary.
- Avoid importing things at time-of-use. This is unnecessary and unpredictable. Keep all imports at the top of each file.
- Follow the PEP8 guidance on imports:
  - group imports into Standard library imports, Related third party imports, Local application/library specific imports. separate these groups by a single line
  - Use absolute imports. Do not use relative imports.
- Do not write docstrings or comments unless they tell you something which is not obvious from the code.
- Do not pass `httpx.AsyncClient` via function args unless necessary. Use the `async with` context manager as close to the client.get, client.post as possible.
- Do not abbreviate table names in SQL queries
- Prefer iteration and modularization over code duplication.
- Use descriptive variable names with auxiliary verbs (e.g., is_active, has_permission).
- Do not prefix function names with an underscore, there is no concept of private vs public in this codebase.
- Use lowercase with underscores for directories and files (e.g., routers/user_routes.py).  
- Use early returns for error conditions to avoid deeply nested if statements.
- Place the happy path last in the function for improved readability.
- Do not use `response_model=...` for FastAPI routes, instead annotate the return type. This is equivalent.
- Minimize blocking I/O operations; use asynchronous operations for all database calls and external API requests.
