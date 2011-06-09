require 'base64'
require 'uri'
require 'cgi'
require 'hmac'
require 'hmac-sha1'

module UrlSigner
  class Signer

    attr_accessor :url, :digest_key, :signature, :options
    ALLOWED_OPTIONS = [:verb, :path, :digest_key_encoding, :signature_param_name]

    def initialize(*args)
      @options = { :verb => 'GET', :path => true, :digest_key_encoding => :plain, :signature_param_name => 'signature' }
      @options.merge!(args.pop) if args.last.kind_of? Hash
      @url, @digest_key = args.shift(2)

      block_given? ? yield(self) : self

      raise ArgumentError.new("URL to sign needed (pass it as the first argument, or via the block-definition)!") unless @url
      raise ArgumentError.new("Private key needed (pass it as the second argument, or via the block-definition)!") unless @digest_key

      @url = URI.parse(@url)
    end

    def signed_url
      @signed_url ||= "#{@url.scheme}://#{@url.host}:#{@url.port}#{@url.path}" +
                      '?' + (@url.query.nil? || @url.query.empty? ? '' : "#{@url.query}&") +
                      "#{@options[:signature_param_name]}=#{signature}"
    rescue => ex
      puts ex.message
      ''
    end

    def method_missing(method_name, *args)
      if opt_key = ALLOWED_OPTIONS.detect { |opt| method_name.to_s =~ /^#{opt}(=)?$/ }
        $1 ? @options[opt_key] = args.empty? ? nil : args.first : @options[opt_key]
      else
        super
      end
    end

    def respond_to?(method_name)
      ALLOWED_OPTIONS.detect { |opt| method_name.to_s =~ /^#{opt}=?$/ } || super
    end

    def signature
      # 1/ decode the private key
      decoded_digest_key = case @options[:digest_key_encoding]
      when :base64
        url_safe_base64_decode(@digest_key)
      else
        @digest_key
      end

      # 2/ create a signature using the private key and the URL
      signature = HMAC::SHA1.digest(
                    decoded_digest_key,
                    @options[:verb] + '&' +
                    @url.scheme + @url.host + ":#{@url.port}" + (@options[:path] ? @url.path : '') + '&' +
                    sorted_query_string
                  )

      # 3/ encode the signature into base64 for url use form.
      @signature ||= url_safe_base64_encode(signature).strip!
    end

  private

    def sorted_query_string
      @sorted_query_string ||= @url.query.nil? || @url.query.empty? ? '' : CGI::escape(@url.query.split('&').sort.join('&'))
    end

    def url_safe_base64_decode(base64_string)
      Base64.decode64(base64_string.tr('-_','+/'))
    end

    def url_safe_base64_encode(raw_string)
      Base64.encode64(raw_string).tr('+/','-_')
    end

  end
end
