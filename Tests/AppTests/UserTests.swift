//
//  UserTests.swift
//  
//
//  Created by Travis Brigman on 12/7/21.
//

@testable import App
import XCTVapor

final class UserTests: XCTestCase {
    let usersName = "Alice"
    let usersUsername = "alicea"
    let usersURI = "/api/users/"
    var app: Application!
    
    override func setUpWithError() throws {
      app = try Application.testable()
    }
    
    override func tearDownWithError() throws {
      app.shutdown()
    }
    
    func testUsersCanBeRetrievedFromAPI() throws {
      let user = try User.create(
        name: usersName,
        username: usersUsername,
        on: app.db)
      _ = try User.create(on: app.db)

      try app.test(.GET, usersURI, afterResponse: { response in
        XCTAssertEqual(response.status, .ok)
        let users = try response.content.decode([User].self)
        
        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(users[0].name, usersName)
        XCTAssertEqual(users[0].username, usersUsername)
        XCTAssertEqual(users[0].id, user.id)
      })
    }
    
    func testUserCanBeSavedWithAPI() throws {
      // 1 - Create a User object with known values.
        let user = User(
          name: usersName,
          username: usersUsername,
          password: "password")
      
      // 2 - Use test(_:_:beforeRequest:afterResponse:) to send a POST request to the API
      try app.test(.POST, usersURI, beforeRequest: { req in
        // 3 - Encode the request with the created user before you send the request.
        try req.content.encode(user)
      }, afterResponse: { response in
        // 4 - Decode the response body into a User object.
        let receivedUser = try response.content.decode(User.self)
        // 5 - Assert the response from the API matches the expected values.
        XCTAssertEqual(receivedUser.name, usersName)
        XCTAssertEqual(receivedUser.username, usersUsername)
        XCTAssertNotNil(receivedUser.id)
        
        // 6 - Make another request to get all the users from the API.
        try app.test(.GET, usersURI,
          afterResponse: { secondResponse in
            // 7 - Ensure the response only contains the user you created in the first request.
            let users =
              try secondResponse.content.decode([User].self)
            XCTAssertEqual(users.count, 1)
            XCTAssertEqual(users[0].name, usersName)
            XCTAssertEqual(users[0].username, usersUsername)
            XCTAssertEqual(users[0].id, receivedUser.id)
          })
      })
    }
    
    func testGettingASingleUserFromTheAPI() throws {
      // 1 - Save a user in the database with known values.
      let user = try User.create(
        name: usersName,
        username: usersUsername,
        on: app.db)
      
      // 2 - Get the user at /api/users/<USER ID>.
      try app.test(.GET, "\(usersURI)\(user.id!)",
        afterResponse: { response in
          let receivedUser = try response.content.decode(User.self)
          // 3 - Assert the values are the same as provided when creating the user.
          XCTAssertEqual(receivedUser.name, usersName)
          XCTAssertEqual(receivedUser.username, usersUsername)
          XCTAssertEqual(receivedUser.id, user.id)
        })
    }
    
    func testGettingAUsersAcronymsFromTheAPI() throws {
      // 1 - Create a user for the acronyms.
      let user = try User.create(on: app.db)
      // 2 - Define some expected values for an acronym.
      let acronymShort = "OMG"
      let acronymLong = "Oh My God"
      
      // 3 - Create two acronyms in the database using the created user. Use the expected values for the first acronym.
      let acronym1 = try Acronym.create(
        short: acronymShort,
        long: acronymLong,
        user: user,
        on: app.db)
      _ = try Acronym.create(
        short: "LOL",
        long: "Laugh Out Loud",
        user: user,
        on: app.db)

      // 4 - Get the user’s acronyms from the API by sending a request to /api/users/<USER ID>/acronyms.
      try app.test(.GET, "\(usersURI)\(user.id!)/acronyms",
        afterResponse: { response in
          let acronyms = try response.content.decode([Acronym].self)
          // 5 - Assert the response returns the correct number of acronyms and the first one matches the expected values.
          XCTAssertEqual(acronyms.count, 2)
          XCTAssertEqual(acronyms[0].id, acronym1.id)
          XCTAssertEqual(acronyms[0].short, acronymShort)
          XCTAssertEqual(acronyms[0].long, acronymLong)
        })
    }
}
