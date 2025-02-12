require "./toolchain"

class Api

  class Recipe
    include JSON::Serializable
    property spec_path : String
    property macros : Hash(String, String)
    property commands : Array(Command)

    abstract class Command
      include JSON::Serializable
      property command : String

      use_json_discriminator "command", {
        assemble: Assemble,
        compile: Compile,
        lib: Lib,
        merge: Merge,
        link: Link,
        run: Run,
      }

      class Assemble < Command
        property source : String
        property destination : String
      end

      class Compile < Command
        property source : String
        property destination : String
      end

      class Lib < Command
        property sources : Array(String)
        property destination : String
      end

      class Merge < Command
        property sources : Array(String)
        property destination : String
        property dce : Bool = true
      end

      class Link < Command
        property source : String
        property destination : String
      end

      class Run < Command
        property source : String
      end
    end
  end

  class Job
    include JSON::Serializable

    property id : UUID 
    property owner_id : UUID
    property recipe_path : String
    property success = false
    property completed = false
    property started = false
    property running = false

    @[JSON::Field(ignore: true)]
    property fiber : Fiber?

    def initialize(@id, @owner_id, @recipe_path)
    end
  end

  @jobs = [] of Job

  class Request::RecipePath
    include JSON::Serializable
    property path : String
  end

  route POST, "/job/create", def create_job(ctx)
    user_id = authenticate(ctx)
    recipe_request = ctx >> Request::RecipePath
    job_id = UUID.random
    job = Job.new job_id, user_id, recipe_request.path
    # TODO serialize jobs to REDIS instead. Only the hash job_id => (fiber, socket) can stay local to the api 
    # (because it cant escape the scope of a single api as it's tied to a websocket).
    # the socket is kept so we can close it ?
    # DO limit the amout of possible concurrent job
    # have a route to 
    @jobs << job
    ctx << job
  end

  # Job create put the job on redis
  # initialize bind the receiving api and the job
  # status read redis
  # start check and broadcast
  # stop check and broadcast
  # pause check and broadcast
  # on broadcast, if api is bound to job, do the task

  websocket GET, "/project/:project_id/job/:job_id/initialize", def open_job_tty(socket, ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"
    job_id = UUID.new ctx.path_parameter "job_id"
    job = @jobs.find(&.id.== job_id)

    raise "No such job" unless job
    raise "Not your job" unless job.owner_id == user_id
    raise "Job already initialized" if job.fiber

    Log.info &.emit "Creating job"

    socket.on_close do 
      # Remove all trace of the job
    end

    fiber = Fiber.new do
      job.started = true

      es = JobEventStream.new socket
      fs = JobFileSystem.new @storage, @users, @projects, @files, @blobs, @notifications, project_id, user_id, es

      recipe = es.with_context "Reading recipe file '#{job.recipe_path}'" do 
        fs.read(job.recipe_path) do |io|
          Recipe.from_json io
        end
      end

      toolchain = Toolchain.new false, recipe.spec_path, recipe.macros, fs, es
    
      recipe.commands.each do |command|
        case command
        when Recipe::Command::Compile then toolchain.compile(command.source, command.destination)
        end
      end

      job.completed = true
      job.success = true
      # remove all local trace (socket, fiber ref)
      # Set to cache, keep for 24 hours
    rescue ex
      Log.error exception: ex, &.emit "Exception during job start"
      job.completed = true
      # remove all local trace (socket, fiber ref)
      # Set to cache, keep for 24 hours
    end

    job.fiber = fiber
  end

  route PUT, "/job/:job_id/start", def start_job(ctx)
    user_id = authenticate(ctx)
    job_id = UUID.new ctx.path_parameter "job_id"
    # check job exists
    # just boradcast instead

    # On broadcast, of the job is owned by this api
    
    job = @jobs.find(&.id.== job_id)
    # read from redis
    raise "No such job" unless job
    raise "Not your job" unless job.owner_id == user_id
    fiber = job.fiber
    raise "Job non initialized" unless fiber
    raise "Job finished" if fiber.dead?
    raise "Job already started" if job.running
    job.running = true
    fiber.enqueue
  end

  # route PUT, "/job/:job_id/stop", def stop_job(ctx)
  #   user_id = authenticate(ctx)
  #   job_id = UUID.new ctx.path_parameter "job_id"
  #   job = @jobs.find(&.id.== job_id)
  #   raise "No such job" unless job
  #   raise "Not your job" unless job.owner_id == user_id
  #   fiber = job.fiber
  #   raise "Job non initialized" unless fiber
  #   raise "Job finished" if fiber.dead?
  #   raise "Job not started" unless fiber.running? || fiber.resumable?
  #   fiber.suspend
  #   @jobs.delete job


  # end

  # route PUT, "/job/:job_id/pause", def pause_job(ctx)
  #   user_id = authenticate(ctx)
  #   job_id = UUID.new ctx.path_parameter "job_id"
  #   job = @jobs.find(&.id.== job_id)
  #   raise "No such job" unless job
  #   raise "Not your job" unless job.owner_id == user_id
  #   fiber = job.fiber
  #   raise "Job non initialized" unless fiber
  #   raise "Job finished" if fiber.dead?
  #   raise "Job not started" unless fiber.running? || fiber.resumable?
  #   fiber.suspend
  # end

end