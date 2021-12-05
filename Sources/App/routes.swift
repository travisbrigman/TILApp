import Fluent
import Vapor

func routes(_ app: Application) throws {

    
    // 1
    let acronymsController = AcronymsController()
    // 2
    try app.register(collection: acronymsController)
    
    // 1 - Create a UsersController instance.
    let usersController = UsersController()
    // 2 - Register the new controller instance with the router to hook up the routes.
    try app.register(collection: usersController)
    
    let categoriesController = CategoriesController()
    try app.register(collection: categoriesController)
}
