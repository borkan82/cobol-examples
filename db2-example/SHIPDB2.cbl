       identification division.
       program-id. SHIPDB2.

       data division.
       working-storage section.
           EXEC SQL INCLUDE SQLCA END-EXEC.
           EXEC SQL BEGIN DECLARE SECTION END-EXEC.
           EXEC SQL INCLUDE DCLSHIP END-EXEC.

       01  search-tracking-number     pic x(14).
       01  carrier-to-list            pic x(3).

       01  delivery-event.
           05  event-tracking-number  pic x(14).
           05  event-occurred-at      pic x(26).
           05  event-location         pic x(20).

       01  database-name              pic x(30).
       01  database-user              pic x(30).
       01  database-password          pic x(30).

           EXEC SQL END DECLARE SECTION END-EXEC.

       01  sql-result                 pic s9(9).
           88  sql-ok                 value 0.
           88  sql-not-found          value 100.
       01  sql-state-of-last-call     pic x(5).
           88  sql-duplicate-key      value '23505'.

       01  current-step               pic x(30).
       01  open-shipment-count        pic 9(5) value zero.
       01  no-more-shipments          pic x value 'N'.
           88  end-of-shipments       value 'Y'.

       01  value-for-display          pic z,zzz,zz9.99.
       01  count-for-display          pic zzz9.
       01  attempts-for-display       pic 9.
       01  sqlcode-for-display        pic -(9)9.

       procedure division.

       main-procedure.
           display 'SHIPDB2 started'
           perform connect-to-database

           display space
           display '1. Look up single shipments (SELECT INTO)'
           perform show-single-shipments

           display space
           display '2. Open shipments of carrier BRZ (cursor)'
           perform list-open-shipments

           display space
           display '3. Mark shipment delivered (UPDATE + INSERT)'
           perform mark-shipment-delivered

           display space
           display '4. Open shipments again, after the commit'
           perform list-open-shipments

           display space
           display '5. Insert the same event again (duplicate key)'
           perform try-duplicate-event

           perform disconnect-from-database
           display 'SHIPDB2 finished, return code 0'
           move 0 to return-code
           goback.

       connect-to-database.
           move 'connect' to current-step
           accept database-name     from environment 'TRACKING_DB'
           accept database-user     from environment 'TRACKING_DB_USER'
           accept database-password
                  from environment 'TRACKING_DB_PASSWORD'
           if database-name = spaces
               move 'tracking@localhost' to database-name
           end-if
           EXEC SQL
               CONNECT :database-user IDENTIFIED BY :database-password
                 USING :database-name
           END-EXEC
           perform check-sql-result
           if not sql-ok
               perform handle-sql-error
           end-if.

       show-single-shipments.
           move 'BP260000000101' to search-tracking-number
           perform read-shipment
           move 'BP260000000103' to search-tracking-number
           perform read-shipment
           move 'XX999999999999' to search-tracking-number
           perform read-shipment.

       read-shipment.
           move 'select shipment' to current-step
           EXEC SQL
               SELECT TRACKING_NUMBER, CARRIER_CODE, RECIPIENT_NAME,
                      RECIPIENT_CITY, SHIPMENT_STATUS, DELIVERED_AT,
                      DECLARED_VALUE
                 INTO :tracking-number, :carrier-code, :recipient-name,
                      :recipient-city, :shipment-status,
                      :delivered-at :delivered-at-indicator,
                      :declared-value
                 FROM SHIPMENT
                WHERE TRACKING_NUMBER = :search-tracking-number
           END-EXEC
           perform check-sql-result

           evaluate true
               when sql-ok
                   move declared-value to value-for-display
                   display '   ' tracking-number '  '
                           function trim(recipient-name) ', '
                           function trim(recipient-city)
                           '  status ' shipment-status
                           '  value' value-for-display ' EUR'
      *            A negative indicator means the column is NULL
                   if delivered-at-indicator < 0
                       display '                   not delivered yet'
                   else
                       display '                   delivered at '
                               delivered-at(1:16)
                   end-if
               when sql-not-found
                   display '   ' search-tracking-number
                           '  not found (SQLCODE 100)'
               when other
                   perform handle-sql-error
           end-evaluate.

       list-open-shipments.
           move 'BRZ' to carrier-to-list

           EXEC SQL
               DECLARE OPEN_SHIPMENTS CURSOR FOR
               SELECT TRACKING_NUMBER, RECIPIENT_NAME,
                      SHIPMENT_STATUS, PROMISED_ON, DELIVERY_ATTEMPTS
                 FROM SHIPMENT
                WHERE CARRIER_CODE = :carrier-to-list
                  AND SHIPMENT_STATUS NOT IN ('DL', 'RT')
                ORDER BY PROMISED_ON, TRACKING_NUMBER
           END-EXEC

           move 'open cursor' to current-step
           EXEC SQL OPEN OPEN_SHIPMENTS END-EXEC
           perform check-sql-result
           if not sql-ok
               perform handle-sql-error
           end-if

           move zero to open-shipment-count
           move 'N' to no-more-shipments
           perform fetch-next-shipment until end-of-shipments

           move 'close cursor' to current-step
           EXEC SQL CLOSE OPEN_SHIPMENTS END-EXEC
           perform check-sql-result
           if not sql-ok
               perform handle-sql-error
           end-if

           move open-shipment-count to count-for-display
           display '   open shipments:' count-for-display.

       fetch-next-shipment.
           move 'fetch cursor' to current-step
           EXEC SQL
               FETCH OPEN_SHIPMENTS
                INTO :tracking-number, :recipient-name,
                     :shipment-status, :promised-on,
                     :delivery-attempts
           END-EXEC
           perform check-sql-result

           evaluate true
               when sql-ok
                   add 1 to open-shipment-count
                   move delivery-attempts to attempts-for-display
                   display '   ' tracking-number '  '
                           recipient-name(1:16)
                           shipment-status '  due ' promised-on
                           '  attempts ' attempts-for-display
               when sql-not-found
                   set end-of-shipments to true
               when other
                   perform handle-sql-error
           end-evaluate.

       mark-shipment-delivered.
           move 'BP260000000102'             to event-tracking-number
           move '2026-10-07 12:10:00.000000' to event-occurred-at
           move 'Belgrade'                   to event-location

           move 'update shipment' to current-step
           EXEC SQL
               UPDATE SHIPMENT
                  SET SHIPMENT_STATUS = 'DL',
                      DELIVERED_AT =
                          CAST(:event-occurred-at AS TIMESTAMP)
                WHERE TRACKING_NUMBER = :event-tracking-number
                  AND SHIPMENT_STATUS NOT IN ('DL', 'RT')
           END-EXEC
           perform check-sql-result
           if not sql-ok and not sql-not-found
               perform handle-sql-error
           end-if

           if sqlerrd(3) = zero
               display '   ' event-tracking-number
                       '  unchanged (unknown or already closed)'
           else
               perform insert-delivery-event
               if not sql-ok
                   perform handle-sql-error
               end-if
               move 'commit' to current-step
               EXEC SQL COMMIT END-EXEC
               perform check-sql-result
               if not sql-ok
                   perform handle-sql-error
               end-if
               display '   ' event-tracking-number
                       '  delivered, event recorded, committed'
           end-if.

       insert-delivery-event.
           move 'insert event' to current-step
           EXEC SQL
               INSERT INTO SHIPMENT_EVENT
                      (TRACKING_NUMBER, OCCURRED_AT,
                       EVENT_STATUS, LOCATION)
               VALUES (:event-tracking-number,
                       CAST(:event-occurred-at AS TIMESTAMP),
                       'DL', :event-location)
           END-EXEC
           perform check-sql-result.

       try-duplicate-event.
           perform insert-delivery-event
           evaluate true
               when sql-ok
                   display '   unexpected: duplicate was accepted'
                   EXEC SQL ROLLBACK END-EXEC
               when sql-duplicate-key
                   display '   rejected as duplicate (SQLSTATE 23505,'
                           ' Db2 SQLCODE -803), rolled back'
                   EXEC SQL ROLLBACK END-EXEC
               when other
                   perform handle-sql-error
           end-evaluate.

       disconnect-from-database.
           EXEC SQL COMMIT END-EXEC
           EXEC SQL DISCONNECT ALL END-EXEC.

       check-sql-result.
           move sqlcode  to sql-result
           move sqlstate to sql-state-of-last-call.

       handle-sql-error.
           move sqlcode to sqlcode-for-display
           display '*** SQL error in step: ' function trim(current-step)
           display '*** SQLCODE ' function trim(sqlcode-for-display)
                   ', SQLSTATE ' sqlstate
           display '*** ' function trim(sqlerrmc)
           EXEC SQL ROLLBACK END-EXEC
           move 12 to return-code
           stop run.
