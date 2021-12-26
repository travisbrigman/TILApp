//
//  File.swift
//  
//
//  Created by Travis Brigman on 12/26/21.
//

import ImperialGoogle
import Vapor
import Fluent

struct ImperialController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
      func processGoogleLogin(request: Request, token: String)
        throws -> EventLoopFuture<ResponseEncodable> {
          request.eventLoop.future(request.redirect(to: "/"))
        }
      
      guard let googleCallbackURL =
        Environment.get("GOOGLE_CALLBACK_URL") else {
          fatalError("Google callback URL not set")
      }
      try routes.oAuth(
        from: Google.self,
        authenticate: "login-google",
        callback: googleCallbackURL,
        scope: ["profile", "email"],
        completion: processGoogleLogin)
  }
    
    
}

struct GoogleUserInfo: Content {
  let email: String
  let name: String
}

extension Google {
  // 1 - Add a new method to Imperial’s Google service that gets a user’s details from the Google API.
  static func getUser(on request: Request)
    throws -> EventLoopFuture<GoogleUserInfo> {
      // 2 - Set the headers for the request by adding the OAuth token to the authorization header.
      var headers = HTTPHeaders()
      headers.bearerAuthorization =
        try BearerAuthorization(token: request.accessToken())

      // 3 - Set the URL for the request — this is Google’s API to get the user’s information. This uses Vapor’s URI type, which Client requires.
      let googleAPIURL: URI =
        "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
      // 4 - Use request.client to send the request to Google. get() sends an HTTP GET request to the URL provided. Unwrap the returned future response.
      return request
        .client
        .get(googleAPIURL, headers: headers)
        .flatMapThrowing { response in
        // 5 - Ensure the response status is 200 OK.
        guard response.status == .ok else {
          // 6 - Otherwise, return to the login page if the response was 401 Unauthorized or return an error.
          if response.status == .unauthorized {
            throw Abort.redirect(to: "/login-google")
          } else {
            throw Abort(.internalServerError)
          }
        }
        // 7 - Decode the data from the response to GoogleUserInfo and return the result.
        return try response.content
          .decode(GoogleUserInfo.self)
      }
  }
}
