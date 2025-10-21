# Installation Guide

This guide will walk you through installing and setting up ActionAudit in your Rails application.

## Prerequisites

- Rails 6.0 or higher
- Ruby 3.1.0 or higher

## Installation

### 1. Add to Gemfile

Add ActionAudit to your application's Gemfile:

```ruby
gem 'action_audit'
```

Then execute:

```bash
bundle install
```

### 2. Run the Generator

ActionAudit provides a Rails generator to set up the initial configuration:

```bash
rails generate action_audit:install
```

This generator will create:
- `config/audit.yml` - Your audit message configuration file
- `config/initializers/action_audit.rb` - Configuration for custom formatting and tagging

### 3. Include in Controllers

Add ActionAudit to your controllers. You can include it in your `ApplicationController` to enable auditing across all controllers:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include ActionAudit

  # Your existing code...
end
```

Or include it in specific controllers:

```ruby
# app/controllers/admin/users_controller.rb
class Admin::UsersController < ApplicationController
  include ActionAudit

  # Your controller actions...
end
```

### 4. Configure Audit Messages

Edit the generated `config/audit.yml` file to define your audit messages:

```yaml
# config/audit.yml
admin:
  users:
    create: "Created user %{email}"
    update: "Updated user %{id}"
    destroy: "Deleted user %{id}"

sessions:
  create: "User logged in with %{email}"
  destroy: "User logged out"
```

### 5. Test Your Setup

Start your Rails server and trigger a controller action that should be audited. Check your Rails logs for audit entries.

## Verification

To verify that ActionAudit is working correctly:

1. Start your Rails console:
   ```bash
   rails console
   ```

2. Check that audit messages are loaded:
   ```ruby
   ActionAudit::AuditMessages.lookup("admin/users", "create")
   # Should return: "Created user %{email}"
   ```

3. Test in your application by triggering an audited action and checking the logs.

## Next Steps

- [Configure custom logging](configuration.md)
- [Learn about usage patterns](usage.md)
- [Set up multi-engine auditing](multi-engine.md)

## Troubleshooting

If you encounter issues during installation:

1. **Missing audit messages**: Ensure your `config/audit.yml` file exists and has the correct YAML structure
2. **No log output**: Check that you've included `ActionAudit` in your controllers
3. **Rails engine issues**: See the [Multi-Engine Setup Guide](multi-engine.md)

For more detailed troubleshooting, see the [Troubleshooting Guide](troubleshooting.md).
