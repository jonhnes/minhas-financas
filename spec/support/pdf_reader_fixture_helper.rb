require "yaml"

module PdfReaderFixtureHelper
  # CI uses tracked extracted-page fixtures; doc/ remains local-only for manual parsing checks.
  def stub_pdf_reader_fixture(fixture_name)
    fixture_path = Rails.root.join("spec", "fixtures", "parsers", "#{fixture_name}.yml")
    pages = YAML.safe_load_file(fixture_path).fetch("pages")
    page_doubles = pages.map { |text| double("PDF::Reader::Page", text: text) }
    reader = instance_double(PDF::Reader, pages: page_doubles)

    allow(PDF::Reader).to receive(:new).and_return(reader)

    reader
  end
end
