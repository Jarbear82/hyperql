-- ENUMS --
DEFINE ENUM Gender {
    MALE,
    FEMALE
};

-- FIELDS --
DEFINE FIELD id: UUID @required;
DEFINE FIELD name: String @required;
DEFINE FIELD gender: Enum<Gender> @required;
DEFINE FIELD age: Int;
DEFINE FIELD date: Date;

-- ROLES --
DEFINE ROLE father ALLOWS Person: {
    .gender == .MALE,
    .age >= 18
};

DEFINE ROLE mother ALLOWS Person: {
    .gender == .FEMALE,
    .age >= 18
};

DEFINE ROLE son ALLOWS Person: {
    .gender == .MALE
};

DEFINE ROLE daughter ALLOWS Person: {
    .gender == .FEMALE
};

DEFINE ROLE husband ALLOWS Person: {
    .gender == .MALE,
    .age >= 18
};

DEFINE ROLE wife ALLOWS Person: {
    .gender == .FEMALE,
    .age >= 18
};

DEFINE ROLE friend ALLOWS Person;
DEFINE ROLE owner ALLOWS Person;
DEFINE ROLE pet ALLOWS Dog;

-- NODES --
DEFINE NODE Person {
    id,
    name,
    gender,
    age
} {
    constraints: [
        .age >= 0,
        .age <= 150
    ]
};

DEFINE NODE Dog {
    id,
    name
};

-- EDGES --
DEFINE EDGE Marriage {
    husband <- (ONE),
    wife <- (ONE),
    date
} {
    constraints: {
        different_people: .husband != .wife,
        valid_date: .date <= NOW()
    }
};

DEFINE EDGE Family {
    father -> (ONE),
    mother -> (ONE),
    son <- (MANY),
    daughter <- (MANY)
} {
    constraints: [
        .father != .mother
    ]
};

DEFINE EDGE Friendship {
    friend <- (MANY)
};

DEFINE EDGE Owns {
    owner -> (ONE),
    pet <- (ONE)
};

-- Instances --
CREATE NODE doug:Person {
    id = UUID(),
    name = "Doug",
    gender = .MALE,
    age = 50
};

CREATE NODE nini:Person {
    id = UUID(),
    name = "Nini",
    gender = .FEMALE,
    age = 48
};

CREATE NODE hans:Person {
    id = UUID(),
    name = "Hans",
    gender = .MALE,
    age = 20
};

CREATE NODE jarom:Person {
    id = UUID(),
    name = "Jarom",
    gender = .MALE,
    age = 18
};

CREATE NODE kip:Person {
    id = UUID(),
    name = "Kip",
    gender = .MALE,
    age = 15
};

CREATE NODE tili:Person {
    id = UUID(),
    name = "Tili",
    gender = .FEMALE,
    age = 12
};

CREATE EDGE andersonFam:Family {
    father => doug,
    mother => nini,
    son => [hans, jarom, kip],
    daughter => [tili]
};

CREATE EDGE dne:Marriage {
    husband => doug,
    wife => nini,
    date = DATE("1999/08/20")
};
