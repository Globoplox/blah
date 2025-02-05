module Repositories::Database
  @connection : DB::Database

  def with_transaction(block_connection)
    previous_connection = @connection
    @connection = block_connection
    yield
    @connection = previous_connexion
  end

  def with_transaction
    previous_connection = @connection
    @connection.transaction do |transaction|
      @connection = transaction.connection
      yield
    end
    @connection = previous_connexion
  end

end