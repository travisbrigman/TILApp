//
//  Application+Testable.swift
//  
//
//  Created by Travis Brigman on 12/7/21.
//

@testable import App
@testable import XCTVapor

extension Application {
  static func testable() throws -> Application {
    let app = Application(.testing)
    try configure(app)
    
    try app.autoRevert().wait()
    try app.autoMigrate().wait()

    return app
  }
}

// 1 - Add an extension to XCTApplicationTester, Vapor’s test wrapper around Application.
extension XCTApplicationTester {
  // 2 - Define a log in method that takes User and returns Token.
  public func login(
    user: User
  ) throws -> Token {
    // 3 - Create a test POST request to /api/users/login — the log in URL — with empty values where needed.
    var request = XCTHTTPRequest(
      method: .POST,
      url: .init(path: "/api/users/login"),
      headers: [:],
      body: ByteBufferAllocator().buffer(capacity: 0)
    )
    // 4 - Set the HTTP Basic Authentication header using Vapor’s BasicAuthorization helpers. Note: The password here must be plaintext text, not the hashed password from User.
    request.headers.basicAuthorization =
      .init(username: user.username, password: "password")
    // 5 Send the request to get the response.
    let response = try performTest(request: request)
    // 6 - Decode the response to Token and return the result.
    return try response.content.decode(Token.self)
  }
    
    // 1 - Add a new method that duplicates the existing app.test(_:_:beforeRequest:afterResponse:) you use in tests. This new method adds loggedInRequest and loggedInUser as parameters. You use these to tell your tests to send an Authorization header or use a specified user, as required.
    @discardableResult
    public func test(
      _ method: HTTPMethod,
      _ path: String,
      headers: HTTPHeaders = [:],
      body: ByteBuffer? = nil,
      loggedInRequest: Bool = false,
      loggedInUser: User? = nil,
      file: StaticString = #file,
      line: UInt = #line,
      beforeRequest: (inout XCTHTTPRequest) throws -> () = { _ in },
      afterResponse: (XCTHTTPResponse) throws -> () = { _ in }
    ) throws -> XCTApplicationTester {
      // 2 - Create a request to use in the test.
      var request = XCTHTTPRequest(
        method: method,
        url: .init(path: path),
        headers: headers,
        body: body ?? ByteBufferAllocator().buffer(capacity: 0)
      )

      // 3 - Determine if this request requires authentication.
      if (loggedInRequest || loggedInUser != nil) {
        let userToLogin: User
        // 4 - Work out the user to use. Note: This requires you to know the user’s password. As all the users in your tests have the password “password”, this isn’t an issue. If no user is specified, use “admin”.
        if let user = loggedInUser {
          userToLogin = user
        } else {
            userToLogin = User(
              name: "Admin",
              username: "admin",
              password: "password",
              email: "admin@localhost.local")
        }

        // 5 - Get a token using login(user:), which you created earlier.
        let token = try login(user: userToLogin)
        // 6 - Add the bearer authorization header to the test request, using the token value retrieved from logging in.
        request.headers.bearerAuthorization =
          .init(token: token.value)
      }

      // 7 - Apply beforeRequest(_:) to the request.
      try beforeRequest(&request)

      // 8 - Get the response and apply afterResponse(_:). Catch any errors and fail the test. This is the same as the standard app.test(_:_:beforeRequest:afterResponse:) method.
      do {
        let response = try performTest(request: request)
        try afterResponse(response)
      } catch {
        XCTFail("\(error)", file: (file), line: line)
        throw error
      }
      return self
    }
}
