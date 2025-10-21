# Configuration Guide

ActionAudit provides flexible configuration options for customizing how audit messages are formatted and logged.

## Audit Messages Configuration

### Basic Structure

Audit messages are defined in `config/audit.yml` using a nested structure that mirrors your controller hierarchy:

```yaml
# config/audit.yml
namespace:
  controller:
    action: "Audit message with %{parameter} interpolation"
```

### Controller Path Mapping

ActionAudit automatically converts controller class names to audit message paths:

- `UsersController` → `users`
- `Admin::UsersController` → `admin/users`
- `API::V1::WebhooksController` → `api/v1/webhooks`

### Parameter Interpolation

Use `%{parameter_name}` syntax to interpolate controller parameters into audit messages:

```yaml
users:
  create: "Created user %{email} with role %{role}"
  update: "Updated user %{id}"
  destroy: "Deleted user %{id}"
```

The gem will automatically extract these values from `params` in your controller.

### Example Configuration

```yaml
# config/audit.yml

# Admin interface
admin:
  users:
    create: "Admin created user %{email}"
    update: "Admin updated user %{id}"
    destroy: "Admin deleted user %{id}"
    activate: "Admin activated user %{id}"
    deactivate: "Admin deactivated user %{id}"

  accounts:
    create: "Admin created account %{name}"
    update: "Admin updated account %{id} with %{name}"
    destroy: "Admin deleted account %{id}"

# User authentication
sessions:
  create: "User logged in with %{email}"
  destroy: "User %{user_id} logged out"

# API endpoints
api:
  v1:
    webhooks:
      create: "Webhook received from %{source}"
    users:
      create: "API user created via %{client_id}"

# Regular controllers
posts:
  create: "Created post '%{title}'"
  update: "Updated post %{id}"
  publish: "Published post %{id}"
  unpublish: "Unpublished post %{id}"
```

## Logging Configuration

### Custom Log Formatter

Configure custom log formatting in `config/initializers/action_audit.rb`:

```ruby
# config/initializers/action_audit.rb

# Basic custom formatter
ActionAudit.log_formatter = lambda do |controller, action, message|
  "[AUDIT] #{controller}/#{action} - #{message}"
end

# Advanced formatter with timestamp and user info
ActionAudit.log_formatter = lambda do |controller, action, message|
  timestamp = Time.current.iso8601
  user_info = defined?(current_user) && current_user ? "User: #{current_user.email}" : "User: anonymous"

  "[#{timestamp}] #{controller}/#{action} | #{message} | #{user_info}"
end

# Formatter with request ID
ActionAudit.log_formatter = lambda do |controller, action, message|
  request_id = defined?(request) && request ? request.request_id : SecureRandom.hex(8)
  "AUDIT [#{request_id}] #{controller}/#{action}: #{message}"
end
```

### Log Tagging

Add consistent tags to all audit log entries:

```ruby
# Simple tag
ActionAudit.log_tag = "AUDIT"

# Multiple tags (if your logger supports it)
ActionAudit.log_tag = ["AUDIT", "SECURITY"]

# Dynamic tag
ActionAudit.log_tag = "AUDIT-#{Rails.env.upcase}"
```

### Default Behavior

If no custom configuration is provided:

- **Default formatter**: `"#{controller_path}/#{action_name} - #{interpolated_message}"`
- **Default tag**: `nil` (no tagging)

## Configuration Examples

### Minimal Configuration

```ruby
# config/initializers/action_audit.rb
ActionAudit.log_tag = "AUDIT"
```

### Production Configuration

```ruby
# config/initializers/action_audit.rb
ActionAudit.log_tag = "AUDIT"

ActionAudit.log_formatter = lambda do |controller, action, message|
  timestamp = Time.current.iso8601
  request_id = defined?(request) && request ? request.request_id : "unknown"
  user_id = defined?(current_user) && current_user ? current_user.id : "anonymous"

  "[#{timestamp}] #{controller}/#{action} | #{message} | user_id=#{user_id} | request_id=#{request_id}"
end
```

### Development Configuration

```ruby
# config/initializers/action_audit.rb
if Rails.env.development?
  ActionAudit.log_tag = "DEV-AUDIT"

  ActionAudit.log_formatter = lambda do |controller, action, message|
    "🔍 [#{Time.current.strftime('%H:%M:%S')}] #{controller}/#{action} - #{message}"
  end
end
```

## Environment-Specific Configuration

You can configure ActionAudit differently for each environment:

```ruby
# config/initializers/action_audit.rb
case Rails.env
when 'development'
  ActionAudit.log_tag = "DEV-AUDIT"
  ActionAudit.log_formatter = ->(c, a, m) { "🔍 #{c}/#{a} - #{m}" }

when 'staging'
  ActionAudit.log_tag = "STAGING-AUDIT"
  ActionAudit.log_formatter = ->(c, a, m) { "[STAGING] #{c}/#{a} | #{m}" }

when 'production'
  ActionAudit.log_tag = "AUDIT"
  ActionAudit.log_formatter = lambda do |controller, action, message|
    timestamp = Time.current.iso8601
    "[#{timestamp}] #{controller}/#{action} | #{message}"
  end
end
```

## Integration with Structured Logging

ActionAudit works well with structured logging solutions:

```ruby
# For use with lograge or similar structured logging
ActionAudit.log_formatter = lambda do |controller, action, message|
  {
    type: 'audit',
    controller: controller,
    action: action,
    message: message,
    timestamp: Time.current.iso8601,
    user_id: defined?(current_user) && current_user&.id,
    request_id: defined?(request) && request&.request_id
  }.to_json
end
```

## Testing Configuration

In your test environment, you might want to disable or modify auditing:

```ruby
# config/environments/test.rb or config/initializers/action_audit.rb
if Rails.env.test?
  # Option 1: Disable formatting for cleaner test output
  ActionAudit.log_formatter = nil
  ActionAudit.log_tag = nil

  # Option 2: Use simple test-friendly format
  ActionAudit.log_formatter = ->(c, a, m) { "TEST_AUDIT: #{c}/#{a} - #{m}" }
end
```

## Next Steps

- [Learn about usage patterns](usage.md)
- [Set up multi-engine configuration](multi-engine.md)
- [Explore real-world examples](examples.md)
