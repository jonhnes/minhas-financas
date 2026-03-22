module Imports
  class ProcessImportJob < ApplicationJob
    queue_as :imports

    def perform(import_id)
      import = Import.find(import_id)
      Imports::ProcessImport.new(import: import).call
    rescue StandardError => error
      Rails.logger.error("[Imports::ProcessImportJob] #{error.class}: #{error.message}")
    end
  end
end
