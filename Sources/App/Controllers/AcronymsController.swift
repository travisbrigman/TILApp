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
        // 1
        acronymsRoutes.post(use: createHandler)
        // 2
        acronymsRoutes.get(":acronymID", use: getHandler)
        // 3
        acronymsRoutes.put(":acronymID", use: updateHandler)
        // 4
        acronymsRoutes.delete(":acronymID", use: deleteHandler)
        // 5
        acronymsRoutes.get("search", use: searchHandler)
        // 6
        acronymsRoutes.get("first", use: getFirstHandler)
        // 7
        acronymsRoutes.get("sorted", use: sortedHandler)
        
        acronymsRoutes.get(":acronymID", "user", use: getUserHandler)
        
        acronymsRoutes.post(
          ":acronymID",
          "categories",
          ":categoryID",
          use: addCategoriesHandler)
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
            let acronym = Acronym(
              short: data.short,
              long: data.long,
              userID: data.userID)
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
      return Acronym
        .find(req.parameters.get("acronymID"), on: req.db)
        .unwrap(or: Abort(.notFound))
        .flatMap { acronym in
          acronym.short = updateData.short
          acronym.long = updateData.long
          acronym.$user.id = updateData.userID
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
    
    // 1 - Define a new route handler, getUserHandler(_:), that returns EventLoopFuture<User>.
    func getUserHandler(_ req: Request)
      -> EventLoopFuture<User> {
      // 2 - Fetch the acronym specified in the request’s parameters and unwrap the returned future.
      Acronym.find(req.parameters.get("acronymID"), on: req.db)
        .unwrap(or: Abort(.notFound))
        .flatMap { acronym in
          // 3 - Use the property wrapper to get the acronym’s owner from the database. This performs a query on the User table to find the user with the ID saved in the database.
          acronym.$user.get(on: req.db)
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
}

//A DTO is a type that represents what a client should send or receive. Your route handler then accepts a DTO and converts it into something your code can use.
struct CreateAcronymData: Content {
  let short: String
  let long: String
  let userID: UUID
}
