require "./repositories"

class Repositories::Notifications::PubSub < Repositories::Notifications
  
  struct CancelableSubscription
    include Repositories::Cancelable
    def initialize(@subscription : ::PubSub::Subscription)
    end

    def cancel
      @subscription.unsubscribe
    end
  end

  @pubsub : ::PubSub

  def initialize(@pubsub)
  end

  def create_file(project_id : UUID, path : String)
    @pubsub.publish("project/#{project_id}/create", {path: path}.to_json)
  end

  def delete_file(project_id : UUID, path : String)
    @pubsub.publish("project/#{project_id}/delete", {path: path}.to_json)
  end

  def move_file(project_id : UUID, old_path : String, new_path : String)
    @pubsub.publish("project/#{project_id}/move", {old_path: old_path, new_path: new_path}.to_json)
  end

  def on_file_created(project_id : UUID, handler : (String) ->) : Repositories::Cancelable
    CancelableSubscription.new(@pubsub.subscribe "project/#{project_id}/create", ->(message : String) do
      fields = JSON.parse message
      handler.call(fields["path"].as_s)
    end)
  end

  def on_file_deleted(project_id : UUID, handler : (String) ->) : Repositories::Cancelable
    CancelableSubscription.new(@pubsub.subscribe "project/#{project_id}/delete", ->(message : String) do
      fields = JSON.parse message
      handler.call(fields["path"].as_s)
    end)
  end

  def on_file_moved(project_id : UUID, handler : (String, String) ->) : Repositories::Cancelable
    CancelableSubscription.new(@pubsub.subscribe "project/#{project_id}/move", ->(message : String) do
      fields = JSON.parse message
      handler.call(fields["old_path"].as_s, fields["new_path"].as_s)
    end)
  end
end
