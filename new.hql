-- ENUMS --
DEFINE ENUM Gender {
    MALE,
    FEMALE
};

-- FIELDS --
DEFINE FIELD id: Uuid;
DEFINE FIELD name: String;
DEFINE FIELD gender: Gender;
DEFINE FIELD date: Date;

-- ROLES --
DEFINE ROLE father ALLOWS Person {
    constraints: [
        Person.gender == Gender.MALE
    ]
};

DEFINE ROLE mother ALLOWS Person {
    constraints: [
        Person.gender == Gender.FEMALE
    ]
};

DEFINE ROLE son ALLOWS Person {
    constraints: [
        Person.gender == Gender.MALE
    ]
};

DEFINE ROLE daughter ALLOWS Person {
    constraints: [
        Person.gender == Gender.FEMALE
    ]
};

DEFINE ROLE husband ALLOWS Person {
    constraints: [
        Person.gender == Gender.MALE
    ]
};

DEFINE ROLE wife ALLOWS Person {
    constraints: [
        Person.gender == Gender.FEMALE
    ]
};

DEFINE ROLE friend ALLOWS Person;
DEFINE ROLE owner ALLOWS Person;
DEFINE ROLE ownee ALLOWS Dog;

-- NODES --
DEFINE NODE Person {
    id,
    name,
    gender
};

DEFINE NODE Dog {
    id,
    name
};


-- EDGES --
DEFINE EDGE Marriage {
    id,
    date,
    husband <- (ONE),
    wife <- (ONE)
};

DEFINE EDGE Family {
    id,
    father -> (ONE),
    mother -> (ONE),
    son <- (MANY),
    daughter <- (MANY)
};

DEFINE EDGE Friendship {
    id,
    friend <- (MANY)
};

DEFINE EDGE Owns {
    id,
    owner -> (MANY),
    ownee <- (ONE)
};

-- Actual Instances --

-- Nodes --
CREATE NODE doug:Person {
    id = UUID(),
    name = "Doug",
    gender = Gender.MALE
};

CREATE NODE nini:Person {
    id = UUID(),
    name = "Nini",
    gender = Gender.FEMALE
};

CREATE NODE hans:Person {
    id = UUID(),
    name = "Hans",
    gender = Gender.MALE
};

CREATE NODE jarom:Person {
    id = UUID(),
    name = "Jarom",
    gender = Gender.MALE
};

CREATE NODE kip:Person {
    id = UUID(),
    name = "Kip",
    gender = Gender.MALE
};

CREATE NODE tili:Person {
    id = UUID(),
    name = "Tili",
    gender = Gender.FEMALE
};

CREATE NODE lucy:Person {
    id = UUID(),
    name = "Lucy",
    gender = Gender.FEMALE
};

CREATE NODE julianna:Person {
    id = UUID(),
    name = "Julianna",
    gender = Gender.FEMALE
};

CREATE NODE willard:Person {
    id = UUID(),
    name = "Willard",
    gender = Gender.MALE
};

CREATE NODE daniel:Person {
    id = UUID(),
    name = "Daniel",
    gender = Gender.MALE
};

CREATE NODE mikayla:Person {
    id = UUID(),
    name = "Mikayla",
    gender = Gender.FEMALE
};

CREATE NODE nova:Dog {
    id = UUID(),
    name = "Nova",
};

-- Edges --

CREATE EDGE andersonFam:Family {
    id = UUID(),
    father => doug,
    mother => nini,
    son => [hans, jarom, kip]
    daughter => tili
};

CREATE EDGE dne:Marriage {
   id = UUID(),
   husband => doug,
   wife => nini,
   date = DATE("1999/08/20")
};

CREATE EDGE hnl:Marriage {
   id = UUID(),
   husband => hans,
   wife => lucy,
   date = DATE("2022/10/07")
};

CREATE EDGE tnw:Marriage {
   id = UUID(),
   husband => willard,
   wife => tili,
   date = DATE("2024/04/22")
};

CREATE EDGE jnj:Marriage {
   id = UUID(),
   husband => jarom,
   wife => julianna,
   date = DATE("2025/01/02")
};

CREATE EDGE dnm:Marriage {
   id = UUID(),
   husband => daniel,
   wife => mikayla,
   date = DATE("2023/02/12")
};

CREATE EDGE :Friendship {
    id = UUID(),
    friend => [daniel, jarom]
};

CREATE EDGE :Owns {
    id = UUID,
    owner => [daniel, mikayla]
    ownee => nova
};
