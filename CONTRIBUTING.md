## How to contribute to fabric_flutter

### Quick Start

1. **Fork and clone** the repository locally
2. **Install Flutter SDK** (stable channel, `^3.12.1` or higher)
3. **Install dependencies:**
   ```bash
   flutter pub get
   ```
4. **Set up pre-commit hooks** (optional but recommended):
   ```bash
   ./scripts/install-hooks.sh
   ```
5. **Create your feature branch:**
   ```bash
   git checkout -b my-new-feature
   ```
6. **Make your changes** following the code standards below
7. **Run validation suite:**
   ```bash
   dart format .              # Format code
   flutter analyze            # Check for issues
   flutter test               # Run tests
   ```
8. **Commit your changes** with a clear message
9. **Push to your fork** and submit a pull request
10. **Wait for review** from a team member

### Code Standards

This project follows strict code quality standards. All contributions must comply with:

#### Documentation (Effective Dart)
* Use triple-slash `///` comments for all public **and private** API elements
* Start with a capitalized sentence ending with a period
* Use third-person present-tense verbs ("Builds...", "Stores...", "Provides...")
* Separate summary from details with a blank `///` line
* Use square brackets `[Type]` for type references, backticks for literals
* **NO** Javadoc-style `@param`, `@returns`, `@throws` tags - use prose instead
* Document *why*, not just *what*

#### Code Style
* **Single quotes** for strings (`prefer_single_quotes: true`)
* **NO `print()` statements** - use `debugPrint()` instead
* **Trailing commas** on all multi-line function calls
* Use `const` constructors wherever possible
* Wrap debug logging in `if (kDebugMode)` checks

#### Serialization Patterns
* Use `@JsonSerializable(explicitToJson: true)` annotations
* Make `fromJson` factories accept nullable maps: `fromJson(Map<String, dynamic>? json)`
* Use null coalescing: `_$XFromJson(json ?? {})`
* Regenerate `.g.dart` files after model changes:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

#### Testing
* Add at least one test for each bug fix or feature
* Mirror lib/ structure in test/ directory
* Use Arrange-Act-Assert pattern
* Never use real I/O (HTTP, Firebase, databases) - use mocks/fakes
* All tests must pass before submitting PR

### Pre-commit Hooks

We provide optional pre-commit hooks that automatically enforce standards:

```bash
# Install hooks (one-time setup)
./scripts/install-hooks.sh

# The hooks will automatically run on each commit:
# 1. dart format on changed files
# 2. flutter analyze
# 3. Documentation checks
```

### Validation Before Submitting

Run the full validation suite before creating a PR:

```bash
# 1. Regenerate serialized models (if you changed any)
dart run build_runner build --delete-conflicting-outputs

# 2. Format code
dart format .

# 3. Check for issues (must report zero issues)
flutter analyze

# 4. Run tests (all must pass)
flutter test
```

**CI/CD:** GitHub Actions will automatically run `flutter analyze` and `flutter test` on your PR. Ensure both pass before requesting review.

## Filing Issues

**If you are filing an issue to request a feature**, please provide a clear description of the feature. It can be helpful to describe answers to the following questions:

* Who will use the feature?
* When will they use the feature?
* What is the user’s goal?

Or... If you are filing an issue to report a bug, be sure to provide:

* A clear description of the bug and related expectations.
* A reduced test case that demonstrates the problem.

## Submitting Pull Requests

**Before creating a pull request**, ensure that an issue exists for the corresponding change in the PR that you intend to make. If an issue does not exist, please create one providing:

* A reference to the corresponding issue or issues that will be closed by the pull request.
* A succinct description of the design used to fix any related issues.
* At least one test for each bug fixed or feature added as part of the pull request.

If a proposed change contains multiple commits, please **squash commits to as few as is necessary** to succinctly express the change. 

We really appreciate your interest in contributing and improving the organization.

## Squashing commits

To squash four commits into one, do the following:

    $ git rebase -i HEAD~4

In the text editor that comes up, replace the words "pick" with "squash" next to the commits you want to squash into the commit before it. Save and close the editor, and git will combine the "squash"'ed commits with the one before it. Git will then give you the opportunity to change your commit message to something like, "Issue #100: Fixed retweet bug."

**Important**: If you've already pushed commits to GitHub, and then squash them locally, you will have to force the push to your branch.

    $ git push origin branch-name --force

Helpful hint: You can always edit your last commit message, before pushing, by using:

    $ git commit --amend

### See also:
[Git Book Chapter 6.4: Git Tools - Rewriting History](http://git-scm.com/book/en/Git-Tools-Rewriting-History)
