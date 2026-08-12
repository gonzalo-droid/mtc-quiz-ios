enum Route: Hashable {
    case detail(categoryId: String)
    case pdf(categoryId: String)
    case evaluation(categoryId: String)
    case summary(categoryId: String, evaluationId: String)
    case settings
    case customize
    case premium
    case questionReview(categoryId: String)
    case stats
    case history
    case errorReview
    case terms
    case privacy
}
