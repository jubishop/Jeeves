$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'jeeves'
require 'minitest/autorun'
require 'minitest/pride' # For colorized output
require 'webmock/minitest' # For mocking HTTP requests

# Ensure WebMock is properly configured
WebMock.disable_net_connect!(allow_localhost: true)
