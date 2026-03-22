FactoryBot.define do
  factory :user do
    sequence(:name) { |index| "Usuário #{index}" }
    sequence(:email) { |index| "user#{index}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    timezone { "America/Sao_Paulo" }
    locale { "pt-BR" }
  end
end
