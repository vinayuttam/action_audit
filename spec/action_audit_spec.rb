# frozen_string_literal: true

RSpec.describe ActionAudit do
  let(:logger) { double("Logger", info: nil, tagged: nil) }

  before do
    # Mock Rails logger
    allow(Rails).to receive(:logger).and_return(logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:tagged).and_yield

    # Clear any existing configuration
    ActionAudit.log_formatter = nil
    ActionAudit.log_tag = nil
    ActionAudit::AuditMessages.clear!
  end

  it "has a version number" do
    expect(ActionAudit::VERSION).not_to be nil
  end

  describe "configuration" do
    it "allows setting log_formatter" do
      formatter = ->(controller, action, msg) { "Custom: #{msg}" }
      ActionAudit.log_formatter = formatter
      expect(ActionAudit.log_formatter).to eq(formatter)
    end

    it "allows setting log_tag" do
      ActionAudit.log_tag = "AUDIT"
      expect(ActionAudit.log_tag).to eq("AUDIT")
    end
  end

  describe ActionAudit::AuditMessages do
    describe ".add_message" do
      it "stores messages for simple controller paths" do
        ActionAudit::AuditMessages.add_message("posts", "create", "Created post %{title}")
        message = ActionAudit::AuditMessages.lookup("posts", "create")
        expect(message).to eq("Created post %{title}")
      end

      it "stores messages for nested controller paths" do
        ActionAudit::AuditMessages.add_message("manage/accounts", "create", "Created account %{id}")
        message = ActionAudit::AuditMessages.lookup("manage/accounts", "create")
        expect(message).to eq("Created account %{id}")
      end
    end

    describe ".lookup" do
      before do
        ActionAudit::AuditMessages.add_message("manage/accounts", "create", "Created account %{id}")
        ActionAudit::AuditMessages.add_message("posts", "update", "Updated post %{id}")
      end

      it "finds messages for nested paths" do
        message = ActionAudit::AuditMessages.lookup("manage/accounts", "create")
        expect(message).to eq("Created account %{id}")
      end

      it "finds messages for simple paths" do
        message = ActionAudit::AuditMessages.lookup("posts", "update")
        expect(message).to eq("Updated post %{id}")
      end

      it "returns nil for non-existent paths" do
        message = ActionAudit::AuditMessages.lookup("nonexistent", "action")
        expect(message).to be_nil
      end

      it "returns nil for non-existent actions" do
        message = ActionAudit::AuditMessages.lookup("posts", "nonexistent")
        expect(message).to be_nil
      end
    end

    describe ".load_from_file" do
      let(:temp_file) { Tempfile.new([ 'audit', '.yml' ]) }

      after { temp_file.unlink }

      it "loads messages from YAML file" do
        yaml_content = {
          'manage' => {
            'accounts' => {
              'create' => 'Created account %{id}',
              'update' => 'Updated account %{id}'
            }
          }
        }

        temp_file.write(yaml_content.to_yaml)
        temp_file.rewind

        ActionAudit::AuditMessages.load_from_file(temp_file.path)

        expect(ActionAudit::AuditMessages.lookup("manage/accounts", "create")).to eq("Created account %{id}")
        expect(ActionAudit::AuditMessages.lookup("manage/accounts", "update")).to eq("Updated account %{id}")
      end
    end
  end

  describe "concern behavior" do
    let(:controller_class) do
      Class.new do
        # Mock the after_action method
        def self.after_action(method_name)
          # Store the callback for testing
          @after_action_callback = method_name
        end

        def self.after_action_callback
          @after_action_callback
        end

        include ActionAudit

        attr_accessor :params, :action_name_value

        def initialize(params = {}, action_name = "create")
          # Convert hash to proper structure for ActionController::Parameters
          if params.is_a?(Hash)
            # Ensure all keys are strings and create Parameters object
            string_hash = {}
            params.each { |k, v| string_hash[k.to_s] = v }
            @params = ActionController::Parameters.new(string_hash)
          else
            @params = params
          end
          @action_name_value = action_name
        end

        def action_name
          @action_name_value
        end

        def self.name
          "Manage::AccountsController"
        end
      end
    end

    let(:controller) { controller_class.new({ id: "123", name: "Test Account" }, "create") }

    before do
      ActionAudit::AuditMessages.add_message("manage/accounts", "create", "Created account %{id}")
    end

    describe "#audit_request" do
      it "logs with default formatter when no custom formatter is set" do
        expect(logger).to receive(:info).with("manage/accounts/create - Created account 123")
        controller.send(:audit_request)
      end

      it "uses custom formatter when set" do
        ActionAudit.log_formatter = ->(controller, action, msg) { "CUSTOM: #{controller}/#{action} - #{msg}" }
        expect(logger).to receive(:info).with("CUSTOM: manage/accounts/create - Created account 123")
        controller.send(:audit_request)
      end

      it "uses tagged logging when log_tag is set" do
        ActionAudit.log_tag = "AUDIT"
        expect(logger).to receive(:tagged).with("AUDIT").and_yield
        expect(logger).to receive(:info).with("manage/accounts/create - Created account 123")
        controller.send(:audit_request)
      end

      it "doesn't log when no message is found" do
        controller = controller_class.new({}, "nonexistent_action")
        expect(logger).not_to receive(:info)
        controller.send(:audit_request)
      end
    end

    describe "#interpolate_message" do
      it "interpolates parameters correctly" do
        params = ActionController::Parameters.new(id: "123", name: "Test")
        message = "Created account %{id} with name %{name}"

        result = controller.send(:interpolate_message, message, params)
        expect(result).to eq("Created account 123 with name Test")
      end

      it "handles missing interpolation parameters gracefully" do
        params = ActionController::Parameters.new(id: "123")
        message = "Created account %{id} with name %{missing}"

        result = controller.send(:interpolate_message, message, params)
        expect(result).to include("interpolation error")
      end

      it "handles non-string messages" do
        params = ActionController::Parameters.new(id: "123")
        message = nil

        result = controller.send(:interpolate_message, message, params)
        expect(result).to eq("")
      end
    end
  end
end
