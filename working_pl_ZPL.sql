
-----------------------------------------------need to GRANT ALL ON UTL_TCP TO <USER>;----------------------------------------------
DECLARE
    CONN         UTL_TCP.CONNECTION;
    RETVAL       BINARY_INTEGER;
    L_RESPONSE   VARCHAR2(1500) := '';
    L_TEXT  VARCHAR2(1000);    
    bcCopy number := 10;
    tagVal varchar2(1500) := 't';
    image varchar2(5500);
   
------------------------------Need to parameterize this part to pull in values from other tables---------------------------   
BEGIN
    image := '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:16E6';
    
    L_TEXT := '^XA~TA000~JSN^LT0^MNW^MTT^PON^PMN^LH0,0^JMA^PR6,6~SD15^JUS^LRN^CI0^XZ
^XA
^MMT
^PW812
^LL1218
^LS0
^FO320,576^GFA,09984,09984,00024,:Z64:'
||image||
'^BY2,3,51^FT368,45^BCI,,Y,N
^FD>:'||tagVal||'^FS
^FT368,108^A0I,33,33^FH\^FDZEBRA (ZPL-II)^FS
^FT11,151^BQN,2,3
^FH\^FDLA,http://bryangilbertson.com^FS
^PQ'||bcCopy||',0,1,Y^XZ';
---------------------------------------------------------------------------------------------------------------------------    
    --OPEN THE CONNECTION
    CONN := UTL_TCP.OPEN_CONNECTION(
        REMOTE_HOST   => '127.0.0.1',  ------aim @ your zebra  or https://chrome.google.com/webstore/detail/zpl-printer/phoidlklenidapnijkabnfdgmadlcmjo?hl=en-US
        REMOTE_PORT   => 9100,
        TX_TIMEOUT    => 10
    );

    --WRITE TO SOCKET
    RETVAL := UTL_TCP.WRITE_LINE(CONN,L_TEXT);
    UTL_TCP.FLUSH(CONN);
    
    -- CHECK AND READ RESPONSE FROM SOCKET
    BEGIN
        WHILE UTL_TCP.AVAILABLE(CONN,10) > 0 LOOP
            L_RESPONSE := L_RESPONSE ||  UTL_TCP.GET_LINE(CONN,TRUE);
        END LOOP;
    EXCEPTION
        WHEN UTL_TCP.END_OF_INPUT THEN
            NULL;
    END;
 
    DBMS_OUTPUT.PUT_LINE('Response from Socket Server : ' || L_RESPONSE);
    UTL_TCP.CLOSE_CONNECTION(CONN);
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20101,SQLERRM);
        UTL_TCP.CLOSE_CONNECTION(CONN);
END;
