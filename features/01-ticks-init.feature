Feature: Initialization of Tick
  Scenario: Initialization of Tick
    When creating a tick without parameters it should raise ArgumentError
  
  Scenario Outline: Initialization of Tick with different valid parameter types
    When creating a tick with '<params>' it should result in <timestamp> and <price>
    Examples:
      | params                                 | timestamp     |  price  | 
      | {s: :foo, t: 1555767235, p: 123 }      | 1555767235000 |  123.0  | 
      | {s: "foo", t: 1555767235123, p: 1.21 } | 1555767235123 |    1.21 | 
      | ["foo",  "1555767235", "225" ]         | 1555767235000 |  225.0  | 
      | :foo, 1555767235, 225                  | 1555767235000 |  225.0  |
      | 1555767235, 225                        | 1555767235000 |  225.0  |
