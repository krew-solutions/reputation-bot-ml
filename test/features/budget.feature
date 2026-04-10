Feature: Budget Exhaustion

  Scenario: Hourly budget of 5 votes is enforced
    Given a community "Test" with a chat
    And a member "voter"
    And a member "author1"
    And a member "author2"
    And a member "author3"
    And a member "author4"
    And a member "author5"
    And a member "author6"
    And "author1" posted message "m1"
    And "author2" posted message "m2"
    And "author3" posted message "m3"
    And "author4" posted message "m4"
    And "author5" posted message "m5"
    And "author6" posted message "m6"
    And "voter" upvotes message "m1"
    And "voter" upvotes message "m2"
    And "voter" upvotes message "m3"
    And "voter" upvotes message "m4"
    And "voter" upvotes message "m5"
    When "voter" upvotes message "m6"
    Then the error is "Budget_exhausted"
