Multiple Transactions of the same type can be made more readable by using the following syntax:

```hyperql
-- ENUMS --
DEFINE ENUM Gender {
    MALE,
    FEMALE
};

-- FIELDS --
DEFINE FIELD [
    id: UUID @required,
    name: String @required,
    gender: Enum<Gender> @required,
    age: Int,
    date: Date,
];



-- ROLES --

DEFINE ROLE [
    father { .gender == .MALE, .age >= 18 },    
    mother { .gender == .FEMALE, .age >= 18 },    
    son { .gender == .MALE },    
    daughter { .gender == .FEMALE, },    
    husband { .gender == .MALE, .age >= 18 },    
    wife { .gender == .FEMALE, .age >= 18 },    
    friend,
    owner,
] ALLOWS Person;

DEFINE ROLE pet ALLOWS Dog;

-- NODES --
DEFINE NODE [
    Person {
        id,
        name,
        gender,
        age
    } {
        constraints: { .age >= 0, .age <= 150 }
    };

    Dog { id, name };
];

-- EDGES --

DEFINE EDGE [
    Marriage {
        husband <- (ONE),
        wife <- (ONE),
        date
    } {
        constraints: {
            different_people: .husband != .wife,
            valid_date: .date <= NOW()
        }
    },
    Family {
        father -> (ONE),
        mother -> (ONE),
        son <- (MANY),
        daughter <- (MANY)
    } {
        constraints: { .father != .mother }
    },
    Friendship { friend <- (MANY) },
    Owns { owner -> (MANY), pet <- (ONE) },
];

-- Instances --

CREATE NODE [
    doug:Person {
        id = UUID(),
        name = "Doug",
        gender = .MALE,
        age = 50
    },
    nini:Person {
        id = UUID(),
        name = "Nini",
        gender = .FEMALE,
        age = 48
    },
    hans:Person {
        id = UUID(),
        name = "Hans",
        gender = .MALE,
        age = 20
    },
    jarom:Person {
        id = UUID(),
        name = "Jarom",
        gender = .MALE,
        age = 18
    },
    kip:Person {
        id = UUID(),
        name = "Kip",
        gender = .MALE,
        age = 15
    },
    tili:Person {
        id = UUID(),
        name = "Tili",
        gender = .FEMALE,
        age = 12
    }

];

CREATE EDGE [
    andersonFam:Family {
        father => doug,
        mother => nini,
        son => [hans, jarom, kip],
        daughter => [tili]
    },
    dne:Marriage {
        husband => doug,
        wife => nini,
        date = DATE("1999/08/20")
    }
];

CREATE [
    NODE [
        lucy:Person {
            id = UUID(),
            name = "Lucy",
            gender = .FEMALE,
            age = 24
        },
        julianna:Person {
            id = UUID(),
            name = "Julianna",
            gender = .FEMALE,
            age = 24
        },
        willard:Person {
            id = UUID(),
            name = "Willard",
            gender = .MALE,
            age = 25
        },
        daniel:Person {
            id = UUID(),
            name = "Daniel",
            gender = .MALE,
            age = 23
        },
        mikayla:Person {
            id = UUID(),
            name = "Mikayla",
            gender = .FEMALE,
            age = 25
        },
        nova:Dog {
            id = UUID(),
            name = "Nova"
        }
    
    ],
    EDGE [
        hnl:Marriage {
            husband => hans,
            wife => lucy,
            date = DATE("2022/10/07")
        },
        jnj:Marriage {
            husband => jarom,
            wife => julianna,
            date = DATE("2025/01/02")
        },
        wnt:Marriage {
            husband => willard,
            wife => tili,
            date = DATE("2024/04/22")
        },
        dnm:Marriage {
            husband => daniel,
            wife => mikayla,
            date = DATE("2023/02/25")
        },
        jnd:Friendship { friend => [daniel, jarom] },
        dmn:Own {
            owner = [daniel, mikayla],
            pet = nova
        }
    ]
];

```


```hyperql
// Single Syntax
DEFINE ROLE character ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature];
DEFINE ROLE combatant ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature];
DEFINE ROLE quest_giver ALLOWS [NonPlayerCharacter, Faction, Deity];
DEFINE ROLE quest_target ALLOWS [NonPlayerCharacter, Creature, Location, Item];
DEFINE ROLE merchant ALLOWS [NonPlayerCharacter];
DEFINE ROLE customer ALLOWS [PlayerCharacter, NonPlayerCharacter];
DEFINE ROLE owner ALLOWS [PlayerCharacter, NonPlayerCharacter, Faction];
DEFINE ROLE possessor ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature, Location];
DEFINE ROLE member ALLOWS [PlayerCharacter, NonPlayerCharacter];
DEFINE ROLE organization ALLOWS [Faction, Guild];
DEFINE ROLE parent ALLOWS [Location];
DEFINE ROLE child ALLOWS [Location];
DEFINE ROLE worshipper ALLOWS [PlayerCharacter, NonPlayerCharacter, Faction];
DEFINE ROLE divine ALLOWS [Deity];
DEFINE ROLE teacher ALLOWS [NonPlayerCharacter];
DEFINE ROLE student ALLOWS [PlayerCharacter, NonPlayerCharacter];
DEFINE ROLE source ALLOWS [Location, NonPlayerCharacter, Event];
DEFINE ROLE destination ALLOWS [Location];
DEFINE ROLE participant ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature];
DEFINE ROLE scene ALLOWS [Event, Encounter];

// Alt1 Multi-syntax
DEFINE ROLE [
    character ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature],
    combatant ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature],
    quest_giver ALLOWS [NonPlayerCharacter, Faction, Deity],
    quest_target ALLOWS [NonPlayerCharacter, Creature, Location, Item],
    merchant ALLOWS [NonPlayerCharacter],
    customer ALLOWS [PlayerCharacter, NonPlayerCharacter],
    owner ALLOWS [PlayerCharacter, NonPlayerCharacter, Faction],
    possessor ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature, Location],
    member ALLOWS [PlayerCharacter, NonPlayerCharacter],
    organization ALLOWS [Faction, Guild],
    parent ALLOWS [Location],
    child ALLOWS [Location],
    worshipper ALLOWS [PlayerCharacter, NonPlayerCharacter, Faction],
    divine ALLOWS [Deity],
    teacher ALLOWS [NonPlayerCharacter],
    student ALLOWS [PlayerCharacter, NonPlayerCharacter],
    source ALLOWS [Location, NonPlayerCharacter, Event],
    destination ALLOWS [Location],
    participant ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature],
    scene ALLOWS [Event, Encounter],
];

// Alt2 Multi-syntax
DEFINE ROLE [
    [
        character, 
        combatant, 
        customer, 
        owner, 
        possessor, 
        member, 
        worshipper, 
        student, 
        participant
    ] ALLOWS PlayerCharacter,
    [
        character, 
        combatant,
        quest_giver,
        quest_target,
        merchant,
        customer,
        owner,
        possessor,
        member,
        worshipper,
        teacher,
        student,
        source,
        participant
    ] ALLOWS NonPlayerCharacter,
    [
        character,
        combatant,
        quest_target,
        possesor,
        participant
    ] ALLOWS Creature,
    [
        quest_giver,
        owner,
        organization,
        worshipper
    ] ALLOWS Faction,
    [ quest_giver, divine ] ALLOWS Deity,
    [
        quest_target,
        possessor,
        parent,
        child,
        source,
        destination  
    ] ALLOWS Location,
    [ quest_target ] ALLOWS Item,
    [ organization ] ALLOWS Guild,
    [ source, scene ] ALLOWS Event,
    [ scene ] ALLOWS Encounter
];

// Alt3 Multi-syntax
DEFINE ROLE [
    [
        [
            [
                character,
                combatant,
                possessor,
                participant
            ] ALLOWS Creature,
            customer, 
            owner,
            member, 
            worshipper, 
            student, 
        ] ALLOWS PlayerCharacter,
        quest_giver,
        quest_target ALLOWS Creature,
        merchant,
        teacher,
        source,
    ] ALLOWS NonPlayerCharacter,
    [
        quest_giver,
        owner,
        organization ALLOWS Guild,
        worshipper
    ] ALLOWS Faction,
    [ quest_giver, divine ] ALLOWS Deity,
    [
        quest_target ALLOWS Item,
        possessor,
        parent,
        child,
        source,
        destination  
    ] ALLOWS Location,
    [ 
        source,
        scene ALLOWS Encounter
    ] ALLOWS Event,
];
```
