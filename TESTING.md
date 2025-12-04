# Testing Guide

This document explains how to run tests for the legal-mcp project.

## Test Structure

The project uses unit tests only:

### Unit Tests
- **Location**: `store/tests/test_*.py` (marked with `@pytest.mark.unit`)
- **Requirements**: None (use mocked dependencies)
- **Speed**: Fast (~0.5s for 51 tests)
- **Purpose**: Test business logic in isolation

## Running Tests

### Prerequisites

Install dependencies:
```bash
pip install -r requirements.txt
```

### Run All Tests

```bash
pytest
```

or

```bash
pytest -m unit
```

All tests use mocked dependencies, so no database is required.

### Run Specific Test File

```bash
pytest store/tests/test_repository.py -v
```

### Run Specific Test

```bash
pytest store/tests/test_repository.py::TestLegalTextRepository::test_add_legal_text -v
```

## Test Configuration

Test configuration is in `pytest.ini`:

- **Test discovery**: Looks for `test_*.py` files in `store/tests/`
- **Markers**: `unit` for categorizing tests
- **Asyncio mode**: Auto-detects async tests

## Test Isolation

- **Unit tests**: Each test uses fresh mocks (no cleanup needed)

## Writing New Tests

### Unit Test Example

```python
import pytest
from unittest.mock import AsyncMock

@pytest.mark.unit
def test_my_function(mock_repository):
    """Test description"""
    mock_repository.method.return_value = expected_value
    result = my_function(mock_repository)
    assert result == expected_value
```

## Coverage

To generate test coverage report:

```bash
pytest --cov=app --cov-report=html
```

Open `htmlcov/index.html` to view coverage details.
