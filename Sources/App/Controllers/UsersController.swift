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
        // 1 - Register getAllHandler(_:) to process GET requests to /api/users/.
        usersRoute.get(use: getAllHandler)
        // 2 - Register getHandler(_:) to process GET requests to /api/users/<USER ID>. This uses a dynamic path component that matches the parameter you search for in getHandler(_:).
        usersRoute.get(":userID", use: getHandler)
        
        usersRoute.get(
          ":userID",
          "acronyms",
          use: getAcronymsHandler)
        
        // 1 - Create a protected route group using HTTP basic authentication, as you did for creating an acronym. This doesn’t use GuardAuthenticationMiddleware since req.auth.require(_:) throws the correct error if a user isn’t authenticated.
        let basicAuthMiddleware = User.authenticator()
        let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
        // 2 - Connect /api/users/login to loginHandler(_:) through the protected group.
        basicAuthGroup.post("login", use: loginHandler)
        
        let tokenAuthMiddleware = Token.authenticator()
        let guardAuthMiddleware = User.guardMiddleware()
        let tokenAuthGroup = usersRoute.grouped(
          tokenAuthMiddleware,
          guardAuthMiddleware)
        tokenAuthGroup.post(use: createHandler)
    }

    // 5 - Define the route handler function.
    func createHandler(_ req: Request)
    throws -> EventLoopFuture<User.Public>
    {
        // 6 - Decode the user from the request body.
        let user = try req.content.decode(User.self)
        user.password = try Bcrypt.hash(user.password)
        // 7 - Save the decoded user. save(on:) returns EventLoopFuture<Void> so use map(_:) to wait for the save to complete and return the saved user.
        return user.save(on: req.db).map { user.convertToPublic() }
    }

    // 1 - Define a new route handler, getAllHandler(_:), that returns EventLoopFuture<[User]>.
    func getAllHandler(_ req: Request)
    -> EventLoopFuture<[User.Public]>
    {
        // 2 - Return all the users using a Fluent query.
        User.query(on: req.db).all().convertToPublic()
    }

    // 3 - Define a new route handler, getHandler(_:), that returns EventLoopFuture<User>.
    func getHandler(_ req: Request)
    -> EventLoopFuture<User.Public>
    {
        // 4 - Return the user specified by the request’s parameter named userID.
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound)).convertToPublic()
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
    
    // 1 - Define a route handler for logging a user in.
    func loginHandler(_ req: Request) throws
      -> EventLoopFuture<Token> {
      // 2 - Get the authenticated user from the request. You’ll protect this route with the HTTP basic authentication middleware. This saves the user’s identity in the request’s authentication cache, allowing you to retrieve the user object later. req.auth.require(_:) throws an authentication error if there’s no authenticated user.
      let user = try req.auth.require(User.self)
      // 3 - Create a token for the user.
      let token = try Token.generate(for: user)
      // 4 - Save and return the token.
      return token.save(on: req.db).map { token }
    }
}
