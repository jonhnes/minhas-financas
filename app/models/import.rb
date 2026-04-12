class Import < ApplicationRecord
  MAX_SOURCE_FILE_SIZE = 50.megabytes

  belongs_to :user
  belongs_to :credit_card
  belongs_to :statement, optional: true

  has_many :import_items, dependent: :destroy
  has_one_attached :source_file

  enum :source_kind, {
    pdf: "pdf"
  }

  enum :provider_key, {
    bradesco_pdf: "bradesco_pdf",
    inter_pdf: "inter_pdf"
  }

  enum :status, {
    uploaded: "uploaded",
    processing: "processing",
    review_pending: "review_pending",
    failed: "failed",
    superseded: "superseded",
    confirmed: "confirmed"
  }

  validates :source_kind, :provider_key, :status, presence: true
  validate :source_file_presence
  validate :source_file_is_pdf
  validate :source_file_size

  scope :recent_first, -> { order(created_at: :desc) }

  def reviewable?
    review_pending? || failed?
  end

  def confirmable?
    review_pending? && statement.nil? && confirmed_at.nil?
  end

  def statement_payload
    parsed_payload.fetch("statement", {})
  end

  def summary_payload
    parsed_payload.fetch("summary", {})
  end

  def comparison_payload
    parsed_payload.fetch("comparison", {})
  end

  def document_kind
    statement_payload.dig("metadata", "document_kind")
  end

  def update_statement_payload!(attributes)
    next_payload = parsed_payload.deep_dup
    next_payload["statement"] = statement_payload.merge(attributes.stringify_keys)
    update!(parsed_payload: next_payload)
  end

  private

  def source_file_presence
    errors.add(:source_file, "é obrigatório") unless source_file.attached?
  end

  def source_file_is_pdf
    return unless source_file.attached?
    return if source_file.content_type == "application/pdf"

    errors.add(:source_file, "deve ser um PDF")
  end

  def source_file_size
    return unless source_file.attached?
    return if source_file.blob.byte_size <= MAX_SOURCE_FILE_SIZE

    errors.add(:source_file, "deve ter no máximo 50 MB")
  end
end
