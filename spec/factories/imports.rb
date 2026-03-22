FactoryBot.define do
  factory :import do
    association :user
    credit_card { association :credit_card, user: user }
    statement { nil }
    source_kind { "pdf" }
    provider_key { "inter_pdf" }
    status { "review_pending" }
    raw_payload { {} }
    parsed_payload do
      {
        "statement" => {
          "period_start" => "2026-01-29",
          "period_end" => "2026-02-28",
          "due_date" => "2026-03-05",
          "total_amount_cents" => 649_417,
          "status" => "open",
          "metadata" => {}
        },
        "summary" => {
          "total_items" => 1,
          "ignored_items" => 0,
          "reviewable_items" => 1
        }
      }
    end
    error_payload { {} }
    processing_started_at { Time.zone.parse("2026-03-22 19:43:38") }
    processing_finished_at { Time.zone.parse("2026-03-22 19:43:42") }
    confirmed_at { nil }

    transient do
      source_file_path { Rails.root.join("doc", "inter.pdf") }
    end

    after(:build) do |import_record, evaluator|
      next if import_record.source_file.attached?

      import_record.source_file.attach(
        io: File.open(evaluator.source_file_path),
        filename: File.basename(evaluator.source_file_path),
        content_type: "application/pdf"
      )
    end
  end
end
