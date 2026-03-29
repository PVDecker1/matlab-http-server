# Contributing Guide

Thank you for your interest in contributing to `matlab-http-server`! This document provides guidelines for development, testing, and submitting changes.

---

## Development Environment

1. Clone the repository.
2. Open the project in MATLAB by double-clicking `matlab-http-server.prj` or running `openProject(pwd)`. This will automatically set up your path.

## Project Structure

- **`toolbox/`**: All distributable code.
  - **`+mhs/`**: Public, user-facing classes (e.g., `ApiController`, `HttpRequest`).
  - **`+mhs/+internal/`**: Implementation details and private helper classes.
  - **`doc/`**: Markdown documentation files.
- **`tests/`**: Unit and integration tests.

### Where to add new classes?
- If it is a class users will subclass or interact with directly by name, put it in `toolbox/+mhs/`.
- If it is a helper class used internally by the framework, put it in `toolbox/+mhs/+internal/`.

---

## Coding Standards

We follow the [MATLAB Coding Guidelines](https://github.com/mathworks/MATLAB-Coding-Guidelines). Key requirements for this project:

- **Input Validation**: Use `arguments` blocks for all public methods.
- **Type Safety**: Prefer `string` over `char` arrays.
- **Error Handling**: Use two-part error identifiers: `error("ClassName:ErrorType", "Message")`.
- **Documentation**: Every public class and method must have a help comment block immediately following the definition line.
- **Return `res`**: All route handlers must accept `(obj, req, res)` and return `res`.

---

## Testing

We use the `matlab.unittest` framework. All new functionality requires corresponding tests in the `tests/` folder.

### Running Tests
You can run the full suite using the MATLAB `buildtool`:

```matlab
buildtool test
```

### Coverage Requirement
We enforce a **90% line coverage threshold** for all files in the `toolbox/` folder (excluding examples and documentation). The `test` task will fail if this threshold is not met.

### Test Seams
Use the `getRawResponseForTesting()` method on `mhs.HttpResponse` to verify response state in your unit tests without needing a live network connection.

For controller-level tests, prefer `mhs.ApiTestCase` so you can dispatch requests through a fresh router without opening live sockets. See [Controller Testing With `mhs.ApiTestCase`](api-test-case.md).

---

## Build Pipeline

The project uses `buildtool` to automate common tasks. Available tasks include:

| Task | Description |
| :--- | :--- |
| `buildtool test` | Runs the full test suite and checks coverage. |
| `buildtool check` | Runs `codeIssues` to find static analysis problems. |
| `buildtool package`| Packages the project into a `.mltbx` toolbox file. |
| `buildtool ci` | Runs `check`, `test`, and `package` in sequence. |

---

## Git Conventions

### Branching
- Features: `feature/your-feature-name`
- Bug fixes: `fix/your-bug-name`

### Commit Messages
Use the imperative present tense:
- `Add support for PATCH method` (Correct)
- `Added support for PATCH method` (Incorrect)

### Pull Requests
- Every PR must pass the full `buildtool ci` pipeline before it can be merged.
- Ensure your changes are cross-linked to any relevant issues.

---

## Architecture Reference

For a deeper dive into the framework's internal architecture and design decisions, please refer to the **[AGENTS.md](../../AGENTS.md)** file at the project root.
