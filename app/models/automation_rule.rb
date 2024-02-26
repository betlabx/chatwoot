# == Schema Information
#
# Table name: automation_rules
#
#  id          :bigint           not null, primary key
#  actions     :jsonb            not null
#  active      :boolean          default(TRUE), not null
#  conditions  :jsonb            not null
#  description :text
#  event_name  :string           not null
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_automation_rules_on_account_id  (account_id)
#
class AutomationRule < ApplicationRecord
  include Rails.application.routes.url_helpers

  MAX_ERROR_THRESHOLD = 3

  belongs_to :account
  has_many_attached :files

  validate :json_conditions_format
  validate :json_actions_format
  validate :query_operator_presence
  validates :account_id, presence: true

  scope :active, -> { where(active: true) }

  def conditions_attributes
    %w[content email country_code status message_type browser_language assignee_id team_id referer city company inbox_id
       mail_subject phone_number priority conversation_language]
  end

  def actions_attributes
    %w[send_message add_label remove_label send_email_to_team assign_team assign_agent send_webhook_event mute_conversation
       send_attachment change_status resolve_conversation snooze_conversation change_priority send_email_transcript].freeze
  end

  def file_base_data
    files.map do |file|
      {
        id: file.id,
        automation_rule_id: id,
        file_type: file.content_type,
        account_id: account_id,
        file_url: url_for(file),
        blob_id: file.blob_id,
        filename: file.filename.to_s
      }
    end
  end

  def invalid_condition_error!
    ::Redis::Alfred.incr(rule_condition_error_key)

    disable_and_notify if condition_error_counts >= MAX_ERROR_THRESHOLD
  end

  def rule_condition_error_key
    format(::Redis::Alfred::AUTOMATION_RULE_CONDITION_ERROR, obj_type: self.class.table_name.singularize, obj_id: id)
  end

  def disable_and_notify
    self.active = false
    save!

    # send an email to the admin that the rule is disabled
    mailer = AdministratorNotifications::ChannelNotificationsMailer.with(account: account)
    mailer.automation_rule_disabled(self).deliver_later
  end

  private

  def condition_error_counts
    ::Redis::Alfred.get(rule_condition_error_key).to_i
  end

  def json_conditions_format
    return if conditions.blank?

    attributes = conditions.map { |obj, _| obj['attribute_key'] }
    conditions = attributes - conditions_attributes
    conditions -= account.custom_attribute_definitions.pluck(:attribute_key)
    errors.add(:conditions, "Automation conditions #{conditions.join(',')} not supported.") if conditions.any?
  end

  def json_actions_format
    return if actions.blank?

    attributes = actions.map { |obj, _| obj['action_name'] }
    actions = attributes - actions_attributes

    errors.add(:actions, "Automation actions #{actions.join(',')} not supported.") if actions.any?
  end

  def query_operator_presence
    return if conditions.blank?

    operators = conditions.select { |obj, _| obj['query_operator'].nil? }
    errors.add(:conditions, 'Automation conditions should have query operator.') if operators.length > 1
  end
end

AutomationRule.include_mod_with('Audit::AutomationRule')
AutomationRule.prepend_mod_with('AutomationRule')
