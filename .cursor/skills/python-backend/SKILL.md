---
name: python-backend
description: >
  Python backend development expertise for FastAPI, security patterns, database operations,
  Upstash integrations, and code quality. Use when: (1) Building REST APIs with FastAPI,
  (2) Implementing JWT/OAuth2 authentication,
  (3) Integrating Redis/Upstash caching, (4) Refactoring AI-generated Python code (deslopification).
---

# python-backend

Production-ready Python backend patterns for FastAPI, and Upstash.

## When to Use This Skill

- Building REST APIs with FastAPI
- Implementing JWT/OAuth2 authentication
- Integrating Redis/Upstash caching and rate limiting
- Refactoring AI-generated Python code

## Core Principles

1. **Async-first** - Use async/await for I/O operations
2. **Type everything** - Pydantic models for validation
3. **Dependency injection** - Use FastAPI's Depends()

## Quick Patterns

### Project Structure

```
src/
├── auth/
│   ├── router.py      # endpoints
│   ├── schemas.py     # pydantic models
│   ├── models.py      # db models
│   ├── service.py     # business logic
│   └── dependencies.py
├── posts/
│   └── ...
├── config.py
├── database.py
└── main.py
```

### Async Routes

```python
# BAD - blocks event loop
@router.get("/")
async def bad():
    time.sleep(10)  # Blocking!

# GOOD - runs in threadpool
@router.get("/")
def good():
    time.sleep(10)  # OK in sync function

# BEST - non-blocking
@router.get("/")
async def best():
    await asyncio.sleep(10)  # Non-blocking
```

### Pydantic Validation

```python
from pydantic import BaseModel, EmailStr, Field

class UserCreate(BaseModel):
    email: EmailStr
    username: str = Field(min_length=3, max_length=50, pattern="^[a-zA-Z0-9_]+$")
    age: int = Field(ge=18)
```


### Redis Caching

```python
from upstash_redis import Redis

redis = Redis.from_env()

@app.get("/data/{id}")
def get_data(id: str):
    cached = redis.get(f"data:{id}")
    if cached:
        return cached
    data = fetch_from_db(id)
    redis.setex(f"data:{id}", 600, data)
    return data
```

### Rate Limiting

```python
from upstash_ratelimit import Ratelimit, SlidingWindow

ratelimit = Ratelimit(
    redis=Redis.from_env(),
    limiter=SlidingWindow(max_requests=10, window=60),
)

@app.get("/api/resource")
def protected(request: Request):
    result = ratelimit.limit(request.client.host)
    if not result.allowed:
        raise HTTPException(429, "Rate limit exceeded")
    return {"data": "..."}
```

## Reference Documents

For detailed patterns, see:

| Document | Content |
|----------|---------|
| `references/fastapi_patterns.md` | Project structure, async, Pydantic, dependencies, testing |
| `references/upstash_patterns.md` | Redis, rate limiting, QStash background jobs |

## Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Upstash Documentation](https://upstash.com/docs)
