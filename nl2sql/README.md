# Assignment 1. NL2SQL

For Assignment 1, we will convert natural language questions to SQL queries using ChatGPT. <br/>
Each participant will be given `10 natural language questions (NLQs)`. <br/>
Refer to the [Database Information](#database-information) tab to find the corresponding database information for each NLQ. <br/>
Prompt ChatGPT by combining schema information with additional details to derive accurate SQL queries. <br/>

"Additional details" could include following information:

- changes in how schema information is presented
- changes in prompting techniques
- primary/foreign key (pk/fk) information
- providing examples of column values
- adding manual descriptions about the schema information, etc.

<br/>
If ChatGPT fails to produce the correct SQL query after several attempts, you may write the SQL query yourself. <br/>
If a natural language question is ambiguous, feel free to revise the question. <br/>
Please use PostgreSQL to verify the accuracy of the results obtained from ChatGPT.

## Environments

- [ChatGPT](https://chat.openai.com/)
- Postgres

## Database Information

- Basic ([Data](./database/basic.md), [Diagram1](./assets/basic1.png), [Diagram2](./assets/basic2.gif))
- Movie ([Data](./database/movie.md), [Diagram](./assets/movie1.png))
- Hospital ([Data](./database/hospital.md), [Diagram](./assets/hospital1.png))
- Employee([Data](./database/employee.md), [Diagram](./assets/employee1.png))

(The provided CREATE TABLE queries do not include primary key-foreign key constraints. <br/>For understanding the relationships between tables, please refer to the diagrams.)

<!-- **To test Basic, Movie, Employee Database**

1. Cick [Data](./database/sqlexbackup.sql) and Download sqlexbackup.sql File.
2. Go to pgAdmin -> Tools -> PSQL Tool .
3. Import sqlexbackup file by following command:
   ```
   postgres-# \i [path-to-sqlexbackup.sql]
   i.e) postgres-# \i /Users/kyong/Downloads/sqlex/sqlexbackup.sql
   ``` -->

## Submission Files

You are required to submit two files (`BKMS1-A1-report.pdf`, `BKMS1-A1-answer.xlsx`).

1. `BKMS1-A1-report.pdf`

   Document the entire process of prompting ChatGPT in the report. <br/>
   Include your student ID, name, and the version of ChatGPT in your report.<br/>
   If ChatGPT fails to derive the desired SQL query, include a screenshot or a copy of the unsuccessful result in the report, followed by your final written query.<br/>
   Report should be in **pdf format**.

2. `BKMS1-A1-answer.xlsx`

   This file is for verifying your final SQL query answers. <br/>
   If you needed to revise a natural language question due to ambiguity, write down the revised question in <span style="color:red">red font</span> instead of the original question.
   <br/>
   **► Use the following file: ([BKMS1-A1-answer.xlsx](./BKMS1-A1-answer.xlsx))**

   - `Database`: Write down the database corresponding to each natural language question assigned to you.
   - `NLQ` : Write down the natural language question assigned to you.
   - `SQL` : Write the final SQL query in a single line. <br/>

3. Submission Folder Architecture

   The architecture of submission folder should be as follows:

   ```
    BKMS1-A1-[student ID]/
       ├── BKMS1-A1-report.pdf
       └── BKMS1-A1-answer.xlsx
   ```

   **[Instructions]**

   1. Create a folder named `BKMS1-A1-[yourStudentID]`. _Ex) BKMS1-A1-2024-00000_ <br/>
   2. Inside the `BKMS1-A1-[yourStudentID]` folder, place `BKMS1-A1-report.pdf` and `BKMS1-A1-answer.xlsx` files.
   3. zip the `BKMS1-A1-[yourStudentID]` folder.
   4. Submit the zipped folder through ETL.

## Submission Guide

> Due Date: 2024.04.07 11:59 PM<br/>
> Where: ETL

1. Make sure to follow **submission folder instruction**.

   - -10 points if the file format(pdf, xlsx) is incorrect.
   - -10 points if the folder architecture is different compared to submission folder instruction.

2. Late submissions are penalized by **20%** of total grade per day. <br/>
3. Write the **ChatGPT version** you used in the report. <br/>
4. Download the [REPORT TEMPLATE](./report-template.docx). _(This is just a formatting example, write report in a free format.)_

<br/>
<br/>

---

### (Hint) Prompting Example

```
### Complete Postgres SQL query only and with no explanation.
### SQLite SQL tables, with their properties:
# [Schema]
# frpm(CDSCode, Academic Year, County Code, District Code, School Code, County Name, District Name)
# schools(CDSCode, StatusType, County, District, School, Street, StreetAbr, City, Zip, State, MailStreet, MailStrAbr)
### What is the highest eligible free rate for K-12 students in the schools in Alameda County?
```
