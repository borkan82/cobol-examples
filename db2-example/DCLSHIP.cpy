       01  DCLSHIPMENT.
           10 TRACKING-NUMBER      PIC X(14).
           10 CARRIER-CODE         PIC X(3).
           10 RECIPIENT-NAME       PIC X(30).
           10 RECIPIENT-CITY       PIC X(20).
           10 SHIPMENT-STATUS      PIC X(2).
           10 SHIPPED-ON           PIC X(10).
           10 PROMISED-ON          PIC X(10).
           10 DELIVERED-AT         PIC X(26).
           10 DELIVERY-ATTEMPTS    PIC S9(4) USAGE COMP.
           10 DECLARED-VALUE       PIC S9(7)V9(2) USAGE COMP-3.
           
      * Null indicator for the only nullable column                    *
       01  ISHIPMENT.
           10 DELIVERED-AT-INDICATOR PIC S9(4) USAGE COMP.
