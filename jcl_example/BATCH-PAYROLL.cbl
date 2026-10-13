
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-PAYROLL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT EMPLOYEE-FILE
               ASSIGN TO "employees.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD EMPLOYEE-FILE.
       01 EMPLOYEE-RECORD.
          05 EMPLOYEE-ID   PIC X(5).
          05 EMPLOYEE-NAME PIC X(25).
          05 EMPLOYEE-SALARY PIC X(7).

       WORKING-STORAGE SECTION.
       01 WS-FILE-STATUS   PIC XX.
       01 WS-EOF           PIC X VALUE "N".
       01 WS-EMPLOYEE-COUNT PIC 9(4) VALUE ZERO.
       01 WS-TOTAL-SALARY  PIC 9(9)V99 VALUE ZERO.
       01 WS-SALARY        PIC 9(6)V99 VALUE ZERO.
       01 WS-SALARY-TEXT   PIC X(7).

       PROCEDURE DIVISION.
       MAIN-PROCEDURE.
           DISPLAY "BATCH PAYROLL STARTED"

           OPEN INPUT EMPLOYEE-FILE

           IF WS-FILE-STATUS NOT = "00"
               DISPLAY "ERROR OPENING FILE: "
                   WS-FILE-STATUS
               STOP RUN
           END-IF

           PERFORM UNTIL WS-EOF = "Y"
               READ EMPLOYEE-FILE
                   AT END
                       MOVE "Y" TO WS-EOF
                   NOT AT END
                       PERFORM PROCESS-EMPLOYEE
               END-READ
           END-PERFORM

           CLOSE EMPLOYEE-FILE

           DISPLAY "EMPLOYEES PROCESSED: "
               WS-EMPLOYEE-COUNT
           DISPLAY "TOTAL SALARY: "
               WS-TOTAL-SALARY
           DISPLAY "BATCH PAYROLL COMPLETED"

           STOP RUN.

       PROCESS-EMPLOYEE.
           MOVE EMPLOYEE-SALARY TO WS-SALARY-TEXT

           IF FUNCTION TEST-NUMVAL(
               FUNCTION TRIM(WS-SALARY-TEXT)) = 0

               COMPUTE WS-SALARY =
                   FUNCTION NUMVAL(WS-SALARY-TEXT)

               ADD WS-SALARY TO WS-TOTAL-SALARY
               ADD 1 TO WS-EMPLOYEE-COUNT

               DISPLAY EMPLOYEE-ID " "
                   EMPLOYEE-NAME " "
                   WS-SALARY

           ELSE
               DISPLAY "INVALID SALARY FOR EMPLOYEE: "
                   EMPLOYEE-ID
           END-IF.
