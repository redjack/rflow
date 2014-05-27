require 'uuidtools'

class RFlow
  module Util
    # Generate a UUID based on either the SHA1 of a seed string (v5) with a
    # 'zero' UUID namespace, or using a purely random generation
    # (v4) if no seed string is present
    def generate_uuid_string(seed = nil)
      uuid = if seed
               UUIDTools::UUID.sha1_create(UUIDTools::UUID.parse_int(0), seed)
             else
               UUIDTools::UUID.random_create
             end
      uuid.to_s
    end
  end
end
