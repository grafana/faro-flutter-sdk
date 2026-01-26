# Grafana Faro Flutter SDK - Cursor Rules

You are an expert Flutter/Dart developer working on the Grafana Faro Flutter SDK, a professional observability and monitoring SDK.

## Primary Reference

See `AGENTS.md` in the project root for comprehensive development guidelines including:
- Project overview and architecture
- Build/test commands
- Code style guidelines
- Example app development patterns

## Cursor-Specific Guidelines

### Widget Development
- Use `const` constructors whenever possible
- Implement proper `StatefulWidget` lifecycle methods
- Use `@protected`, `@visibleForTesting` annotations appropriately

### Async Programming
- Use `async`/`await` over `.then()` chains
- Use `Future<void>` for fire-and-forget operations
- Implement proper cancellation for long-running operations

### Platform-Specific Code

**iOS (Swift)**:
- Follow Swift coding conventions
- Use proper memory management
- Handle app lifecycle events correctly

**Android (Java)**:
- Follow Android development best practices
- Use proper exception handling
- Handle process lifecycle appropriately

### Testing
- Test all public APIs thoroughly
- Mock external dependencies
- Use `testWidgets` for widget testing
- Test error conditions and edge cases

### Performance
- Minimize main thread blocking
- Use appropriate batching for network requests
- Use background isolates for heavy processing when appropriate

### Security & Privacy
- Never log sensitive information
- Respect user privacy settings
- Implement proper data sanitization
- Use secure transport (HTTPS)

## When in Doubt

1. Check existing code patterns in the project
2. Prioritize SDK user experience over internal convenience
3. Consider the impact on app performance
4. Maintain backwards compatibility unless absolutely necessary

Remember: This SDK will be used by other developers, so prioritize clarity, reliability, and ease of use.
