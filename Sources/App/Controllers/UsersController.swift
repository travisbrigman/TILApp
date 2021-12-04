//
//  File.swift
//
//
//  Created by Travis Brigman on 12/3/21.
//

import Vapor

// 1 - Define a new type UsersController that conforms to RouteCollection.
struct UsersController: RouteCollection {
    // 2 - Implement boot(routes:) as required by RouteCollection.
    func boot(routes: RoutesBuilder) throws {
        // 3 - Create a new route group for the path /api/users.
        let usersRoute = routes.grouped("api", "users")
        // 4 - Register createHandler(_:) to handle a POST request to /api/users.
        usersRoute.post(use: createHandler)

        // 1 - Register getAllHandler(_:) to process GET requests to /api/users/.
        usersRoute.get(use: getAllHandler)
        // 2 - Register getHandler(_:) to process GET requests to /api/users/<USER ID>. This uses a dynamic path component that matches the parameter you search for in getHandler(_:).
        usersRoute.get(":userID", use: getHandler)
        
        usersRoute.get(
          ":userID",
          "acronyms",
          use: getAcronymsHandler)
    }

    // 5 - Define the route handler function.
    func createHandler(_ req: Request)
        throws -> EventLoopFuture<User>
    {
        // 6 - Decode the user from the request body.
        let user = try req.content.decode(User.self)
        // 7 - Save the decoded user. save(on:) returns EventLoopFuture<Void> so use map(_:) to wait for the save to complete and return the saved user.
        return user.save(on: req.db).map { user }
    }

    // 1 - Define a new route handler, getAllHandler(_:), that returns EventLoopFuture<[User]>.
    func getAllHandler(_ req: Request)
        -> EventLoopFuture<[User]>
    {
        // 2 - Return all the users using a Fluent query.
        User.query(on: req.db).all()
    }

    // 3 - Define a new route handler, getHandler(_:), that returns EventLoopFuture<User>.
    func getHandler(_ req: Request)
        -> EventLoopFuture<User>
    {
        // 4 - Return the user specified by the request’s parameter named userID.
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
    }

    // 1 - Define a new route handler, getAcronymsHandler(_:), that returns EventLoopFuture<[Acronym]>.
    func getAcronymsHandler(_ req: Request)
        -> EventLoopFuture<[Acronym]>
    {
        // 2 - Fetch the user specified in the request’s parameters and unwrap the returned future.
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { user in
                // 3 - Use the new property wrapper created above to get the acronyms using a Fluent query to return all the acronyms. Remember, this uses the property wrapper‘s projected value, not the wrapped value.
                user.$acronyms.get(on: req.db)
            }
    }
}
