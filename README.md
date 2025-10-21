# ActionAudit

A Rails gem that provides automatic auditing of controller actions across multiple Rails engines. ActionAudit works similar to `I18n` by loading audit messages from YAML files, but focuses on logging controller actions with customizable formatting and tagging while preserving Rails request context.

## Features

- **Automatic auditing**: Hooks into controller actions via `after_action`
- **YAML-based configuration**: Load audit messages from `config/audit.yml` files
- **Multi-engine support**: Automatically loads configurations from all Rails engines
- **Customizable formatting**: Configure custom log formatters and tags
- **Parameter interpolation**: Support for dynamic message interpolation using controller parameters
- **Rails integration**: Preserves request context including `request_id`

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'action_audit'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install action_audit

## Usage

### 1. Include in Controllers

Include the `ActionAudit` module in any controller you want to audit:

```ruby
class Manage::AccountsController < ApplicationController
  include ActionAudit

  def create
    @account = Account.create!(account_params)
    # audit_request is automatically called after this action
  end

  def update
    @account = Account.find(params[:id])
    @account.update!(account_params)
  end

  private

  def account_params
    params.require(:account).permit(:name, :email)
  end
end
```

### 2. Configure Audit Messages

Create a `config/audit.yml` file in your Rails application or engine:

```yaml
# config/audit.yml
manage:
  accounts:
    create: "Created account %{id}"
    update: "Updated account %{id} with %{name}"
    destroy: "Deleted account %{id}"
  users:
    invite: "Invited user %{email}"
    create: "Created user %{email}"

sessions:
  create: "User logged in with email %{email}"
  destroy: "User logged out"

posts:
  create: "Created post '%{title}'"
  update: "Updated post %{id}"
  publish: "Published post %{id}"
```

### 3. Customize Logging (Optional)

Create an initializer to customize the logging behavior:

```ruby
# config/initializers/action_audit.rb

# Add a custom tag to all audit logs
ActionAudit.log_tag = "AUDIT"

# Customize the log format
ActionAudit.log_formatter = lambda do |controller, action, message|
  user_info = defined?(current_user) && current_user ? "User: #{current_user.email}" : "User: anonymous"
  "[#{Time.current.iso8601}] #{controller}/#{action} | #{message} | #{user_info}"
end
```

### 4. Multi-Engine Support

ActionAudit automatically loads `config/audit.yml` files from:
- Your main Rails application
- All mounted Rails engines

Each engine can have its own audit configuration that will be merged together.

## Configuration Options

### Log Formatter

Customize how log messages are formatted:

```ruby
# Simple formatter
ActionAudit.log_formatter = ->(controller, action, msg) do
  "AUDIT: #{controller}/#{action} - #{msg}"
end

# Complex formatter with timestamp and user info
ActionAudit.log_formatter = lambda do |controller, action, message|
  timestamp = Time.current.strftime("%Y-%m-%d %H:%M:%S")
  "[#{timestamp}] AUDIT: #{controller}/#{action} - #{message}"
end
```

### Log Tag

Add a consistent tag to all audit logs:

```ruby
ActionAudit.log_tag = "AUDIT"
# or
ActionAudit.log_tag = "APP_AUDIT"
```

## Message Interpolation

Audit messages support parameter interpolation using controller params:

```yaml
# audit.yml
accounts:
  create: "Created account %{id} for %{name}"
  update: "Updated account %{id} - changed %{changed_fields}"
```

```ruby
# In your controller
def create
  @account = Account.create!(name: params[:name])
  # Will log: "Created account 123 for Acme Corp"
  # Uses params[:id] and params[:name] for interpolation
end
```

## Example Log Output

### Default Format
```
manage/accounts/create - Created account 123
manage/accounts/update - Updated account 123 with Acme Corp
sessions/create - User logged in with email john@example.com
```

### With Custom Formatter and Tag
```
[AUDIT] [2025-01-15T10:30:00Z] manage/accounts/create | Created account 123 | User: john@example.com
[AUDIT] [2025-01-15T10:31:00Z] manage/accounts/update | Updated account 123 with Acme Corp | User: john@example.com
[AUDIT] [2025-01-15T10:32:00Z] sessions/destroy | User logged out | User: john@example.com
```

## API Reference

### ActionAudit Module

When included in a controller, automatically adds:
- `after_action :audit_request` - Hooks into action completion
- `audit_request` - Private method that performs the logging
- `interpolate_message` - Private method for parameter interpolation

### ActionAudit.log_formatter

A `Proc` that receives `(controller_path, action_name, interpolated_message)` and returns a formatted string.

**Default**: `"#{controller_path}/#{action_name} - #{interpolated_message}"`

### ActionAudit.log_tag

A string tag to be used with `Rails.logger.tagged()`.

**Default**: `nil` (no tagging)

### ActionAudit::AuditMessages

Registry for audit messages with methods:
- `.lookup(controller_path, action_name)` - Find a message
- `.load_from_file(file_path)` - Load messages from YAML file
- `.load_from_engines` - Load from all Rails engines
- `.add_message(controller_path, action_name, message)` - Add a message programmatically
- `.clear!` - Clear all messages

## Documentation

For comprehensive documentation, see the [docs](docs/) directory:

- [Installation Guide](docs/installation.md) - Step-by-step setup instructions
- [Configuration Guide](docs/configuration.md) - How to configure audit messages and logging
- [Usage Guide](docs/usage.md) - How to use ActionAudit in your controllers
- [Multi-Engine Setup](docs/multi-engine.md) - Using ActionAudit across Rails engines
- [API Reference](docs/api-reference.md) - Complete API documentation
- [Examples](docs/examples.md) - Real-world usage examples
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions
- [Migration Guide](docs/migration.md) - Migrating from other audit solutions

*Documentation generated by GitHub Copilot*

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

The project uses RuboCop Rails Omakase for code style. Run `bundle exec rubocop` to check style, or `bundle exec rake` to run both tests and RuboCop checks.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/action_audit. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/action_audit/blob/main/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the ActionAudit project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/action_audit/blob/main/CODE_OF_CONDUCT.md).
