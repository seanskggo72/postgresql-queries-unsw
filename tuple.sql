create table Countries (
	id          integer, -- PG: serial
	code        char(3) not null unique,
	name        LongName not null,
	primary key (id)
);

create table Buildings (
	id          integer, -- PG: serial
	unswid      ShortString not null unique,
	name        LongName not null,
	campus      CampusType,
	gridref     char(4),
	primary key (id)
);

create table Room_types (
	id          integer, -- PG: serial
	description MediumString not null,
	primary key (id)
);

create table Rooms (
	id          integer, -- PG: serial
	unswid      ShortString not null unique,
	rtype       integer references Room_types(id),
	name        ShortName not null,
	longname    LongName,
	building    integer references Buildings(id),
	capacity    integer check (capacity >= 0),
	primary key (id)
);

create table Facilities (
	id          integer, -- PG: serial
	description MediumString not null,
	primary key (id)
);

create table Room_facilities (
	room        integer references Rooms(id),
	facility    integer references Facilities(id),
	primary key (room,facility)
);

create table OrgUnit_types (
	id          integer, -- PG: serial
	name        ShortName not null,
	primary key (id)
);

create table OrgUnits (
	id          integer, -- PG: serial
	utype       integer not null references OrgUnit_types(id),
	name        MediumString not null,
	longname    LongString,
	unswid      ShortString,
	phone       PhoneNumber,
	email       EmailString,
	website     URLString,
	starting    date, -- not null
	ending      date,
	primary key (id)
);

create table OrgUnit_groups (
	owner	    integer references OrgUnits(id),
	member      integer references OrgUnits(id),
	primary key (owner,member)
);

create table Terms (
	id          integer, -- PG: serial
	unswid      integer not null unique,
	year        CourseYearType,
	session     char(2) not null, -- has constraint in database
	name        ShortName not null,
	longname    LongName not null,
	starting    date not null,
	ending      date not null,
	startBrk    date, -- start of mid-semester break
	endBrk      date, -- end of mid-semester break
	endWD       date, -- last date to withdraw without academic penalty
	endEnrol    date, -- last date to enrol without special permission
	census      date, -- last date to withdraw without paying for course
	primary key (id)
);

create table Public_holidays (
	term        integer references Terms(id),
	description MediumString, -- e.g. Good Friday, Easter Day
	day         date
);

create table Staff_role_types (
	id          char(1),
	description ShortString,
	primary key (id)
);

create table Staff_role_classes (
	id          char(1),
	description ShortString,
	primary key (id)
);

create table Staff_roles (
	id          integer, -- PG: serial
	rtype       char(1) references Staff_role_types(id),
	rclass      char(1) references Staff_role_classes(id),
	name        LongString not null,
	description LongString,
	primary key (id)
);

create table People (
	id          integer, -- PG: serial
	unswid      integer unique, -- staff/student id (can be null)
	password    ShortString not null,
	family      LongName,
	given       LongName not null,
	title       ShortName, -- e.g. "Prof", "A/Prof", "Dr", ...
	sortname    LongName not null,
	name        LongName not null,
	street      LongString,
	city        MediumString,
	state       MediumString,
	postcode    ShortString,
	country     integer references Countries(id),
	homephone   PhoneNumber, -- should be not null
	mobphone    PhoneNumber,
	email       EmailString not null,
	homepage    URLString,
	gender      char(1) check (gender in ('m','f')),
	birthday    date,
	origin      integer references Countries(id),  -- country where born
	primary key (id)
);

create table Students (
	id          integer references People(id),
	stype       varchar(5) check (stype in ('local','intl')),
	primary key (id)
);

create table Student_groups (
	id          integer, -- PG: serial
	name        LongName unique not null,
	definition  TextString not null, -- SQL query to get student(id)'s
	primary key (id)
);

create table Staff (
	id          integer references People(id),
	office      integer referencNumber, -- full number, not just extension
	employed    date noes Rooms(id),
	phone       Phonet null,
	supervisor  integer references Staff(id),
	primary key (id)
);

create table Affiliations (
	staff       integer references Staff(id),
	orgUnit     integer references OrgUnits(id),
	role        integer references Staff_roles(id),
	isPrimary   boolean, -- is this role the basis for their employment?
	starting    date not null, -- when they commenced this role
	ending      date,  -- when they finshed; null means current
	primary key (staff,orgUnit,role,starting)
);

create table Programs (
	id          integer, -- PG: serial
	code        char(4) not null, -- e.g. 3978, 3645, 3648
	name        LongName not null,
	uoc         integer check (uoc >= 0),
	offeredBy   integer references OrgUnits(id),
	career      CareerType,
	duration    integer,  -- #months
	description TextString, -- PG: text
	firstOffer  integer references Terms(id), -- should be not null
	lastOffer   integer references Terms(id), -- null means current
	primary key (id)
);

create table Streams (
	id          integer, -- PG: serial
	code        char(6) not null, -- e.g. COMPA1, SENGA1
	name        LongName not null,
	offeredBy   integer references OrgUnits(id),
	stype       ShortString,
	description TextString,
	firstOffer  integer references Terms(id), -- should be not null
	lastOffer   integer references Terms(id), -- null means current
	primary key (id)
);

create table Degree_types (
	id          integer, -- PG: serial
	unswid      ShortName not null unique, -- e.g. BSc, BSc(CompSci), BE, PhD
	name        MediumString not null,  -- e.g. Bachelor of Science
	prefix      MediumString,
	career      CareerType,
	aqf_level   integer check (aqf_level > 0),
	primary key (id)
);

create table Program_degrees (
	program     integer references Programs(id),
	degree      integer references Degree_types(id),
	name        LongString not null,
	abbrev      MediumString,
	primary key (program,degree)
);

create table Degrees_awarded (
	student     integer references Students(id),
	program     integer references Programs(id),
	graduated   date,	
	primary key (student,program)
);

create table Academic_standing (
	id          integer,
	standing    ShortName not null,
	notes       TextString,
	primary key (id)
);

create table Subjects (
	id          integer, -- PG: serial
	code        char(8) not null, -- PG: check (code ~ '[A-Z]{4}[0-9]{4}'),
	name        MediumName not null,
	longname    LongName,
	uoc         integer check (uoc >= 0),
	offeredBy   integer references OrgUnits(id),
	eftsload    float,
	career      CareerType,
	syllabus    TextString, -- PG: text
	contactHPW  float, -- contact hours per week
	_excluded   text,    -- plain text from MAPPS
	excluded    integer, -- references Acad_object_groups(id),
	_equivalent text,    -- plain textfrom MAPPS
	equivalent  integer, -- references Acad_object_groups(id),
	_prereq     text,    -- plain text from MAPPS
	prereq      integer, -- references Rules(id)
	replaces    integer references Subjects(id),
	firstOffer  integer references Terms(id), -- should be not null
	lastOffer   integer references Terms(id), -- null means current
	primary key (id)
);

create table Courses (
	id          integer, -- PG: serial
	subject     integer not null references Subjects(id),
	term        integer not null references Terms(id),
	homepage    URLString,
	primary key (id)
);

create table Course_staff (
	course      integer references Courses(id),
	staff       integer references Staff(id),
	role        integer references Staff_roles(id),
	primary key (course,staff,role)
);

create table Course_quotas (
	course      integer references Courses(id),
	sgroup      integer references Student_groups(id),
	quota       integer not null,
	primary key (course,sgroup)
);

create table Program_enrolments (
	id          integer,
	student     integer not null references Students(id),
	term        integer not null references Terms(id),
	program     integer not null references Programs(id),
	wam         real,
	standing    integer references Academic_standing(id),
	advisor     integer references Staff(id),
	notes       TextString,
	primary key (id)
);

create table Stream_enrolments (
	partOf      integer references Program_enrolments(id),
	stream      integer references Streams(id),
	primary key (partOf,stream)
);

create table Course_enrolments (
	student     integer references Students(id),
	course      integer references Courses(id),
	mark        integer check (mark >= 0 and mark <= 100),
	grade       GradeType,
	stuEval     integer check (stuEval >= 1 and stuEval <= 6),
	primary key (student,course)
);

create table Books (
	id          integer, -- PG: serial
	isbn        varchar(20) unique,
	title       LongString not null,
	authors     LongString not null,
	publisher   LongString not null,
	edition     integer,
	pubYear     integer not null check (pubYear > 1900),
	primary key (id)
);

create table Course_books (
	course      integer references Courses(id),
	book        integer references Books(id),
	bktype      varchar(10) not null check (bktype in ('Text','Reference')),
	primary key (course,book)
);

create table Class_types (
	id          integer, -- PG: serial
	unswid      ShortString not null unique,
	name        MediumName not null,
	description MediumString,
	primary key (id)
);

create table Classes (
	id          integer, -- PG: serial
	course      integer not null references Courses(id),
	room        integer not null references Rooms(id),
	ctype       integer not null references Class_types(id),
	dayOfWk     integer not null check (dayOfWk >= 0 and dayOfWk <= 6),
	                                  -- Sun=0 Mon=1 Tue=2 ... Sat=6
	startTime   integer not null check (startTime >= 8 and startTime <= 22),
	endTime     integer not null check (endTime >= 9 and endTime <= 23),
	                                  -- time of day, between 8am and 11pm
	startDate   date not null,
	endDate     date not null,
	repeats     integer, -- every X weeks
	primary key (id)
);

create table Class_teachers (
	class       integer references Classes(id),
	teacher     integer references Staff(id),
	primary key (class,teacher)
);

create table Class_enrolments (
	student     integer references Students(id),
	class       integer references Classes(id),
	primary key (student,class)
);

create table External_subjects (
	id          integer,
	extsubj     LongName not null,
	institution LongName not null,
	yearOffered CourseYearType,
	equivTo     integer not null references Subjects(id),
--	creator     integer not null references Staff(id),
--	created     date not null,
	primary key (id)
);

create table Variations (
	student     integer references Students(id),
	program     integer references Programs(id),
	subject     integer references Subjects(id),
	vtype       VariationType not null,
	intEquiv    integer references Subjects(id),
	extEquiv    integer references External_subjects(id),
	yearPassed  CourseYearType,
	mark        integer check (mark > 0), -- if we know it
	approver    integer not null references Staff(id),
	approved    date not null,
	primary key (student,program,subject),
	constraint  TwoCases check
	              ((intEquiv is null and extEquiv is not null)
	              or
	               (intEquiv is not null and extEquiv is null))
);

create table Acad_object_groups (
	id          integer,
	name        LongName,
	gtype       AcadObjectGroupType not null,
	glogic      AcadObjectGroupLogicType,
	gdefBy      AcadObjectGroupDefType not null,
	negated     boolean default false,
	parent      integer, -- references Acad_object_groups(id),
	definition  TextString, -- if pattern or query-based group
	primary key (id)
);

alter table Acad_object_groups
	add foreign key (parent) references Acad_object_groups(id);

alter table Subjects
	add foreign key (excluded) references Acad_object_groups(id);

alter table Subjects
	add foreign key (equivalent) references Acad_object_groups(id);

create table Subject_group_members (
	subject     integer references Subjects(id),
	ao_group    integer references Acad_object_groups(id),
	primary key (subject,ao_group)
);

create table Stream_group_members (
	stream      integer references Streams(id),
	ao_group    integer references Acad_object_groups(id),
	primary key (stream,ao_group)
);

create table Program_group_members (
	program     integer references Programs(id),
	ao_group    integer references Acad_object_groups(id),
	primary key (program,ao_group)
);

create table Rules (
	id          integer,
	name        MediumName,
	type        RuleType,
	min         integer check (min >= 0),
	max         integer check (min >= 0),
	ao_group    integer references Acad_object_groups(id),
	description TextString,
	primary key (id)
);

create table Subject_prereqs (
	subject     integer references Subjects(id),
	career      CareerType, -- what kind of students it applies to
	rule        integer references Rules(id),
	primary key (subject,career,rule)
);

create table Stream_rules (
	stream      integer references Streams(id),
	rule        integer references Rules(id),
	primary key (stream,rule)
);

create table Program_rules (
	program     integer references Programs(id),
	rule        integer references Rules(id),
	primary key (program,rule)
);