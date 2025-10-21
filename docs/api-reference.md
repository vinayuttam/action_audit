# API Reference

Complete API documentation for the ActionAudit gem.

## Module: ActionAudit

The main module that provides auditing functionality when included in controllers.

### Class Methods

#### `ActionAudit.log_formatter`

**Type:** `Proc` or `nil`

**Description:** Custom formatter for audit log messages.

**Signature:**
```ruby
ActionAudit.log_formatter = ->(controller_path, action_name, interpolated_message) { "formatted string" }
```

**Parameters:**
- `controller_path` (String): The normalized controller path (e.g., "admin/users")
- `action_name` (String): The controller action name (e.g., "create")
- `interpolated_message` (String): The audit message with parameters interpolated

**Returns:** String that will be logged

**Default:** `nil` (uses default formatting)

**Example:**
```ruby
ActionAudit.log_formatter = lambda do |controller, action, message|
  "[#{Time.current.iso8601}] #{controller}/#{action} | #{message}"
end
```

#### `ActionAudit.log_tag`

**Type:** `String`, `Array`, or `nil`

**Description:** Tag(s) to be used with `Rails.logger.tagged()`.

**Default:** `nil` (no tagging)

**Examples:**
```ruby
ActionAudit.log_tag = "AUDIT"
ActionAudit.log_tag = ["AUDIT", "SECURITY"]
ActionAudit.log_tag = nil  # Disable tagging
```

### Instance Methods (Private)

These methods are automatically added to controllers when `ActionAudit` is included.

#### `audit_request`

**Description:** The main auditing method called via `after_action` callback.

**Behavior:**
1. Determines controller path and action name
2. Looks up audit message from configuration
3. Interpolates message with controller parameters
4. Logs the formatted message

**Called automatically:** Yes (via `after_action`)

#### `interpolate_message(message, params)`

**Description:** Interpolates audit message with controller parameters.

**Parameters:**
- `message` (String): The audit message template
- `params` (ActionController::Parameters): Controller parameters for interpolation

**Returns:** String with interpolated values

**Error Handling:**
- Missing parameters: Logs interpolation error alongside original message
- Invalid message types: Converts to string

---

## Class: ActionAudit::AuditMessages

Registry class for managing audit messages, similar to I18n backend.

### Class Methods

#### `messages`

**Returns:** Hash containing all loaded audit messages

**Example:**
```ruby
ActionAudit::AuditMessages.messages
# => {
#   "admin" => {
#     "users" => {
#       "create" => "Created user %{email}"
#     }
#   }
# }
```

#### `lookup(controller_path, action_name)`

**Description:** Look up an audit message for a specific controller/action combination.

**Parameters:**
- `controller_path` (String): Controller path (e.g., "admin/users")
- `action_name` (String): Action name (e.g., "create")

**Returns:** String message template or `nil` if not found

**Example:**
```ruby
ActionAudit::AuditMessages.lookup("admin/users", "create")
# => "Created user %{email}"

ActionAudit::AuditMessages.lookup("nonexistent", "action")
# => nil
```

#### `load_from_file(file_path)`

**Description:** Load audit messages from a YAML file.

**Parameters:**
- `file_path` (String): Absolute path to YAML file

**Behavior:**
- Merges loaded messages with existing ones
- Handles missing files gracefully
- Validates YAML structure

**Example:**
```ruby
ActionAudit::AuditMessages.load_from_file("/path/to/audit.yml")
```

#### `load_from_engines`

**Description:** Automatically discover and load audit messages from all Rails engines.

**Behavior:**
- Loads from main application `config/audit.yml`
- Loads from each mounted engine's `config/audit.yml`
- Called automatically during Rails initialization

**Example:**
```ruby
ActionAudit::AuditMessages.load_from_engines
```

#### `add_message(controller_path, action_name, message)`

**Description:** Programmatically add an audit message.

**Parameters:**
- `controller_path` (String): Controller path (e.g., "admin/users")
- `action_name` (String): Action name (e.g., "create")
- `message` (String): Audit message template

**Example:**
```ruby
ActionAudit::AuditMessages.add_message("admin/users", "create", "Created user %{email}")
```

#### `clear!`

**Description:** Clear all loaded audit messages. Primarily used for testing.

**Example:**
```ruby
ActionAudit::AuditMessages.clear!
ActionAudit::AuditMessages.messages
# => {}
```

---

## Class: ActionAudit::Engine

Rails engine that provides automatic configuration loading and integration.

### Behavior

- **Namespace:** Isolated as `ActionAudit`
- **Initializer:** Runs after `:load_config_initializers`
- **Development Mode:** Automatically reloads configurations when files change
- **Integration:** Seamlessly integrates with Rails application and engines

### Initializers

#### `action_audit.load_audit_messages`

Automatically loads audit messages from all engines during Rails startup.

#### Development Mode Configuration

In development mode, configurations are reloaded on each request to support hot reloading.

---

## Configuration File Format

### YAML Structure

Audit messages are defined in `config/audit.yml` using nested YAML structure:

```yaml
# Top-level keys are controller namespaces or direct controllers
namespace:
  controller:
    action: "Message template with %{parameter}"

# Examples:
admin:
  users:
    create: "Admin created user %{email}"
    update: "Admin updated user %{id}"

sessions:
  create: "User logged in with %{email}"
  destroy: "User logged out"
```

### Controller Path Mapping

Controller class names are automatically converted to audit message paths:

| Controller Class | Audit Path |
|------------------|------------|
| `UsersController` | `users` |
| `Admin::UsersController` | `admin/users` |
| `API::V1::WebhooksController` | `api/v1/webhooks` |
| `Manage::Settings::PreferencesController` | `manage/settings/preferences` |

### Parameter Interpolation

Use `%{parameter_name}` syntax for parameter interpolation:

```yaml
users:
  create: "Created user %{email} with role %{role}"
  update: "Updated user %{id}"
  destroy: "Deleted user %{id}"
```

**Supported Parameter Sources:**
- Direct controller parameters (`params[:email]`)
- Nested parameters (automatically flattened)
- Strong parameters (converted safely)

---

## Error Handling

### Missing Messages

If no audit message is configured for a controller/action:
- **Behavior:** No log entry is created (silent skip)
- **Impact:** No performance penalty or errors

### Missing Parameters

If a parameter referenced in the message template is missing:
- **Behavior:** Original message is logged with error information
- **Format:** `"Original message (interpolation error: key{param} not found)"`
- **Impact:** Audit still occurs with error context

### Invalid YAML

If `config/audit.yml` has syntax errors:
- **Behavior:** Rails logs warning during startup
- **Impact:** That particular configuration file is skipped
- **Recovery:** Fix YAML syntax and restart (or reload in development)

### File System Issues

If audit configuration files are unreadable:
- **Behavior:** Files are silently skipped
- **Impact:** Only affects that specific engine's configuration
- **Recovery:** Fix file permissions and restart

---

## Performance Characteristics

### Memory Usage

- **Message Storage:** All audit messages loaded into memory at startup
- **Typical Usage:** < 1MB for large applications with extensive audit configurations
- **Scaling:** Linear with number of configured audit messages

### Runtime Performance

- **Message Lookup:** O(1) hash lookup by controller path and action
- **Parameter Interpolation:** Standard Ruby string interpolation performance
- **Logging Overhead:** Equivalent to standard Rails logging

### Initialization Time

- **Configuration Loading:** O(n) where n is number of engines with audit configs
- **YAML Parsing:** Standard Ruby YAML parsing performance
- **Typical Impact:** < 100ms additional startup time

---

## Testing Support

### RSpec Integration

ActionAudit works seamlessly with RSpec controller tests:

```ruby
RSpec.describe UsersController, type: :controller do
  describe "#create" do
    it "logs user creation" do
      expect(Rails.logger).to receive(:info).with(/Created user.*john@example\.com/)
      post :create, params: { user: { email: "john@example.com" } }
    end
  end
end
```

### Test Configuration

For testing environments:

```ruby
# In test environment
ActionAudit::AuditMessages.clear!  # Clear messages
ActionAudit.log_formatter = nil    # Use default formatting
ActionAudit.log_tag = nil          # Disable tagging
```

### Stubbing

To disable auditing in specific tests:

```ruby
before do
  allow(controller).to receive(:audit_request)
end
```

---

## Thread Safety

ActionAudit is thread-safe:

- **Message Registry:** Read-only after initialization
- **Configuration Loading:** Happens during Rails initialization (single-threaded)
- **Runtime Usage:** No shared mutable state during request processing

---

## Rails Version Compatibility

| Rails Version | ActionAudit Support |
|---------------|-------------------|
| 6.0.x | ✅ Fully supported |
| 6.1.x | ✅ Fully supported |
| 7.0.x | ✅ Fully supported |
| 7.1.x | ✅ Fully supported |
| 8.0.x | ✅ Fully supported |

---

## Ruby Version Compatibility

| Ruby Version | ActionAudit Support |
|-------------|-------------------|
| 3.1.x | ✅ Fully supported |
| 3.2.x | ✅ Fully supported |
| 3.3.x | ✅ Fully supported |

---

## Dependencies

### Runtime Dependencies

- **Rails** (`>= 6.0`): Core Rails framework
- **ActiveSupport** (`>= 6.0`): For `Concern` and core extensions

### Development Dependencies

- **RSpec** (`~> 3.0`): Testing framework
- **RSpec-Rails** (`~> 6.0`): Rails integration for RSpec

---

## Migration from Other Solutions

### From Manual Logging

```ruby
# Before: Manual logging
def create
  @user = User.create!(user_params)
  Rails.logger.info "Created user #{@user.email}"
end

# After: ActionAudit
class UsersController < ApplicationController
  include ActionAudit

  def create
    @user = User.create!(user_params)
    # Automatic logging via audit.yml configuration
  end
end
```

### From Other Audit Gems

ActionAudit provides a lightweight, configuration-based approach compared to database-backed audit solutions. Migration typically involves:

1. Configuring audit messages in YAML
2. Including `ActionAudit` in controllers
3. Removing previous audit gem dependencies

---

## Next Steps

- [See real-world examples](examples.md)
- [Learn about troubleshooting](troubleshooting.md)
- [Check installation guide](installation.md)
