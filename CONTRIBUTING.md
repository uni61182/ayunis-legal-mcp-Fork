# Contributing to Legal MCP

Thank you for your interest in contributing to Legal MCP! We welcome contributions from the community.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue on GitHub with:
- A clear description of the problem
- Steps to reproduce the issue
- Expected vs actual behavior
- Your environment (OS, Python version, Docker version)
- Relevant logs or error messages

### Suggesting Features

We welcome feature suggestions! Please open an issue with:
- A clear description of the feature
- The problem it solves or use case it enables
- Any implementation ideas you have

### Pull Requests

1. **Fork the repository** and create a new branch from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write clear, readable code
   - Follow existing code style and conventions
   - Add docstrings to all functions and classes
   - Update documentation if needed

3. **Test your changes**
   ```bash
   # Run tests
   cd store && pytest

   # Run CLI tests
   pytest tests/
   ```

4. **Commit your changes**
   ```bash
   git commit -m "feat: add your feature description"
   ```

   We follow [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat:` - New features
   - `fix:` - Bug fixes
   - `docs:` - Documentation changes
   - `refactor:` - Code refactoring
   - `test:` - Test additions or changes
   - `chore:` - Maintenance tasks

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request**
   - Provide a clear description of your changes
   - Reference any related issues
   - Ensure all tests pass
   - Wait for review

## Development Setup

### Prerequisites

- Python 3.10+
- Docker and Docker Compose
- Ollama (for embeddings)

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/legal-mcp.git
   cd legal-mcp
   ```

2. **Start PostgreSQL**
   ```bash
   docker-compose up postgres -d
   ```

3. **Set up Python environment**
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

4. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your Ollama endpoint and credentials
   ```

5. **Run database migrations**
   ```bash
   cd store
   alembic upgrade head
   ```

6. **Start the Store API**
   ```bash
   cd store
   uvicorn app.main:app --reload
   ```

7. **Start the MCP Server** (in a separate terminal)
   ```bash
   cd mcp
   python -m server.main
   ```

### Using Docker

```bash
# Build and start all services
docker-compose up --build

# Run migrations
docker-compose exec store-api alembic upgrade head

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Code Style

- Follow [PEP 8](https://peps.python.org/pep-0008/) for Python code
- Use type hints where appropriate
- Write docstrings for all public functions and classes (Google style)
- Keep functions focused and single-purpose
- Add comments for complex logic

## Testing

- Write tests for new features
- Maintain or improve code coverage
- Run tests before submitting PR
- Add integration tests for API endpoints

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_repository.py
```

## Documentation

- Update README.md if you add new features
- Add docstrings to all new functions and classes
- Update API documentation if you change endpoints
- Add examples for new functionality

## Community Guidelines

- Be respectful and inclusive
- Follow our [Code of Conduct](CODE_OF_CONDUCT.md)
- Help others in discussions and issues
- Give constructive feedback in code reviews

## Questions?

If you have questions about contributing, feel free to:
- Open a GitHub issue
- Ask in pull request discussions
- Check existing issues and documentation

## License

By contributing to Legal MCP, you agree that your contributions will be licensed under the MIT License.

Thank you for contributing! 🎉
