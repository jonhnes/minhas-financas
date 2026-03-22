categories = [
  {
    name: "Receitas",
    color: "#2D7B59",
    children: ["Salário", "Freelance", "Reembolso"]
  },
  {
    name: "Moradia",
    color: "#144F43",
    children: ["Aluguel", "Condomínio", "Contas da casa"]
  },
  {
    name: "Mercado",
    color: "#1F5564",
    children: ["Supermercado", "Feira", "Delivery de mercado"]
  },
  {
    name: "Restaurantes",
    color: "#D98D30",
    children: ["Restaurantes", "Cafés", "Delivery"]
  },
  {
    name: "Mobilidade",
    color: "#A9D0DA",
    children: ["Uber e táxi", "Combustível", "Transporte público"]
  },
  {
    name: "Saúde",
    color: "#D35D4B",
    children: ["Farmácia", "Consultas", "Exames"]
  },
  {
    name: "Estudos",
    color: "#B3D2C4",
    children: ["Livros", "Cursos", "Ferramentas"]
  },
  {
    name: "Assinaturas",
    color: "#D98D30",
    children: ["Streaming", "Software", "Serviços"]
  },
  {
    name: "Casa & escritório",
    color: "#144F43",
    children: ["Móveis", "Papelaria", "Home office"]
  },
  {
    name: "Viagens",
    color: "#1F5564",
    children: ["Passagens", "Hospedagem", "Passeios"]
  }
]

categories.each_with_index do |category_data, position|
  parent = Category.find_or_create_by!(user_id: nil, system: true, name: category_data[:name]) do |category|
    category.color = category_data[:color]
    category.position = position
    category.active = true
  end

  category_data[:children].each_with_index do |child_name, child_position|
    Category.find_or_create_by!(user_id: nil, system: true, parent: parent, name: child_name) do |category|
      category.color = category_data[:color]
      category.position = child_position
      category.active = true
    end
  end
end
