class Impression < ActiveRecord::Base
  belongs_to :impressionable, :polymorphic=>true
  belongs_to :user

  after_save :update_impressions_counter_cache

  def self.group_by_day
    format = case ActiveRecord::Base.connection.adapter_name.downcase
      when /^sqlite/ then raise "Impression#group_by_day does not yet support sqlite!"
      when /^mysql/ then "DATE_FORMAT(created_at, '%Y-%m-%d')"
      when /^postgresql/ then "TO_CHAR(created_at, 'YYYY-MM-DD')"
    end
    group("day").select("#{format} AS day")
  end

  def self.by_controller_action(controller_with_action)
    controller, action = controller_with_action.split("#")
    where(:controller_name => controller).where(action.present? ? {:action_name => action} : "TRUE")
  end

  def controller_action?(controller_with_action)
    controller, action = controller_with_action.split("#")
    return false if controller != self.controller_name
    return false if action && action != self.action_name
    true
  end

  def controller_action
    [controller_name.presence, action_name.presence].compact.join("#")
  end

  private

  def update_impressions_counter_cache
    impressionable_class = self.impressionable_type.constantize

    if impressionable_class.counter_cache_options
      resouce = impressionable_class.find(self.impressionable_id)
      resouce.try(:update_counter_cache)
    end
  rescue NameError
    # If controller has no associated model, e.g. WelcomeController
  end
end