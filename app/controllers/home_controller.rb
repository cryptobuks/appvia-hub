class HomeController < ApplicationController
  def show
    @activity = ActivityService.new.overall
  end
end
