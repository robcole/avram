require "file_utils"
require "spec"
require "../src/avram"
require "./support/models/base_model"
require "./support/models/**"
require "./support/factories/base_factory"
require "./support/factories/**"
require "./support/**"
require "../config/*"
require "../db/migrations/**"

Pulsar.enable_test_mode!

backend = Log::IOBackend.new(STDERR)
backend.formatter = Dexter::JSONLogFormatter.proc
Log.builder.bind("avram.*", :error, backend)

Db::Create.new(quiet: true).run_task
Db::Migrate.new(quiet: true).run_task
Db::VerifyConnection.new(quiet: true).run_task

Avram::SpecHelper.use_transactional_specs(TestDatabase)

Spec.before_each do
  # All specs seem to run on the same Fiber,
  # so we set back to NullStore before each spec
  # to ensure queries aren't randomly cached
  Fiber.current.query_cache = LuckyCache::NullStore.new
end

class SampleBackupDatabase < Avram::Database
end

SampleBackupDatabase.configure do |settings|
  settings.credentials = Avram::Credentials.parse?(ENV["BACKUP_DATABASE_URL"]?) || Avram::Credentials.new(
    hostname: "db",
    database: "sample_backup",
    username: "lucky",
    password: "developer"
  )
end

Habitat.raise_if_missing_settings!
