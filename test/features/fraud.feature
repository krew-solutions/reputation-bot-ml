Feature: Fraud Detection

  Scenario: Confirmed fraudster cannot vote
    Given a community "Test" with a chat
    And a member "fraudster"
    And a member "alice"
    And "alice" posted message "msg1"
    And "fraudster" has fraud score 90
    When "fraudster" upvotes message "msg1"
    Then the error is "Fraud_blocked"
