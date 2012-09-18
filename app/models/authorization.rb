class Authorization < ActiveRecord::Base

  belongs_to :user

  attr_accessor :redirect_uri

  validate :generate_token
  validate :set_origin

  validates_presence_of :origin, :token

  def scopes
    scope.split(/\s+/).inject({}) {|scopes, s|
      path, mode = s.split(':')
      scopes.update(path => mode)
    }
  end

  def origin
    read_attribute(:origin) || set_origin
  end

  def origin_host
    URI.parse(origin).try(:host)
  end

  def token_redirect_uri
    "#{redirect_uri}#access_token=#{token}"
  end

  def allows?(mode, path)
    scopes.each do |scope, m|
      logger.info "Check scope: #{scope.inspect} vs. #{path.inspect}"
      if path =~ /^#{scope}/
        return (mode == :read || m == 'rw')
      end
    end
    return false
  end

  private

  def set_origin
    return if read_attribute(:origin)
    if @redirect_uri
      uri = URI.parse(@redirect_uri)
      if( (uri.scheme == 'https' && uri.port == 443) ||
          (uri.scheme == 'http' && uri.port = 80) )
        host_with_port = uri.host
      else
        host_with_port = "#{uri.host}:#{uri.port}"
      end
      return self.origin = "#{uri.scheme}://#{host_with_port}"
    else
      errors.add(:redirect_uri, :blank)
    end
    return nil
  end

  def generate_token
    self.token = open("/dev/urandom").read(24).bytes.map { |byte|
      byte.to_s(16)
    }.join
  end

end