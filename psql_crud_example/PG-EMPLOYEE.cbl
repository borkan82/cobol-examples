
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PG-EMPLOYEE.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-CHOICE        PIC X VALUE SPACE.
       01 WS-STOP          PIC X VALUE "N".
       01 WS-RESULT        PIC S9(9) COMP-5.
       01 WS-EMPLOYEE-ID   PIC X(5).
       01 WS-EMPLOYEE-NAME PIC X(31).
       01 WS-SALARY        PIC X(32).
       01 WS-NEW-NAME   PIC X(30).
       01 WS-NEW-SALARY PIC X(12).
       01 WS-SALARY-INPUT PIC X(12).
       01 WS-SALARY-VALID PIC X VALUE "N".
       01 WS-CHAR-COUNT   PIC 9(2) COMP-5.
       01 WS-DOT-COUNT    PIC 9 VALUE 0.
       01 WS-DIGIT-COUNT  PIC 9(2) COMP-5.
       01 WS-DECIMAL-COUNT PIC 9 VALUE 0.
       01 WS-INVALID      PIC X VALUE "N".
       01 WS-CHAR         PIC X.
       01 WS-I            PIC 9(2) COMP-5.
       01 WS-DB-ERROR PIC X(512).

       PROCEDURE DIVISION.

       MAIN-PROCEDURE.
           PERFORM UNTIL WS-STOP = "Y"
               DISPLAY " "
               DISPLAY "=============================="
               DISPLAY "     EMPLOYEE DATABASE"
               DISPLAY "=============================="
               DISPLAY "1. Find employee"
               DISPLAY "2. Add employee"
               DISPLAY "3. Update salary"
               DISPLAY "4. Delete employee"
               DISPLAY "5. Exit"
               DISPLAY "=============================="
               DISPLAY "Choose an option (1-5): "
                   WITH NO ADVANCING

               ACCEPT WS-CHOICE

               EVALUATE WS-CHOICE
                   WHEN "1"
                       PERFORM FIND-EMPLOYEE
                   WHEN "2"
                       PERFORM ADD-EMPLOYEE
                   WHEN "3"
                       PERFORM UPDATE-SALARY
                   WHEN "4"
                       PERFORM DELETE-EMPLOYEE
                   WHEN "5"
                       MOVE "Y" TO WS-STOP
                       DISPLAY "Exiting application..."
                   WHEN OTHER
                       DISPLAY "Invalid option. Choose 1-5."
               END-EVALUATE
           END-PERFORM

           STOP RUN.

       FIND-EMPLOYEE.
           MOVE SPACES TO WS-EMPLOYEE-ID
                          WS-EMPLOYEE-NAME
                          WS-SALARY

           DISPLAY "Enter employee ID (5 characters): "
               WITH NO ADVANCING
           ACCEPT WS-EMPLOYEE-ID

           PERFORM VALIDATE-EMPLOYEE-ID

           IF WS-RESULT = 0
               CALL STATIC "pg_get_employee"
                   USING
                       BY REFERENCE WS-EMPLOYEE-ID
                       BY REFERENCE WS-EMPLOYEE-NAME
                       BY REFERENCE WS-SALARY
                   RETURNING WS-RESULT
               END-CALL
           END-IF

           CALL STATIC "pg_get_employee"
               USING
                   BY REFERENCE WS-EMPLOYEE-ID
                   BY REFERENCE WS-EMPLOYEE-NAME
                   BY REFERENCE WS-SALARY
               RETURNING WS-RESULT
           END-CALL

           EVALUATE WS-RESULT
               WHEN 0
                   DISPLAY "Employee found:"
                   DISPLAY "ID: " WS-EMPLOYEE-ID
                   DISPLAY "Name: "
                       FUNCTION TRIM(WS-EMPLOYEE-NAME)
                   DISPLAY "Salary: "
                       FUNCTION TRIM(WS-SALARY)
               WHEN 2
                   DISPLAY "Employee not found."
               WHEN OTHER
                   DISPLAY "Database query failed."
           END-EVALUATE.

       
       ADD-EMPLOYEE.
           MOVE SPACES TO WS-EMPLOYEE-ID
                          WS-NEW-NAME
                          WS-NEW-SALARY

           DISPLAY "Enter employee ID (5 characters): "
               WITH NO ADVANCING
           ACCEPT WS-EMPLOYEE-ID

           DISPLAY "Enter employee name: "
               WITH NO ADVANCING
           ACCEPT WS-NEW-NAME

           DISPLAY "Enter salary (e.g. 2800.00): "
               WITH NO ADVANCING
           ACCEPT WS-NEW-SALARY

           MOVE WS-NEW-SALARY TO WS-SALARY-INPUT
           PERFORM VALIDATE-SALARY

           CALL STATIC "pg_insert_employee"
               USING
                   BY REFERENCE WS-EMPLOYEE-ID
                   BY REFERENCE WS-NEW-NAME
                   BY REFERENCE WS-NEW-SALARY
               RETURNING WS-RESULT
           END-CALL

           IF WS-RESULT = 0
               DISPLAY "Employee added successfully!"
           ELSE
               MOVE SPACES TO WS-DB-ERROR

               CALL STATIC "pg_get_last_error"
                   USING
                       BY REFERENCE WS-DB-ERROR
                       BY VALUE 512
                   RETURNING WS-RESULT
               END-CALL

               DISPLAY "Insert failed:"
               DISPLAY FUNCTION TRIM(WS-DB-ERROR)
           END-IF.

       
       UPDATE-SALARY.
           MOVE SPACES TO WS-EMPLOYEE-ID
                          WS-NEW-SALARY

           DISPLAY "Enter employee ID (5 characters): "
               WITH NO ADVANCING
           ACCEPT WS-EMPLOYEE-ID

           DISPLAY "Enter new salary (e.g. 3200.00): "
               WITH NO ADVANCING
           ACCEPT WS-NEW-SALARY

           CALL STATIC "pg_update_salary"
               USING
                   BY REFERENCE WS-EMPLOYEE-ID
                   BY REFERENCE WS-NEW-SALARY
               RETURNING WS-RESULT
           END-CALL

           DISPLAY "DEBUG: pg_update_salary result = "
                   WS-RESULT

           EVALUATE WS-RESULT
               WHEN 0
                   DISPLAY "Salary updated successfully."
               WHEN 2
                   DISPLAY "Error: Employee not found."
               WHEN OTHER
                   MOVE SPACES TO WS-DB-ERROR

                   CALL STATIC "pg_get_last_error"
                       USING
                           BY REFERENCE WS-DB-ERROR
                           BY VALUE 512
                       RETURNING WS-RESULT
                   END-CALL

                   IF WS-DB-ERROR = SPACES
                       DISPLAY "Salary update failed."
                       DISPLAY
                           "No diagnostic was provided by ODBC."
                   ELSE
                       DISPLAY "Salary update failed:"
                       DISPLAY FUNCTION TRIM(WS-DB-ERROR)
                   END-IF
           END-EVALUATE.

       DELETE-EMPLOYEE.
           MOVE SPACES TO WS-EMPLOYEE-ID

           DISPLAY "Enter employee ID to delete: "
               WITH NO ADVANCING
           ACCEPT WS-EMPLOYEE-ID

           DISPLAY "Are you sure? Enter Y to confirm: "
               WITH NO ADVANCING
           ACCEPT WS-CHOICE

           IF WS-CHOICE = "Y" OR WS-CHOICE = "y"
               CALL STATIC "pg_delete_employee"
                   USING BY REFERENCE WS-EMPLOYEE-ID
                   RETURNING WS-RESULT
               END-CALL

               EVALUATE WS-RESULT
                   WHEN 0
                       DISPLAY
                           "Employee deleted successfully!"
                   WHEN 2
                       DISPLAY "Employee not found."
                   WHEN OTHER
                       DISPLAY "Delete failed."
               END-EVALUATE
           ELSE
               DISPLAY "Deletion cancelled."
           END-IF.

       VALIDATE-EMPLOYEE-ID.
           IF WS-EMPLOYEE-ID = SPACES
               DISPLAY "Error: Employee ID cannot be blank."
               MOVE 1 TO WS-RESULT
           ELSE
               MOVE 0 TO WS-RESULT
           END-IF.

           IF WS-EMPLOYEE-ID IS NUMERIC
               MOVE 0 TO WS-RESULT
           ELSE
               DISPLAY
                   "Error: ID must contain exactly 5 digits."
               MOVE 1 TO WS-RESULT
           END-IF.


       VALIDATE-SALARY.
           MOVE "N" TO WS-SALARY-VALID
           MOVE 0 TO WS-DOT-COUNT
                      WS-DIGIT-COUNT
                      WS-DECIMAL-COUNT
           MOVE "N" TO WS-INVALID
           MOVE FUNCTION LENGTH(
               FUNCTION TRIM(WS-SALARY-INPUT TRAILING))
               TO WS-CHAR-COUNT

           IF WS-CHAR-COUNT = 0 OR WS-CHAR-COUNT > 12
               MOVE "Y" TO WS-INVALID
           ELSE
               PERFORM VARYING WS-I FROM 1 BY 1
                   UNTIL WS-I > WS-CHAR-COUNT
                   MOVE WS-SALARY-INPUT(WS-I:1)
                       TO WS-CHAR

                   EVALUATE TRUE
                       WHEN WS-CHAR >= "0"
                        AND WS-CHAR <= "9"
                           ADD 1 TO WS-DIGIT-COUNT
                           IF WS-DOT-COUNT = 1
                               ADD 1 TO WS-DECIMAL-COUNT
                           END-IF
                       WHEN WS-CHAR = "."
                           ADD 1 TO WS-DOT-COUNT
                       WHEN OTHER
                           MOVE "Y" TO WS-INVALID
                   END-EVALUATE
               END-PERFORM

               IF WS-DIGIT-COUNT = 0
                   MOVE "Y" TO WS-INVALID
               END-IF

               IF WS-DOT-COUNT > 1
                   MOVE "Y" TO WS-INVALID
               END-IF

               IF WS-DOT-COUNT = 1
                   IF WS-DECIMAL-COUNT < 1
                       OR WS-DECIMAL-COUNT > 2
                       MOVE "Y" TO WS-INVALID
                   END-IF
               END-IF
           END-IF

           IF WS-INVALID = "N"
               MOVE "Y" TO WS-SALARY-VALID
           ELSE
               DISPLAY
                   "Invalid salary. Enter a non-negative amount,"
               DISPLAY
                   "with no more than 2 decimal places."
           END-IF.
