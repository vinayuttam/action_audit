## [Unreleased]

## [1.0.0] - 2025-10-07

### Added
- Initial release of ActionAudit gem
- Automatic auditing of controller actions via `after_action` callback
- YAML-based audit message configuration with `config/audit.yml` files
- Multi-engine support - automatically loads audit configurations from all Rails engines
- Parameter interpolation in audit messages using controller params (e.g., `%{id}`, `%{email}`)
- Customizable log formatting via `ActionAudit.log_formatter`
- Customizable log tagging via `ActionAudit.log_tag`
- Rails engine integration for automatic configuration loading
- Comprehensive test suite with RSpec
- Rails generator for easy installation (`rails generate action_audit:install`)
- Full documentation with examples and usage patterns

### Features
- **ActiveSupport::Concern** integration for easy inclusion in controllers
- **Nested controller path support** (e.g., `Manage::AccountsController` → `manage/accounts`)
- **Error handling** for interpolation failures with graceful fallbacks
- **Request context preservation** including Rails request_id when available
- **Development mode support** with automatic configuration reloading
- **Flexible message registry** similar to I18n for consistent audit message management

### Examples
- Sample audit.yml configurations for various use cases
- Custom log formatter examples with timestamps and user information
- Multi-engine setup examples
