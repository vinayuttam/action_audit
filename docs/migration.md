# Migration Guide

Guide for migrating from other audit solutions to ActionAudit.

## Migration Overview

ActionAudit provides a lightweight, configuration-based approach to auditing that differs from database-backed audit solutions. This guide helps you migrate from various audit gems and custom solutions.

## From Manual Logging Solutions

### Before: Manual Rails.logger Calls

```ruby
# Old approach: Manual logging in each action
class UsersController < ApplicationController
  def create
    @user = User.create!(user_params)
    Rails.logger.info "User created: #{@user.email} by #{current_user&.email}"
    redirect_to @user
  end

  def update
    @user = User.find(params[:id])
    old_email = @user.email
    @user.update!(user_params)
    Rails.logger.info "User #{@user.id} updated: #{old_email} -> #{@user.email}"
    redirect_to @user
  end

  def destroy
    @user = User.find(params[:id])
    user_email = @user.email
    @user.destroy!
    Rails.logger.info "User deleted: #{user_email} by #{current_user&.email}"
    redirect_to users_path
  end
end
```

### After: ActionAudit Configuration

```ruby
# New approach: Include ActionAudit
class UsersController < ApplicationController
  include ActionAudit

  def create
    @user = User.create!(user_params)
    # Automatic logging via audit.yml
    redirect_to @user
  end

  def update
    @user = User.find(params[:id])
    @user.update!(user_params)
    # Automatic logging via audit.yml
    redirect_to @user
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy!
    # Automatic logging via audit.yml
    redirect_to users_path
  end
end
```

```yaml
# config/audit.yml
users:
  create: "User created: %{email}"
  update: "User %{id} updated"
  destroy: "User deleted: %{id}"
```

```ruby
# config/initializers/action_audit.rb
ActionAudit.log_formatter = lambda do |controller, action, message|
  user_info = defined?(current_user) && current_user ? " by #{current_user.email}" : ""
  "#{message}#{user_info}"
end
```

**Migration Benefits:**
- **Centralized Configuration:** All audit messages in one place
- **Consistency:** Uniform message format across controllers
- **Maintainability:** Easy to update messages without touching controller code
- **DRY Principle:** No repeated logging code

## From Database Audit Gems

### From Audited Gem

The `audited` gem stores audit records in the database. ActionAudit focuses on logging instead.

#### Before: Audited Configuration

```ruby
# Gemfile
gem 'audited'

# Model
class User < ApplicationRecord
  audited only: [:name, :email], on: [:create, :update, :destroy]
end

# Querying audit records
user.audits.where(action: 'create')
user.audits.last.audited_changes
```

#### After: ActionAudit Configuration

```ruby
# Gemfile
gem 'action_audit'

# Controller
class UsersController < ApplicationController
  include ActionAudit

  def create
    @user = User.create!(user_params)
    # ActionAudit logs the action
  end
end
```

```yaml
# config/audit.yml
users:
  create: "Created user %{email} with %{name}"
  update: "Updated user %{id}: %{name}"
  destroy: "Deleted user %{id}"
```

**Key Differences:**
- **Storage:** ActionAudit uses Rails logs, not database
- **Performance:** No database writes for audit records
- **Querying:** Use log analysis tools instead of ActiveRecord queries
- **Retention:** Managed by log rotation, not database cleanup

### From PaperTrail Gem

PaperTrail tracks changes to models with database storage.

#### Migration Strategy

1. **Keep PaperTrail for data versioning**
2. **Add ActionAudit for user action logging**
3. **Use both gems for different purposes**

```ruby
# Model: Keep PaperTrail for data history
class User < ApplicationRecord
  has_paper_trail only: [:name, :email, :role]
end

# Controller: Add ActionAudit for action logging
class UsersController < ApplicationController
  include ActionAudit

  def update
    @user = User.find(params[:id])
    @user.update!(user_params)
    # PaperTrail records the data change
    # ActionAudit logs the user action
  end
end
```

**Use Cases:**
- **PaperTrail:** Data versioning, rollbacks, change history
- **ActionAudit:** User actions, security logging, compliance

## From Custom Audit Solutions

### From Service Object Pattern

```ruby
# Before: Custom audit service
class AuditService
  def self.log_user_action(action, user, target = nil)
    message = build_message(action, user, target)
    Rails.logger.info("[AUDIT] #{message}")
    AuditRecord.create!(
      action: action,
      user: user,
      target: target,
      message: message
    )
  end

  private

  def self.build_message(action, user, target)
    case action
    when :create_user
      "User #{user.email} created user #{target.email}"
    when :update_user
      "User #{user.email} updated user #{target.id}"
    # ... many more cases
    end
  end
end

# Usage in controllers
class UsersController < ApplicationController
  def create
    @user = User.create!(user_params)
    AuditService.log_user_action(:create_user, current_user, @user)
    redirect_to @user
  end
end
```

```ruby
# After: ActionAudit
class UsersController < ApplicationController
  include ActionAudit

  def create
    @user = User.create!(user_params)
    params[:created_user_email] = @user.email
    # ActionAudit handles the rest
    redirect_to @user
  end
end
```

```yaml
# config/audit.yml
users:
  create: "User created: %{created_user_email}"
  update: "User updated: %{id}"
  destroy: "User deleted: %{id}"
```

```ruby
# config/initializers/action_audit.rb
ActionAudit.log_formatter = lambda do |controller, action, message|
  user_email = defined?(current_user) && current_user ? current_user.email : "system"
  "[AUDIT] User #{user_email}: #{message}"
end
```

## Migration Steps

### Step 1: Install ActionAudit

```ruby
# Gemfile
gem 'action_audit'
```

```bash
bundle install
rails generate action_audit:install
```

### Step 2: Identify Current Audit Points

Analyze your existing codebase to find:

```bash
# Find manual logging calls
grep -r "Rails.logger.*audit\|audit.*log" app/

# Find service object calls
grep -r "AuditService\|Audit.*log" app/

# Find existing audit gem usage
grep -r "audited\|paper_trail" app/
```

### Step 3: Map to ActionAudit Configuration

Create a mapping of your current audit points:

```yaml
# config/audit.yml
# Map your existing audit points to configuration

# From: Rails.logger.info "User #{user.email} created"
users:
  create: "User created: %{email}"

# From: AuditService.log(:user_update, current_user, @user)
users:
  update: "User updated: %{id}"

# From: audit_comment: "Deleted user account"
users:
  destroy: "User deleted: %{id}"
```

### Step 4: Update Controllers Gradually

Migrate controllers one at a time:

```ruby
# Phase 1: Add ActionAudit alongside existing logging
class UsersController < ApplicationController
  include ActionAudit

  def create
    @user = User.create!(user_params)

    # Keep existing logging temporarily
    Rails.logger.info "User created: #{@user.email}"

    # ActionAudit will also log
    redirect_to @user
  end
end
```

```ruby
# Phase 2: Remove old logging after verification
class UsersController < ApplicationController
  include ActionAudit

  def create
    @user = User.create!(user_params)
    # Only ActionAudit logging now
    redirect_to @user
  end
end
```

### Step 5: Configure Custom Formatting

Match your existing log format:

```ruby
# config/initializers/action_audit.rb

# If you had: "[AUDIT] User john@example.com: Created user jane@example.com"
ActionAudit.log_formatter = lambda do |controller, action, message|
  user_email = defined?(current_user) && current_user ? current_user.email : "system"
  "[AUDIT] User #{user_email}: #{message}"
end

ActionAudit.log_tag = nil  # No additional tagging if you had custom format
```

### Step 6: Update Log Processing

If you have log processing tools, update them for ActionAudit format:

```bash
# Old log format
[AUDIT] User john@example.com created user jane@example.com

# New ActionAudit format
[AUDIT] User john@example.com: User created: jane@example.com
```

Update your log parsing scripts accordingly.

## Testing Migration

### Parallel Logging During Migration

Run both systems in parallel to verify migration:

```ruby
# Temporary parallel logging
class UsersController < ApplicationController
  include ActionAudit

  def create
    @user = User.create!(user_params)

    # Old system
    AuditService.log_user_action(:create_user, current_user, @user)

    # New system (ActionAudit automatic)

    redirect_to @user
  end
end
```

### Verification Script

```ruby
# Create: verify_migration.rb
require_relative 'config/environment'

# Test ActionAudit configuration
puts "Testing ActionAudit Configuration"
puts "=" * 40

# Check all your migrated audit points
test_cases = [
  ['users', 'create'],
  ['users', 'update'],
  ['users', 'destroy'],
  ['admin/users', 'create'],
  ['sessions', 'create']
]

test_cases.each do |controller, action|
  message = ActionAudit::AuditMessages.lookup(controller, action)
  status = message ? "✓" : "✗ MISSING"
  puts "#{status} #{controller}/#{action}: #{message}"
end

# Test parameter interpolation
puts "\nTesting Parameter Interpolation"
puts "=" * 40

sample_params = { id: 123, email: 'test@example.com', name: 'Test User' }
test_message = ActionAudit::AuditMessages.lookup('users', 'create')

if test_message
  begin
    result = test_message % sample_params.symbolize_keys
    puts "✓ Interpolation: #{result}"
  rescue KeyError => e
    puts "✗ Interpolation failed: #{e.message}"
  end
end
```

## Rollback Plan

Keep your migration reversible:

### Rollback to Manual Logging

```ruby
# Keep this code commented during migration
class UsersController < ApplicationController
  # include ActionAudit  # Comment out ActionAudit

  def create
    @user = User.create!(user_params)

    # Uncomment manual logging if needed
    Rails.logger.info "[AUDIT] User created: #{@user.email}"

    redirect_to @user
  end
end
```

### Feature Flags

Use feature flags to control migration:

```ruby
# config/initializers/action_audit.rb
if Rails.application.config.use_action_audit
  # ActionAudit configuration
  ActionAudit.log_tag = "AUDIT"
else
  # Disable ActionAudit
  module ActionAudit
    def audit_request
      # No-op when disabled
    end
  end
end
```

## Post-Migration Cleanup

### Remove Old Dependencies

```ruby
# Remove from Gemfile after successful migration
# gem 'audited'
# gem 'paper_trail'  # Only if not needed for versioning
```

### Clean Up Old Code

```bash
# Find and remove old audit service calls
grep -r "AuditService\|OldAuditGem" app/ --exclude-dir=tmp
```

### Update Documentation

Update your application documentation to reflect the new audit approach:

- How to add new audit messages
- Log format and location
- How to query audit logs
- Maintenance procedures

## Common Migration Issues

### Different Parameter Names

**Problem:** Old system used different parameter names.

```ruby
# Old system expected
AuditService.log(:user_created, user_id: @user.id, user_email: @user.email)

# ActionAudit expects params[:user_email]
```

**Solution:** Map parameters in controller:

```ruby
def create
  @user = User.create!(user_params)
  params[:user_email] = @user.email  # Map for ActionAudit
  redirect_to @user
end
```

### Complex Audit Logic

**Problem:** Old system had complex conditional audit logic.

**Solution:** Use custom formatter or controller-level logic:

```ruby
# config/initializers/action_audit.rb
ActionAudit.log_formatter = lambda do |controller, action, message|
  # Add complex logic here if needed
  if controller == 'admin/users' && sensitive_action?(action)
    alert_security_team(message)
  end

  message
end
```

### Database Audit Records

**Problem:** Need to maintain database audit records.

**Solution:** Create custom after_action alongside ActionAudit:

```ruby
class ApplicationController < ActionController::Base
  include ActionAudit

  after_action :create_audit_record, if: :should_audit_to_database?

  private

  def create_audit_record
    # Create database record if needed
    AuditRecord.create!(
      controller: self.class.name,
      action: action_name,
      user: current_user,
      timestamp: Time.current
    )
  end

  def should_audit_to_database?
    # Define when to create database records
    %w[create update destroy].include?(action_name)
  end
end
```

## Next Steps

- [See real-world examples](examples.md)
- [Check troubleshooting guide](troubleshooting.md)
- [Return to main documentation](README.md)
