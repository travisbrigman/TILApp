//
//  CategoriesController.swift
//
//
//  Created by Travis Brigman on 12/4/21.
//

import Vapor

// 1 - Define a new CategoriesController type that conforms to RouteCollection.
struct CategoriesController: RouteCollection {
    // 2 - Implement boot(routes:) as required by RouteCollection. This is where you register route handlers.
    func boot(routes: RoutesBuilder) throws {
        // 3 - Create a new route group for the path /api/categories.
        let categoriesRoute = routes.grouped("api", "categories")
        categoriesRoute.get(use: getAllHandler)
        categoriesRoute.get(":categoryID", use: getHandler)
        categoriesRoute.get(
            ":categoryID",
            "acronyms",
            use: getAcronymsHandler)
        
        let tokenAuthMiddleware = Token.authenticator()
        let guardAuthMiddleware = User.guardMiddleware()
        let tokenAuthGroup = categoriesRoute.grouped(
          tokenAuthMiddleware,
          guardAuthMiddleware)
        tokenAuthGroup.post(use: createHandler)
    }
  
    // 5 - Define createHandler(_:) that creates a category.
    func createHandler(_ req: Request)
        throws -> EventLoopFuture<Category>
    {
        // 6 - Decode the category from the request and save it.
        let category = try req.content.decode(Category.self)
        return category.save(on: req.db).map { category }
    }
  
    // 7 - Define getAllHandler(_:) that returns all the categories.
    func getAllHandler(_ req: Request)
        -> EventLoopFuture<[Category]>
    {
        // 8 - Perform a Fluent query to retrieve all the categories from the database.
        Category.query(on: req.db).all()
    }
  
    // 9 - Define getHandler(_:) that returns a single category.
    func getHandler(_ req: Request)
        -> EventLoopFuture<Category>
    {
        // 10 - Get the ID from the request and use it to find the category.
        Category.find(req.parameters.get("categoryID"), on: req.db)
            .unwrap(or: Abort(.notFound))
    }
    
    // 1 - Define a new route handler, getAcronymsHandler(_:), that returns EventLoopFuture<[Acronym]>.
    func getAcronymsHandler(_ req: Request)
        -> EventLoopFuture<[Acronym]>
    {
        // 2 - Get the category from the database using the ID provided to the request. Ensure one is returned and unwrap the future.
        Category.find(req.parameters.get("categoryID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { category in
                // 3 - Use the new property wrapper to get the acronyms. This uses get(on:) to perform the query for you. This is the same as query(on: req.db).all() from earlier.
                category.$acronyms.get(on: req.db)
            }
    }
}
