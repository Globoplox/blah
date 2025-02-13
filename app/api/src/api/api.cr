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
  @@websockets_router = Cradix((Api, HTTP::WebSocket, Context) -> Nil).new
  @@debug = ENV["ENV"]?.in?({"dev", "local"})
  class_getter debug
  @server : HTTP::Server
  @storage : Storage
  @cache : Cache
  @users : Repositories::Users
  @projects : Repositories::Projects
  @files : Repositories::Files
  @blobs : Repositories::Blobs
  @notifications : Repositories::Notifications
  @websockets : HTTP::WebSocketHandler

  def initialize(@storage, @cache, @users, @projects, @files, @blobs, @notifications, bind, cors_origin)
    @server = uninitialized HTTP::Server
    @websockets = uninitialized HTTP::WebSocketHandler
    
    @websockets = HTTP::WebSocketHandler.new do |socket, ctx|
      t = Time.monotonic
      Log.info &.emit "Websocket #{ctx.request.path}"

      routes = @@websockets_router.search ctx.request.path
      ctx = Context.new ctx
      if routes.empty?
        socket.close
        ctx << Error::NotFound.new "Websocket #{ctx.request.path}"
      else
        handler, path_parameters, wildcard = routes.first
        ctx.path_parameters = path_parameters
        # cradix bug fix:
        if wildcard && ctx.request.path.ends_with?("/") && !wildcard.ends_with?("/")
          wildcard = "#{wildcard}/"
        end
        ctx.path_wildcard = wildcard
        begin
          handler.call self, socket, ctx
        rescue error : Error
          socket.close
          ctx << error
        rescue ex
          socket.close
          Log.error exception: ex, &.emit "Exception handling websocket#{ctx.request.path}"
          ctx << Error::ServerError.new ex.message
        end
      end
      Log.info &.emit "Took: #{(Time.monotonic - t).total_milliseconds}ms"
    end

    @server = HTTP::Server.new([
      HTTP::CompressHandler.new,
      @websockets
    ]) do |ctx|
      t = Time.monotonic
      Log.info &.emit "#{ctx.request.method} #{ctx.request.path}"
      ctx.response.headers["Access-Control-Allow-Methods"] = "POST,DELETE,PUT,PATCH,GET,HEAD,OPTIONS"
      ctx.response.headers["Access-Control-Max-Age"] = "3600"
      ctx.response.headers["Access-Control-Allow-Credentials"] = "true"
      ctx.response.headers["Access-Control-Allow-Headers"] = "Authorization,Content-Type"
      ctx.response.headers["Access-Control-Allow-Origin"] = cors_origin

      if ctx.request.method == "OPTIONS"
        ctx.response.status_code = 204
      else
        routes = @@router.search "#{ctx.request.method}#{ctx.request.path}"
        ctx = Context.new ctx
        if routes.empty?
          ctx << Error::NotFound.new "Route #{ctx.request.method} #{ctx.request.path}"
        else
          handler, path_parameters, wildcard = routes.first
          ctx.path_parameters = path_parameters
          # cradix bug fix:
          if wildcard && ctx.request.path.ends_with?("/") && !wildcard.ends_with?("/")
            wildcard = "#{wildcard}/"
          end
          ctx.path_wildcard = wildcard
          begin
            handler.call self, ctx
          rescue error : Error
            ctx << error
          rescue ex
            Log.error exception: ex, &.emit "Exception handling route #{ctx.request.method}#{ctx.request.path}"
            ctx << Error::ServerError.new ex.message
          end
        end
      end
      Log.info &.emit "Took: #{(Time.monotonic - t).total_milliseconds}ms"
    end

    uri = URI.parse bind
    pp uri.scheme
    pp uri.query_params["reuse_port"]?
    if uri.scheme == "tcp" && uri.query_params["reuse_port"]? == "true"
      Log.info &.emit "Bound to tcp #{uri.host || "localhost"}:#{uri.port || 80}, reuse_port: true"
      @server.bind_tcp host: uri.host || "localhost", port: uri.port || 80, reuse_port: true
    else
      Log.info &.emit "Bound to #{bind}"
      @server.bind bind
    end
  end

  def start
    Log.info &.emit "Listening"
    @server.listen
  end

  def close
    @server.close
  end

  macro websocket(http_method, path, method_def)
    {{method_def}}
    @@websockets_router.add {{path}}, ->(api: Api, socket : HTTP::WebSocket, context: Context) { api.{{method_def.name}}(socket, context) }
  end

  macro route(http_method, path, method_def)
    {{method_def}}
    @@router.add "#{{{http_method}}}/#{{{path}}}", ->(api: Api, context: Context) { api.{{method_def.name}}(context) }
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
