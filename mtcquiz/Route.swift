enum Route: Hashable {
    case detail(categoryId: String)
    case pdf(categoryId: String)
    case evaluation(categoryId: String)
    case summary(categoryId: String, evaluationId: String)
}
