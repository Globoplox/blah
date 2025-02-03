require "http/server"
require "http/status"
require "json"
require "uuid/json"
require "cradix"

require "./error"
require "./context"

require "../models/validations"

class Api
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
  @@router = Cradix((Api, Context) -> Nil).new
  @@debug = ENV["ENV"]?.in?({"dev", "local"})
  class_getter debug

  @server : HTTP::Server
  @storage : Storage
  @cache : Cache
  @users : Repositories::Users

  def initialize(@storage, @cache, @users, bind)    
    @server = uninitialized HTTP::Server
    @server = HTTP::Server.new([
      HTTP::CompressHandler.new
    ]) do |ctx|
      t = Time.monotonic
      Log.info &.emit "#{ctx.request.method} #{ctx.request.path.rstrip '/'}"
      ctx.response.headers["Access-Control-Allow-Methods"] = "POST,DELETE,PUT,PATCH,GET,HEAD,OPTIONS"
      ctx.response.headers["Access-Control-Max-Age"] = "3600"
      ctx.response.headers["Access-Control-Allow-Credentials"] = "true"
      ctx.response.headers["Access-Control-Allow-Headers"] = "Authorization,Content-Type"
      ctx.response.headers["Access-Control-Allow-Origin"] = "*"

      if ctx.request.method == "OPTIONS"
        ctx.response.status_code = 204
      else
        routes = @@router.search "#{ctx.request.method}#{ctx.request.path.rstrip '/'}"
        ctx = Context.new ctx
        if routes.empty?
          ctx << Error::NotFound.new "Route #{ctx.request.method} #{ctx.request.path}"
        else
          handler, path_parameters = routes.first
          ctx.path_parameters = path_parameters
          begin
            handler.call self, ctx
          rescue error : Error
            ctx << error
          rescue ex
            Log.error exception: ex, &.emit "Exception handling route #{ctx.request.method}#{ctx.request.path.rstrip '/'}"
            ctx << Error::ServerError.new ex.message
          end
        end
      end
      Log.info &.emit "Took: #{(Time.monotonic - t).total_milliseconds}ms"
    end

    Log.info &.emit "Bound to #{bind}"
    @server.bind uri: bind
  end

  def start
    Log.info &.emit "Listening"
    @server.listen
  end

  def close
    @server.close
  end

  macro route(http_method, path, method_def)
    {{method_def}}
    @@router.add "#{{{http_method}}}/#{{{path}}.strip '/'}", ->(api: Api, context: Context) { api.{{method_def.name}}(context) }
  end

  GET    = "GET"
  POST   = "POST"
  PUT    = "PUT"
  PATCH  = "PATCH"
  DELETE = "DELETE"

  route GET, "/api/version", def version(ctx)
    ctx << VERSION
  end
end

require "./routes/*"
