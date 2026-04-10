Feature: Vote Casting

  Scenario: Upvote increases author karma
    Given a community "OCaml Devs" with a chat
    And a member "alice"
    And a member "bob"
    And "alice" posted message "msg1"
    When "bob" upvotes message "msg1"
    Then "alice" has positive karma

  Scenario: Downvote produces negative delta
    Given a community "Test" with a chat
    And a member "alice"
    And a member "bob"
    And "alice" posted message "msg1"
    When "bob" downvotes message "msg1"
    Then last karma delta is negative

  Scenario: Self-vote is prohibited
    Given a community "Test" with a chat
    And a member "alice"
    And "alice" posted message "msg1"
    When "alice" upvotes message "msg1"
    Then the error is "Self_vote_prohibited"

  Scenario: Duplicate vote is prohibited
    Given a community "Test" with a chat
    And a member "alice"
    And a member "bob"
    And "alice" posted message "msg1"
    And "bob" upvotes message "msg1"
    When "bob" upvotes message "msg1"
    Then the error is "Duplicate_vote"
