class HomeController < ApplicationController
  def index
    render ::Views::HomePage.new(request: request)
  end
end
