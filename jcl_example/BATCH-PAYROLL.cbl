       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-PAYROLL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT EMPLOYEE-FILE
               ASSIGN TO "employees.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
           SELECT REPORT-FILE
               ASSIGN TO "payroll-report.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-REPORT-STATUS.    

       DATA DIVISION.
       FILE SECTION.
       FD REPORT-FILE.
       01 REPORT-RECORD PIC X(100).
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
       01 WS-REPORT-STATUS PIC XX.
       01 WS-REPORT-TOTAL PIC ZZZ,ZZZ,ZZ9.99.
       01 WS-REPORT-COUNT PIC ZZZ9.

       PROCEDURE DIVISION.
       MAIN-PROCEDURE.
           DISPLAY "BATCH PAYROLL STARTED"

           OPEN INPUT EMPLOYEE-FILE
           IF WS-FILE-STATUS NOT = "00"
               DISPLAY "ERROR OPENING FILE: "
                   WS-FILE-STATUS
               STOP RUN
           END-IF

           OPEN OUTPUT REPORT-FILE

           IF WS-REPORT-STATUS NOT = "00"
               DISPLAY "ERROR OPENING REPORT: "
                   WS-REPORT-STATUS
               CLOSE EMPLOYEE-FILE
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
           MOVE "PAYROLL REPORT" TO REPORT-RECORD
           WRITE REPORT-RECORD

           MOVE SPACES TO REPORT-RECORD
           WRITE REPORT-RECORD

           MOVE "EMPLOYEES PROCESSED:" TO REPORT-RECORD
           WRITE REPORT-RECORD

           MOVE WS-EMPLOYEE-COUNT TO WS-REPORT-COUNT
           MOVE WS-REPORT-COUNT TO REPORT-RECORD
           WRITE REPORT-RECORD

           MOVE "TOTAL SALARY:" TO REPORT-RECORD
           WRITE REPORT-RECORD

           MOVE WS-TOTAL-SALARY TO WS-REPORT-TOTAL
           MOVE WS-REPORT-TOTAL TO REPORT-RECORD
           WRITE REPORT-RECORD

           CLOSE REPORT-FILE

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
