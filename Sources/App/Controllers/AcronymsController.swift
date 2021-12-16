//
//  AcronymsController.swift
//
//
//  Created by Travis Brigman on 12/2/21.
//

import Fluent
import Vapor

struct AcronymsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let acronymsRoutes = routes.grouped("api", "acronyms")
        acronymsRoutes.get(use: getAllHandler)
        // 2
        acronymsRoutes.get(":acronymID", use: getHandler)
        // 5
        acronymsRoutes.get("search", use: searchHandler)
        // 6
        acronymsRoutes.get("first", use: getFirstHandler)
        // 7
        acronymsRoutes.get("sorted", use: sortedHandler)
        
        acronymsRoutes.get(":acronymID", "user", use: getUserHandler)
        
        acronymsRoutes.get(
          ":acronymID",
          "categories",
          use: getCategoriesHandler)
        
        // 1 - Create a ModelTokenAuthenticator middleware for Token. This extracts the bearer token out of the request and converts it into a logged in user.
        let tokenAuthMiddleware = Token.authenticator()
        let guardAuthMiddleware = User.guardMiddleware()
        // 2 - Create a route group using tokenAuthMiddleware and guardAuthMiddleware to protect the route for creating an acronym with token authentication.
        let tokenAuthGroup = acronymsRoutes.grouped(
          tokenAuthMiddleware,
          guardAuthMiddleware)
        // 3 - Connect the “create acronym” path to createHandler(_:data:) through this middleware group using the new AcronymCreateData.
        tokenAuthGroup.post(use: createHandler)
        
        tokenAuthGroup.delete(":acronymID", use: deleteHandler)
        tokenAuthGroup.put(":acronymID", use: updateHandler)
        tokenAuthGroup.post(
          ":acronymID",
          "categories",
          ":categoryID",
          use: addCategoriesHandler)
        tokenAuthGroup.delete(
          ":acronymID",
          "categories",
          ":categoryID",
          use: removeCategoriesHandler)
    }

    // 1 - Register a new route handler that accepts a GET request which returns EventLoopFuture<[Acronym]>, a future array of Acronyms.
    func getAllHandler(_ req: Request)
        -> EventLoopFuture<[Acronym]>
    {
        // 2 - Perform a query to get all the acronyms.
        Acronym.query(on: req.db).all()
    }
    
    func createHandler(_ req: Request) throws
        -> EventLoopFuture<Acronym> {
            // 1 - Decode the request body to CreateAcronymData instead of Acronym.
            let data = try req.content.decode(CreateAcronymData.self)
            // 2 - Create an Acronym from the data received.
            // 1 - Get the authenticated user from the request.
            let user = try req.auth.require(User.self)
            // 2 - Create a new Acronym using the data from the request and the authenticated user.
            let acronym = try Acronym(
              short: data.short,
              long: data.long,
              userID: user.requireID())
            return acronym.save(on: req.db).map { acronym }
    }

    func getHandler(_ req: Request)
        -> EventLoopFuture<Acronym> {
      Acronym.find(req.parameters.get("acronymID"), on: req.db)
        .unwrap(or: Abort(.notFound))
    }

    func updateHandler(_ req: Request) throws
      -> EventLoopFuture<Acronym> {
      let updateData =
        try req.content.decode(CreateAcronymData.self)
      // 1 - Get the authenticated user from the request.
      let user = try req.auth.require(User.self)
      // 2 - Get the user ID from the user. It’s useful to do this here as you can’t throw inside flatMap(_:).
      let userID = try user.requireID()
      return Acronym
        .find(req.parameters.get("acronymID"), on: req.db)
        .unwrap(or: Abort(.notFound))
        .flatMap { acronym in
          acronym.short = updateData.short
          acronym.long = updateData.long
          // 3 - Set the acronym’s user’s ID to the user ID from the step above.
          acronym.$user.id = userID
          return acronym.save(on: req.db).map {
            acronym
          }
      }
    }

    func deleteHandler(_ req: Request)
        -> EventLoopFuture<HTTPStatus> {
      Acronym.find(req.parameters.get("acronymID"), on: req.db)
        .unwrap(or: Abort(.notFound))
        .flatMap { acronym in
          acronym.delete(on: req.db)
            .transform(to: .noContent)
        }
    }

    func searchHandler(_ req: Request) throws
        -> EventLoopFuture<[Acronym]> {
      guard let searchTerm = req
        .query[String.self, at: "term"] else {
          throw Abort(.badRequest)
      }
      return Acronym.query(on: req.db).group(.or) { or in
        or.filter(\.$short == searchTerm)
        or.filter(\.$long == searchTerm)
      }.all()
    }

    func getFirstHandler(_ req: Request)
        -> EventLoopFuture<Acronym> {
      return Acronym.query(on: req.db)
        .first()
        .unwrap(or: Abort(.notFound))
    }

    func sortedHandler(_ req: Request)
        -> EventLoopFuture<[Acronym]> {
      return Acronym.query(on: req.db)
        .sort(\.$short, .ascending).all()
    }
    
    // 1 - Change the return type of the method to Future<User.Public>.
    func getUserHandler(_ req: Request)
      -> EventLoopFuture<User.Public> {
      Acronym.find(req.parameters.get("acronymID"), on: req.db)
      .unwrap(or: Abort(.notFound))
      .flatMap { acronym in
        // 2 - Call convertToPublic() on the acronym’s user to return a public user.
        acronym.$user.get(on: req.db).convertToPublic()
      }
    }
    
    // 1 - Define a new route handler, addCategoriesHandler(_:), that returns EventLoopFuture<HTTPStatus>.
    func addCategoriesHandler(_ req: Request)
      -> EventLoopFuture<HTTPStatus> {
      // 2 - Define two properties to query the database and get the acronym and category from the IDs provided to the request. Each property is an EventLoopFuture.
      let acronymQuery =
        Acronym.find(req.parameters.get("acronymID"), on: req.db)
          .unwrap(or: Abort(.notFound))
      let categoryQuery =
        Category.find(req.parameters.get("categoryID"), on: req.db)
          .unwrap(or: Abort(.notFound))
      // 3 - Use and(_:) to wait for both futures to return.
      return acronymQuery.and(categoryQuery)
        .flatMap { acronym, category in
          acronym
            .$categories
            // 4 - Use attach(_:on:) to set up the relationship between acronym and category.
            .attach(category, on: req.db)
            .transform(to: .created)
        }
    }
    
    // 1 - Defines route handler getCategoriesHandler(_:) returning EventLoopFuture<[Category]>.
    func getCategoriesHandler(_ req: Request)
      -> EventLoopFuture<[Category]> {
      // 2 - Get the acronym from the database using the provided ID and unwrap the returned future.
      Acronym.find(req.parameters.get("acronymID"), on: req.db)
        .unwrap(or: Abort(.notFound))
        .flatMap { acronym in
          // 3 - Use the new property wrapper to get the categories. Then use a Fluent query to return all the categories.
          acronym.$categories.query(on: req.db).all()
        }
    }
    
    // 1 - Define a new route handler, removeCategoriesHandler(_:), that returns an EventLoopFuture<HTTPStatus>.
    func removeCategoriesHandler(_ req: Request)
      -> EventLoopFuture<HTTPStatus> {
      // 2 - Perform two queries to get the acronym and category from the IDs provided.
      let acronymQuery =
        Acronym.find(req.parameters.get("acronymID"), on: req.db)
          .unwrap(or: Abort(.notFound))
      let categoryQuery =
        Category.find(req.parameters.get("categoryID"), on: req.db)
          .unwrap(or: Abort(.notFound))
      // 3 - Use and(_:) to wait for both futures to return.
      return acronymQuery.and(categoryQuery)
        .flatMap { acronym, category in
          // 4 - Use detach(_:on:) to remove the relationship between acronym and category. This finds the pivot model in the database and deletes it. Transform the result into a 204 No Content response.
          acronym
            .$categories
            .detach(category, on: req.db)
            .transform(to: .noContent)
        }
    }
}

//A DTO is a type that represents what a client should send or receive. Your route handler then accepts a DTO and converts it into something your code can use.
struct CreateAcronymData: Content {
  let short: String
  let long: String
  
}
