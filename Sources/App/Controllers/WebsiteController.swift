//
//  WebsiteController.swift
//
//
//  Created by Travis Brigman on 12/11/21.
//

import Foundation
import Leaf
import Vapor

// 1 - Declare a new WebsiteController type that conforms to RouteCollection.
struct WebsiteController: RouteCollection {
    // 2 - Implement boot(routes:) as required by RouteCollection.
    func boot(routes: RoutesBuilder) throws {
        // 3 - Register indexHandler(_:) to process GET requests to the router’s root path, i.e., a request to /.
        routes.get(use: indexHandler)
        routes.get("acronyms", ":acronymID", use: acronymHandler)
        routes.get("users", ":userID", use: userHandler)
        routes.get("users", use: allUsersHandler)
    }

    // 4 - Implement indexHandler(_:) that returns EventLoopFuture<View>.
    func indexHandler(_ req: Request)
      -> EventLoopFuture<View> {
        // 1 - Use a Fluent query to get all the acronyms from the database.
        Acronym.query(on: req.db).all().flatMap { acronyms in
            // 2 - Add the acronyms to IndexContext if there are any, otherwise set the property to nil. Leaf can check for nil in the template.
//            let acronymsData = acronyms.isEmpty ? nil : acronyms
            let context = IndexContext(
              title: "Home page",
              acronyms: acronyms)
            return req.view.render("index", context)
        }
    }
    
    // 1 - Declare a new route handler, acronymHandler(_:), that returns EventLoopFuture<View>.
    func acronymHandler(_ req: Request)
      -> EventLoopFuture<View> {
        // 2 - Extract the acronym from the request’s parameters and unwrap the result. Return a 404 Not Found if there is no acronym.
        Acronym.find(req.parameters.get("acronymID"), on: req.db)
          .unwrap(or: Abort(.notFound))
          .flatMap { acronym in
            // 3 - Get the user for acronym and unwrap the result.
            acronym.$user.get(on: req.db).flatMap { user in
              // 4 - Create an AcronymContext that contains the appropriate details and render the page using the acronym.leaf template.
              let context = AcronymContext(
                title: acronym.short,
                acronym: acronym,
                user: user)
              return req.view.render("acronym", context)
            }
        }
    }
    
    // 1 - Define the route handler for the user page that returns EventLoopFuture<View>.
    func userHandler(_ req: Request)
      -> EventLoopFuture<View> {
        // 2 - Get the user from the request’s parameters and unwrap the future.
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { user in
            // 3 - Get the user’s acronyms using the @Children property wrapper’s project value and unwrap the future.
            user.$acronyms.get(on: req.db).flatMap { acronyms in
              // 4 - Create a UserContext, then render user.leaf, returning the result. In this case, you’re not setting the acronyms array to nil if it’s empty. This is not required as you’re checking the count in template.
              let context = UserContext(
                title: user.name,
                user: user,
                acronyms: acronyms)
              return req.view.render("user", context)
            }
        }
    }
    
    // 1 - Define a route handler for the “All Users” page that returns EventLoopFuture<View>.
    func allUsersHandler(_ req: Request)
      -> EventLoopFuture<View> {
        // 2 - Get the users from the database and unwrap the future.
        User.query(on: req.db)
          .all()
          .flatMap { users in
            // 3 - Create an AllUsersContext and render the allUsers.leaf template, then return the result.
            let context = AllUsersContext(
              title: "All Users",
              users: users)
            return req.view.render("allUsers", context)
        }
    }
    struct IndexContext: Encodable {
        let title: String
        let acronyms: [Acronym]
    }
}

struct AcronymContext: Encodable {
  let title: String
  let acronym: Acronym
  let user: User
}

struct UserContext: Encodable {
  let title: String
  let user: User
  let acronyms: [Acronym]
}

struct AllUsersContext: Encodable {
  let title: String
  let users: [User]
}
