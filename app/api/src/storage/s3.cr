require "awscr-s3"
require "./storage"
require "./signer"

# File storage though Simple Storage Service, aka S3.
# Implementation should be compatible with various implementation; including:
# Minio, AWS S3, openstack storage service.
# It will create (if needed) and access a bucket to handle file storages.
class Storage::S3 < Storage

  # Instantiate with a S3 client, using several envrionnment variables:
  # *S3_KEY* username or api key.
  # *S3_SECRET* user password or api secret.
  # *S3_REGION* S3 compatible services will have a default one.
  # *S3_PUBLIC_HOST* Optional, leave blank to use AWS S3.
  # *S3_BUCKET_PREFIX* optionnal, prefix applied to bucket names to use.
  # *S3_BUCKET_SUFFIX* optionnal, suffix applied to bucket names to use.
  # *S3_ACCESS_VHOST* Optionnal, if false, access uri will be in the form
  #  "scheme://endpoit/bucket/path". If true, access will be in the form
  #  "scheme://bucket.endpoint/path". Default to true.
  # All S3 implementation might not supports all ways.
  # Minio supports only path flavor, openstack only vhost flavor.
  # The bucket name is provided as a separate parameter to accomodate application requiring several isolated storage on the same s3 isntance. 
  def self.from_environnment(bucket_name : String)
    new ENV["S3_KEY"],
      ENV["S3_SECRET"],
      ENV["S3_REGION"],
      ENV["S3_PUBLIC_HOST"]?,
      ENV["S3_ENDPOINT"]?,
      ENV["S3_BUCKET_PREFIX"]?,
      ENV["S3_BUCKET_SUFFIX"]?,
      ENV["S3_ACCESS_VHOST"]? == "true",
      bucket_name
  end

  # Build an access uri for an object.
  # If the object has no public access, it will be a presigned uri.
  # If internal is true, does not use the public host
  def uri(name : String, public : Bool = false, internal : Bool = false) : String
    host = @public_host
    scheme = @public_scheme

    endpoint = @endpoint
    if internal && endpoint
      uri = URI.parse endpoint
      host = uri.authority
      scheme = uri.scheme || "https"
    end
    
    S3::Signer::V4.sign(
      path: "/#{name}",
      bucket: @bucket_name,
      key: @key,
      region: @region,
      secret: @secret,
      host_name: host,
      scheme: @public_scheme,
      vhost: @use_vhost,
      public: public
    )
  end

  def put(data : Bytes | IO | String, mime : String, name : String, acl : ACL = :private)
    amz_acl = case acl
      in ACL::Public then "public-read"
      in ACL::Private then "private"
    end
    name = name.lchop '/'
    @client.put_object @bucket_name, name, data, {"Content-Type" => mime, "X-Amz-Acl" => amz_acl}
  end

  def delete(name : String)
    name = name.lchop '/'
    @client.delete_object @bucket_name, name
  end

  def batch_delete(names : Indexable(String))
    names = names.map &.lchop '/'
    @client.batch_delete @bucket_name, names
  end

  @public_scheme : String
  @public_host : String?

  def initialize(@key : String, @secret : String, @region : String, public_host : String?, @endpoint : String?, @prefix : String?, @suffix : String?, @use_vhost : Bool, @bucket_name : String)
    public_host = nil if public_host.try &.empty?
    @endpoint = nil if @endpoint.try &.empty?
    @client = Awscr::S3::Client.new @region, @key, @secret, endpoint: @endpoint
    @bucket_name = "#{@prefix}-#{@bucket_name}" if @prefix
    @bucket_name = "#{@bucket_name}-#{@suffix}" if @suffix

    if public_host
      uri = URI.parse public_host
      @public_host = uri.authority
      @public_scheme = uri.scheme || "https"
    else
      @public_host = nil
      @public_scheme = "https"
    end

    unless @client.list_buckets.buckets.includes? @bucket_name
      @client.put_bucket @bucket_name, @region
    end
  end

  def close
  end
end
