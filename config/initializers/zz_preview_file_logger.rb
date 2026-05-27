# frozen_string_literal: true

# Write production-mode preview logs to a file that is readable from the
# Codespaces app-container terminal.
#
# The production compose stack sets RAILS_LOG_TO_STDOUT=true, which is right
# for containers but awkward in a Dev Container: VS Code attaches terminals to
# the app container, while Docker stdout is owned by the Codespaces host. This
# initializer is a strict no-op unless PREVIEW_FILE_LOG=true is set by the
# Codespaces compose override.

if ENV['PREVIEW_FILE_LOG'] == 'true'
  preview_log_path = Rails.root.join('log', 'preview.log')
  preview_file_logger = ActiveSupport::Logger.new(preview_log_path)
  preview_file_logger.formatter = Rails.application.config.log_formatter

  Rails.logger.extend(ActiveSupport::Logger.broadcast(preview_file_logger))
  Rails.application.config.logger = Rails.logger
end
