## Table Creation

```sql
CREATE TABLE Physician (
  employeeid SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  position TEXT NOT NULL,
  ssn INTEGER NOT NULL UNIQUE
);

CREATE TABLE Department (
  departmentid SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  head INTEGER NOT NULL
);

CREATE TABLE Affiliated_With (
  physician INTEGER NOT NULL,
  department INTEGER NOT NULL,
  primaryaffiliation BOOLEAN NOT NULL
);

CREATE TABLE Procedure (
  code SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  cost REAL NOT NULL
);

CREATE TABLE Trained_In (
  physician INTEGER NOT NULL,
  treatment INTEGER NOT NULL,
  certificationdate TIMESTAMP NOT NULL,
  certificationexpires TIMESTAMP NOT NULL,
  PRIMARY KEY(physician, treatment)
);

CREATE TABLE Patient (
  ssn INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  phone TEXT NOT NULL,
  insuranceid INTEGER NOT NULL,
  pcp INTEGER NOT NULL
);

CREATE TABLE Nurse (
  employeeid SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  position TEXT NOT NULL,
  registered BOOLEAN NOT NULL,
  ssn INTEGER NOT NULL UNIQUE
);

CREATE TABLE Appointment (
  appointmentid SERIAL PRIMARY KEY,
  patient INTEGER NOT NULL ,
  prepnurse INTEGER,
  physician INTEGER NOT NULL ,
  start_dt_time TIMESTAMP NOT NULL,
  end_dt_time TIMESTAMP NOT NULL,
  examinationroom TEXT NOT NULL
);

CREATE TABLE Medication (
  code SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  brand TEXT NOT NULL,
  description TEXT NOT NULL
);

CREATE TABLE Prescribes (
  physician INTEGER NOT NULL ,
  patient INTEGER NOT NULL ,
  medication INTEGER NOT NULL ,
  date TIMESTAMP NOT NULL,
  appointment INTEGER,
  dose TEXT NOT NULL,
  PRIMARY KEY(physician, patient, medication, date)
);

CREATE TABLE Block (
  blockfloor INTEGER NOT NULL,
  blockcode INTEGER NOT NULL,
  PRIMARY KEY(blockfloor, blockcode)
);

CREATE TABLE Room (
  roomnumber SERIAL PRIMARY KEY,
  roomtype TEXT NOT NULL,
  blockfloor INTEGER NOT NULL,
  blockcode INTEGER NOT NULL,
  unavailable BOOLEAN NOT NULL
);

CREATE TABLE On_Call (
  nurse INTEGER NOT NULL,
  blockFloor INTEGER NOT NULL,
  blockCode INTEGER NOT NULL,
  oncallstart TIMESTAMP NOT NULL,
  oncallend TIMESTAMP NOT NULL,
  PRIMARY KEY(nurse, blockFloor, blockCode, oncallstart, oncallend)
);

CREATE TABLE Stay (
  stayid SERIAL PRIMARY KEY,
  patient INTEGER NOT NULL,
  room INTEGER NOT NULL,
  start_time TIMESTAMP NOT NULL,
  end_time TIMESTAMP NOT NULL
);

CREATE TABLE Undergoes (
  patient INTEGER NOT NULL,
  procedure INTEGER NOT NULL,
  stay INTEGER NOT NULL,
  date TIMESTAMP NOT NULL,
  physician INTEGER NOT NULL,
  assistingnurse INTEGER,
  PRIMARY KEY(patient, procedure, stay, date)
);
```

## Insert Data

```sql
INSERT INTO Physician (employeeid, name, position, ssn) VALUES
(1, 'John Dorian', 'Staff Internist', 111111111),
(2, 'Elliot Reid', 'Attending Physician', 222222222),
(3, 'Christopher Turk', 'Surgical Attending Physician', 333333333),
(4, 'Percival Cox', 'Senior Attending Physician', 444444444),
(5, 'Bob Kelso', 'Head Chief of Medicine', 555555555),
(6, 'Todd Quinlan', 'Surgical Attending Physician', 666666666),
(7, 'John Wen', 'Surgical Attending Physician', 777777777),
(8, 'Keith Dudemeister', 'MD Resident', 888888888),
(9, 'Molly Clock', 'Attending Psychiatrist', 999999999);

INSERT INTO Department (departmentid, name, head) VALUES
(1, 'General Medicine', 4),
(2, 'Surgery', 7),
(3, 'Psychiatry', 9);

INSERT INTO Affiliated_With (physician, department, primaryaffiliation) VALUES
(1, 1, TRUE),
(2, 1, TRUE),
(3, 1, FALSE),
(3, 2, TRUE),
(4, 1, TRUE),
(5, 1, TRUE),
(6, 2, TRUE),
(7, 1, FALSE),
(7, 2, TRUE),
(8, 1, TRUE),
(9, 3, TRUE);

INSERT INTO Procedure (code, name, cost) VALUES
(1, 'Reverse Rhinopodoplasty', 1500.0),
(2, 'Obtuse Pyloric Recombobulation', 3750.0),
(3, 'Folded Demiophtalmectomy', 4500.0),
(4, 'Complete Walletectomy', 10000.0),
(5, 'Obfuscated Dermogastrotomy', 4899.0),
(6, 'Reversible Pancreomyoplasty', 5600.0),
(7, 'Follicular Demiectomy', 25.0);

INSERT INTO Patient (ssn, name, address, phone, insuranceid, pcp) VALUES
(100000001, 'John Smith', '42 Foobar Lane', '555-0256', 68476213, 1),
(100000002, 'Grace Ritchie', '37 Snafu Drive', '555-0512', 36546321, 2),
(100000003, 'Random J. Patient', '101 Omgbbq Street', '555-1204', 65465421, 2),
(100000004, 'Dennis Doe', '1100 Foobaz Avenue', '555-2048', 68421879, 3);

INSERT INTO Nurse (employeeid, name, position, registered, ssn) VALUES
(101, 'Carla Espinosa', 'Head Nurse', TRUE, 111111110),
(102, 'Laverne Roberts', 'Nurse', TRUE, 222222220),
(103, 'Paul Flowers', 'Nurse', FALSE, 333333330);

INSERT INTO Appointment (appointmentid, patient, prepnurse, physician, start_dt_time, end_dt_time, examinationroom) VALUES
(13216584,100000001,101,1,'2008-04-24 10:00','2008-04-24 11:00','A'),
(26548913,100000002,101,2,'2008-04-24 10:00','2008-04-24 11:00','B'),
(36549879,100000001,102,1,'2008-04-25 10:00','2008-04-25 11:00','A'),
(46846589,100000004,103,4,'2008-04-25 10:00','2008-04-25 11:00','B'),
(59871321,100000004,NULL,4,'2008-04-26 10:00','2008-04-26 11:00','C'),
(69879231,100000003,103,2,'2008-04-26 11:00','2008-04-26 12:00','C'),
(76983231,100000001,NULL,3,'2008-04-26 12:00','2008-04-26 13:00','C'),
(86213939,100000004,102,9,'2008-04-27 10:00','2008-04-21 11:00','A'),
(93216548,100000002,101,2,'2008-04-27 10:00','2008-04-27 11:00','B');

INSERT INTO Medication(code, name, brand, description) VALUES
(1,'Procrastin-X','X','N/A'),
(2,'Thesisin','Foo Labs','N/A'),
(3,'Awakin','Bar Laboratories','N/A'),
(4,'Crescavitin','Baz Industries','N/A'),
(5,'Melioraurin','Snafu Pharmaceuticals','N/A');

INSERT INTO Prescribes (physician, patient, medication, date, appointment, dose) VALUES
(1,100000001,1,'2008-04-24 10:47',13216584,'5'),
(9,100000004,2,'2008-04-27 10:53',86213939,'10'),
(9,100000004,2,'2008-04-30 16:53',NULL,'5');

INSERT INTO Block (blockfloor, blockcode) VALUES
(1,1),
(1,2),
(1,3),
(2,1),
(2,2),
(2,3),
(3,1),
(3,2),
(3,3),
(4,1),
(4,2),
(4,3);

INSERT INTO Room (roomnumber, roomtype, blockfloor, blockcode, unavailable) VALUES
(101,'Single',1,1,false),
(102,'Single',1,1,false),
(103,'Single',1,1,false),
(111,'Single',1,2,false),
(112,'Single',1,2,true),
(113,'Single',1,2,false),
(121,'Single',1,3,false),
(122,'Single',1,3,false),
(123,'Single',1,3,false),
(201,'Single',2,1,true),
(202,'Single',2,1,false),
(203,'Single',2,1,false),
(211,'Single',2,2,false),
(212,'Single',2,2,false),
(213,'Single',2,2,true),
(221,'Single',2,3,false),
(222,'Single',2,3,false),
(223,'Single',2,3,false),
(301,'Single',3,1,false),
(302,'Single',3,1,true),
(303,'Single',3,1,false),
(311,'Single',3,2,false),
(312,'Single',3,2,false),
(313,'Single',3,2,false),
(321,'Single',3,3,true),
(322,'Single',3,3,false),
(323,'Single',3,3,false),
(401,'Single',4,1,false),
(402,'Single',4,1,true),
(403,'Single',4,1,false),
(411,'Single',4,2,false),
(412,'Single',4,2,false),
(413,'Single',4,2,false),
(421,'Single',4,3,true),
(422,'Single',4,3,false),
(423,'Single',4,3,false);

INSERT INTO On_Call (nurse, blockFloor, blockCode, oncallstart, oncallend) VALUES
(101,1,1,'2008-11-04 11:00','2008-11-04 19:00'),
(101,1,2,'2008-11-04 11:00','2008-11-04 19:00'),
(102,1,3,'2008-11-04 11:00','2008-11-04 19:00'),
(103,1,1,'2008-11-04 19:00','2008-11-05 03:00'),
(103,1,2,'2008-11-04 19:00','2008-11-05 03:00'),
(103,1,3,'2008-11-04 19:00','2008-11-05 03:00');

INSERT INTO Stay (stayid, patient, room, start_time, end_time) VALUES
(3215,100000001,111,'2008-05-01','2008-05-04'),
(3216,100000003,123,'2008-05-03','2008-05-14'),
(3217,100000004,112,'2008-05-02','2008-05-03');

INSERT INTO Undergoes (patient, procedure, stay, date, physician, assistingnurse) VALUES
(100000001,6,3215,'2008-05-02',3,101),
(100000001,2,3215,'2008-05-03',7,101),
(100000004,1,3217,'2008-05-07',3,102),
(100000004,5,3217,'2008-05-09',6,NULL),
(100000001,7,3217,'2008-05-10',7,101),
(100000004,4,3217,'2008-05-13',3,103);

INSERT INTO Trained_In (physician, treatment, certificationdate, certificationexpires) VALUES
(3,1,'2008-01-01','2008-12-31'),
(3,2,'2008-01-01','2008-12-31'),
(3,5,'2008-01-01','2008-12-31'),
(3,6,'2008-01-01','2008-12-31'),
(3,7,'2008-01-01','2008-12-31'),
(6,2,'2008-01-01','2008-12-31'),
(6,5,'2007-01-01','2007-12-31'),
(6,6,'2008-01-01','2008-12-31'),
(7,1,'2008-01-01','2008-12-31'),
(7,2,'2008-01-01','2008-12-31'),
(7,3,'2008-01-01','2008-12-31'),
(7,4,'2008-01-01','2008-12-31'),
(7,5,'2008-01-01','2008-12-31'),
(7,6,'2008-01-01','2008-12-31'),
(7,7,'2008-01-01','2008-12-31');
```
