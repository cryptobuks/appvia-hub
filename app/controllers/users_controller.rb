class UsersController < ApplicationController
  # GET /users
  def index
    @users = User.order(:email)
  end
end
