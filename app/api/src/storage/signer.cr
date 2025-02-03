require "openssl/hmac"

# The simplest signer I could write for generating
# AWS V4 presigned GET url for s3 compatible service.
#
# S3 Access API usually exists in two flavors:
# scheme://host/bucket/object (path flavor)
# OR scheme://bucket.host/object (vhost flavor)
# Some s3 'compatible' service supports only the vhost way.
# VHost way is much more complex when self-hosting. This is why both options are
# supported, defaulting to vhost.
module S3::Signer::V4
  def self.sign(path, host_name, scheme, bucket, key, region, secret, vhost = true, public = false)
    host_name ||= "s3-#{region}.amazonaws.com" # Default to AWS
    path = path.gsub /#/, "%23"

    if public
      if vhost
        return "#{scheme}://#{bucket}.#{host_name}/#{path.lstrip '/'}"
      else
        return "#{scheme}://#{host_name}/#{bucket}/#{path.lstrip '/'}"
      end
    end

    timestamp = Time.utc
    time_ymd = timestamp.to_s("%Y%m%d")
    time_iso = timestamp.to_s "%Y%m%dT%H%M%SZ"
    scope = "#{time_ymd}/#{region}/s3/aws4_request"

    signing_key = OpenSSL::HMAC.digest(
      :sha256,
      OpenSSL::HMAC.digest(
        :sha256,
        OpenSSL::HMAC.digest(
          :sha256,
          OpenSSL::HMAC.digest(
            :sha256,
            "AWS4#{secret}",
            time_ymd
          ),
          region
        ),
        "s3"
      ),
      "aws4_request"
    )

    if vhost
      canonical = <<-HTTP
        GET
        /#{path.lstrip '/'}
        X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=#{key}%2F#{scope.gsub /\//, "%2F"}&X-Amz-Date=#{time_iso}&X-Amz-Expires=86400&X-Amz-SignedHeaders=host
        host:#{bucket}.#{host_name}

        host
        UNSIGNED-PAYLOAD
        HTTP
    else
      canonical = <<-HTTP
        GET
        /#{bucket}/#{path.lstrip '/'}
        X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=#{key}%2F#{scope.gsub /\//, "%2F"}&X-Amz-Date=#{time_iso}&X-Amz-Expires=86400&X-Amz-SignedHeaders=host
        host:#{host_name}

        host
        UNSIGNED-PAYLOAD
        HTTP
    end

    digest = OpenSSL::Digest.new("SHA256").tap(&.update canonical).final.hexstring
    data = "AWS4-HMAC-SHA256\n#{time_iso}\n#{scope}\n#{digest}"
    signature = OpenSSL::HMAC.hexdigest :sha256, signing_key, data

    if vhost
      "#{scheme}://#{bucket}.#{host_name}/#{path.lstrip '/'}?X-Amz-Expires=86400&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=#{key}/#{scope}&X-Amz-Date=#{time_iso}&X-Amz-SignedHeaders=host&X-Amz-Signature=#{signature}"
    else
      "#{scheme}://#{host_name}/#{bucket}/#{path.lstrip '/'}?X-Amz-Expires=86400&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=#{key}/#{scope}&X-Amz-Date=#{time_iso}&X-Amz-SignedHeaders=host&X-Amz-Signature=#{signature}"
    end
  end
end
