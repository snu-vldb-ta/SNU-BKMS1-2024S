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
```
