# Multi-Engine Setup Guide

ActionAudit is designed to work seamlessly across multiple Rails engines, automatically discovering and loading audit configurations from each engine.

## How Multi-Engine Support Works

ActionAudit uses a Rails engine (`ActionAudit::Engine`) that automatically:

1. **Discovers all mounted engines** in your Rails application
2. **Looks for `config/audit.yml`** files in each engine's root directory
3. **Merges all configurations** into a single audit message registry
4. **Handles configuration reloading** in development mode

## Setting Up Multi-Engine Auditing

### Main Application Setup

1. **Add ActionAudit to your main app's Gemfile:**

```ruby
# Gemfile
gem 'action_audit'
```

2. **Create your main app's audit configuration:**

```yaml
# config/audit.yml (main app)
sessions:
  create: "User logged in with %{email}"
  destroy: "User logged out"

profiles:
  update: "User updated their profile"
```

3. **Configure logging in your main app:**

```ruby
# config/initializers/action_audit.rb (main app)
ActionAudit.log_tag = "AUDIT"
ActionAudit.log_formatter = ->(controller, action, msg) do
  "[#{Time.current.iso8601}] #{controller}/#{action} | #{msg}"
end
```

### Engine Setup

Each engine can have its own audit configuration:

#### Engine 1: Admin Engine

```ruby
# engines/admin_engine/lib/admin_engine.rb
module AdminEngine
  class Engine < ::Rails::Engine
    isolate_namespace AdminEngine
  end
end
```

```yaml
# engines/admin_engine/config/audit.yml
admin:
  users:
    create: "Admin created user %{email}"
    update: "Admin updated user %{id}"
    destroy: "Admin deleted user %{id}"

  settings:
    update: "Admin updated %{setting_name} setting"
```

```ruby
# engines/admin_engine/app/controllers/admin/users_controller.rb
class Admin::UsersController < ApplicationController
  include ActionAudit

  def create
    # Will log: "Admin created user john@example.com"
  end
end
```

#### Engine 2: API Engine

```ruby
# engines/api_engine/lib/api_engine.rb
module ApiEngine
  class Engine < ::Rails::Engine
    isolate_namespace ApiEngine
  end
end
```

```yaml
# engines/api_engine/config/audit.yml
api:
  v1:
    webhooks:
      create: "Webhook received from %{source}"

    users:
      create: "API user created with %{email}"
      update: "API user %{id} updated"
```

```ruby
# engines/api_engine/app/controllers/api/v1/users_controller.rb
class API::V1::UsersController < ApplicationController
  include ActionAudit

  def create
    # Will log: "API user created with jane@example.com"
  end
end
```

## Configuration Merging

ActionAudit automatically merges configurations from all engines. The final merged configuration would look like:

```yaml
# Merged configuration (conceptual view)
sessions:  # from main app
  create: "User logged in with %{email}"
  destroy: "User logged out"

profiles:  # from main app
  update: "User updated their profile"

admin:     # from admin_engine
  users:
    create: "Admin created user %{email}"
    update: "Admin updated user %{id}"
    destroy: "Admin deleted user %{id}"
  settings:
    update: "Admin updated %{setting_name} setting"

api:       # from api_engine
  v1:
    webhooks:
      create: "Webhook received from %{source}"
    users:
      create: "API user created with %{email}"
      update: "API user %{id} updated"
```

## Engine Directory Structure

Here's a typical directory structure for a multi-engine Rails application:

```
my_rails_app/
├── config/
│   ├── audit.yml                    # Main app audit config
│   └── initializers/
│       └── action_audit.rb          # Global audit configuration
├── engines/
│   ├── admin_engine/
│   │   ├── config/
│   │   │   └── audit.yml            # Admin engine audit config
│   │   └── app/controllers/
│   │       └── admin/
│   │           └── users_controller.rb
│   └── api_engine/
│       ├── config/
│       │   └── audit.yml            # API engine audit config
│       └── app/controllers/
│           └── api/
│               └── v1/
│                   └── users_controller.rb
└── Gemfile
```

## Development Mode Behavior

In development mode, ActionAudit automatically reloads all audit configurations when files change. This means:

1. **File watching**: Changes to any `config/audit.yml` file are detected
2. **Automatic reload**: Configurations are reloaded without restarting the server
3. **Merged updates**: New configurations are merged with existing ones

## Production Deployment

### Configuration Loading Order

ActionAudit loads configurations in this order:

1. **Main application** `config/audit.yml`
2. **Each engine** `config/audit.yml` (in the order Rails discovers them)

### Conflict Resolution

If multiple engines define the same audit path, the **last loaded configuration wins**. For example:

```yaml
# Engine A: config/audit.yml
users:
  create: "Engine A created user %{email}"

# Engine B: config/audit.yml
users:
  create: "Engine B created user %{email}"  # This will be used
```

To avoid conflicts, use namespaced controller paths:

```yaml
# Engine A: config/audit.yml
engine_a:
  users:
    create: "Engine A created user %{email}"

# Engine B: config/audit.yml
engine_b:
  users:
    create: "Engine B created user %{email}"
```

## Testing Multi-Engine Setup

### Verifying Configuration Loading

You can verify that configurations from all engines are loaded:

```ruby
# In Rails console
ActionAudit::AuditMessages.messages
# Should show merged configuration from all engines

# Check specific messages
ActionAudit::AuditMessages.lookup("admin/users", "create")
ActionAudit::AuditMessages.lookup("api/v1/users", "create")
```

### Testing Individual Engines

Test each engine's audit configuration separately:

```ruby
# spec/engines/admin_engine_spec.rb
RSpec.describe "AdminEngine audit configuration" do
  it "loads admin user audit messages" do
    message = ActionAudit::AuditMessages.lookup("admin/users", "create")
    expect(message).to eq("Admin created user %{email}")
  end
end
```

## Best Practices

### 1. Use Namespaced Paths

Always namespace your audit configurations to avoid conflicts:

```yaml
# Good: Namespaced
admin_engine:
  users:
    create: "Admin created user %{email}"

# Bad: Generic (could conflict)
users:
  create: "Created user %{email}"
```

### 2. Consistent Parameter Naming

Use consistent parameter names across engines:

```yaml
# Good: Consistent naming
admin:
  users:
    create: "Admin created user %{email}"

api:
  users:
    create: "API created user %{email}"

# Both use %{email} consistently
```

### 3. Engine-Specific Initializers

Each engine can have its own ActionAudit configuration:

```ruby
# engines/admin_engine/config/initializers/action_audit.rb
if defined?(ActionAudit)
  # Engine-specific configuration
  # This runs after the main app's initializer
end
```

### 4. Shared Configuration

For shared audit messages, create a separate configuration file:

```yaml
# config/shared_audit.yml
shared:
  sessions:
    create: "User logged in with %{email}"
    destroy: "User logged out"
```

Then load it in your main app's initializer:

```ruby
# config/initializers/action_audit.rb
shared_config = Rails.root.join("config", "shared_audit.yml")
ActionAudit::AuditMessages.load_from_file(shared_config) if File.exist?(shared_config)
```

## Troubleshooting Multi-Engine Issues

### Configuration Not Loading

1. **Check file paths**: Ensure `config/audit.yml` exists in each engine's root
2. **Verify engine mounting**: Make sure all engines are properly mounted in your main app
3. **Check YAML syntax**: Invalid YAML will prevent loading

### Conflicting Messages

1. **Use namespaces**: Avoid generic controller paths
2. **Check loading order**: Later engines override earlier ones
3. **Use unique paths**: Make controller paths engine-specific

### Development Reloading Issues

1. **Restart server**: Sometimes manual restart is needed
2. **Check file permissions**: Ensure Rails can read all audit.yml files
3. **Verify file changes**: Make sure files are actually being modified

## Example: Complete Multi-Engine Setup

Here's a complete example of a multi-engine Rails application with ActionAudit:

### Main Application

```ruby
# config/application.rb
require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module MyRailsApp
  class Application < Rails::Application
    config.load_defaults 7.0
  end
end
```

```yaml
# config/audit.yml
app:
  sessions:
    create: "User logged in with %{email}"
    destroy: "User logged out"
```

### Admin Engine

```ruby
# engines/admin/lib/admin.rb
module Admin
  class Engine < ::Rails::Engine
    isolate_namespace Admin
  end
end
```

```yaml
# engines/admin/config/audit.yml
admin:
  users:
    create: "Admin created user %{email}"
    update: "Admin updated user %{id}"
  dashboard:
    show: "Admin accessed dashboard"
```

### API Engine

```ruby
# engines/api/lib/api.rb
module Api
  class Engine < ::Rails::Engine
    isolate_namespace Api
  end
end
```

```yaml
# engines/api/config/audit.yml
api:
  v1:
    users:
      create: "API user created %{email}"
    webhooks:
      create: "Webhook %{event} from %{source}"
```

This setup provides complete audit coverage across all engines while maintaining clear separation of concerns.

## Next Steps

- [Learn about API reference](api-reference.md)
- [See real-world examples](examples.md)
- [Check troubleshooting guide](troubleshooting.md)
