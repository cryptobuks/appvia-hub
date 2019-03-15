class QuayAgent
  def initialize(access_token:, org:, global_robot_token_name:, global_robot_token:)
    @access_token = access_token
    @org = org
    @global_robot_token_name = global_robot_token_name
    @global_robot_token = global_robot_token
  end

  def create_repository(name)
    # TODO
  end

  def delete_repository(name)
    # TODO
  end
end
