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
    // 4 - Register the route handlers to their routes.
    categoriesRoute.post(use: createHandler)
    categoriesRoute.get(use: getAllHandler)
    categoriesRoute.get(":categoryID", use: getHandler)
  }
  
  // 5 - Define createHandler(_:) that creates a category.
  func createHandler(_ req: Request)
    throws -> EventLoopFuture<Category> {
    // 6 - Decode the category from the request and save it.
    let category = try req.content.decode(Category.self)
    return category.save(on: req.db).map { category }
  }
  
  // 7 - Define getAllHandler(_:) that returns all the categories.
  func getAllHandler(_ req: Request)
    -> EventLoopFuture<[Category]> {
    // 8 - Perform a Fluent query to retrieve all the categories from the database.
    Category.query(on: req.db).all()
  }
  
  // 9 - Define getHandler(_:) that returns a single category.
  func getHandler(_ req: Request)
    -> EventLoopFuture<Category> {
    // 10 - Get the ID from the request and use it to find the category.
    Category.find(req.parameters.get("categoryID"), on: req.db)
      .unwrap(or: Abort(.notFound))
  }
}
