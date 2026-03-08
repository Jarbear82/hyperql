DEFINE NAMESPACE Social.Network STRICT_MODE = true;

-- ==========================================
-- CORE SCHEMA: Shared Types & Global Fields
-- ==========================================
DEFINE SCHEMA Core [
    ENUM [
        Gender<INT> {
            MALE = 1,
            FEMALE = 2
        }
    ],
    FIELD [
        id:     UUID         @required DEFAULT UUID(),
        name:   String       @required,
        gender: Enum<Gender> @required,
        age:    Int,
        date:   Date         DEFAULT NOW()
    ],
    NODE [
        Person {
            id,
            name,
            gender,
            age
        } {
            constraints: [
                .age >= 0,
                .age <= 150
            ]
        },
        Dog {
            id,
            name
        }
    ]
];

-- ==========================================
-- MATRIMONY SCHEMA
-- ==========================================
DEFINE SCHEMA Matrimony [
    ROLE [
        husband ALLOWS Person: { .gender == Gender.MALE,   .age >= 18 },
        wife    ALLOWS Person: { .gender == Gender.FEMALE, .age >= 18 }
    ],
    EDGE [
        Marriage {
            husband <- (1),
            wife    <- (1),
            date
        } {
            constraints: {
                different_people: .husband != .wife,
                valid_date:       .date <= NOW()
            }
        }
    ]
];

-- ==========================================
-- FAMILY SCHEMA
-- ==========================================
DEFINE SCHEMA FamilyTree [
    ROLE [
        father   ALLOWS Person: { .gender == Gender.MALE,   .age >= 18 },
        mother   ALLOWS Person: { .gender == Gender.FEMALE, .age >= 18 },
        son      ALLOWS Person: { .gender == Gender.MALE },
        daughter ALLOWS Person: { .gender == Gender.FEMALE }
    ],
    EDGE [
        Family {
            father   -> (1),
            mother   -> (1),
            son      <- (*),
            daughter <- (*)
        } {
            constraints: [
                .father != .mother
            ]
        }
    ]
];

-- ==========================================
-- FRIENDSHIP SCHEMA
-- ==========================================
DEFINE SCHEMA FriendshipNetwork [
    ROLE [
        friend ALLOWS Person
    ],
    EDGE [
        Friendship {
            friend <-> (*)
        }
    ]
];

-- ==========================================
-- PETS SCHEMA
-- ==========================================
DEFINE SCHEMA Pets [
    ROLE [
        owner ALLOWS Person,
        pet   ALLOWS Dog
    ],
    EDGE [
        OwnPet {
            owner -> (2),
            pet   <- (1)
        }
    ]
];

-- ==========================================
-- INSTANCE CREATION
-- ==========================================
CREATE [
    NODE [
        doug:     Person { name = "Doug",     gender = Gender.MALE,   age = 45 },
        nini:     Person { name = "Nini",     gender = Gender.FEMALE, age = 45 },
        hans:     Person { name = "Hans",     gender = Gender.MALE,   age = 20 },
        jarom:    Person { name = "Jarom",    gender = Gender.MALE,   age = 20 },
        kip:      Person { name = "Kip",      gender = Gender.MALE,   age = 20 },
        tili:     Person { name = "Tili",     gender = Gender.FEMALE, age = 20 },
        lucy:     Person { name = "Lucy",     gender = Gender.FEMALE, age = 20 },
        willard:  Person { name = "Willard",  gender = Gender.MALE,   age = 20 },
        julianna: Person { name = "Julianna", gender = Gender.FEMALE, age = 20 },
        daniel:   Person { name = "Daniel",   gender = Gender.MALE,   age = 20 },
        mikayla:  Person { name = "Mikayla",  gender = Gender.FEMALE, age = 20 },
        nova:     Dog    { name = "Nova" }
    ],
    EDGE [
        andersonFam:Family {
            father   => doug,
            mother   => nini,
            son      => [hans, jarom, kip],
            daughter => [tili]
        },
        dne:Marriage {
            husband => doug,
            wife    => nini,
            date    =  DATE("1999-08-20")
        },
        hnl:Marriage {
            husband => hans,
            wife    => lucy,
            date    =  DATE("2022-10-07")
        },
        dnm:Marriage {
            husband => daniel,
            wife    => mikayla,
            date    =  DATE("2023-02-25")
        },
        wnt:Marriage {
            husband => willard,
            wife    => tili,
            date    =  DATE("2024-04-22")
        },
        jnj:Marriage {
            husband => jarom,
            wife    => julianna,
            date    =  DATE("2025-01-02")
        },
        jnd:Friendship {
            friend => [daniel, jarom]
        },
        dmn:OwnPet {
            owner => [daniel, mikayla],
            pet => nova,
        }
    ]
];
