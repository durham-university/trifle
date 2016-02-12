module Trifle
  class ResqueAdmin
    def self.matches?(request)
      current_user = request.env['warden'].user
      return current_user.try(:is_admin?)
    end
  end
end
