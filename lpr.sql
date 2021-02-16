--I took out some code that reports the error to an error table and which raises an exception.... I should have not inserted the return(0); 
--The solution I use in production also uses external procedures in C to be able to print graphics and unicode text as image as most ZEBRA printers do not support unicode
--with their standard firmware. I thought it would be a bit too much to post...



create or replace package LPRPRINT
as
function CreateLabel(p_printerid number, p_filename varchar2, p_application varchar2) return integer;
host varchar2(100) := '<Oracle Host name>';
rawnul raw(1) := utl_raw.cast_to_raw(chr(0));
rawlf raw(1) := utl_raw.cast_to_raw(chr(10));
end;
/
create or replace package body LPRPRINT
as
-- RFC 1179 LPR for Oracle 11G
-- Not fully complient, Cannot control the local port according to the RFC should be 721 - 731
-- Developed to print to ZEBRA label printers.
-- Can be used to print to any printer in RAW or TEXT format
-- Menno Kress July 2012
-- This package needs the following table:
-- create table LPRPrinters
-- (
-- printer_id number primary key,
-- printername varchar2(50),
-- IPaddress varchar2(15 Byte),
-- port number,
-- queuename varchar2(128 byte)
-- );
-- create index lprprinter_name_idx on lprprinters(printername);
--
-- The following sequence should be defined
-- create sequence lprprintque_seq minvalue 0 maxvalue 999 increment by 1 order cycle cache 10;
--
-- This package uses the UTL_TCP package, in Oracle 11g and above,
-- access must be granted to use the TCP ports.
-- Below is an example on how th create the access list and grant access to users.
-- This example grants access to the network 10.145.0.0 / 255.255.0.0
-- on port 515 (default LPD listener port)
-- BEGIN
-- DBMS_NETWORK_ACL_ADMIN.create_acl (
-- acl => 'lpr_acl_file.xml',
-- description => 'LPR printer access list',
-- principal => 'EUROLAND',
-- is_grant => TRUE,
-- privilege => 'connect',
-- start_date => SYSTIMESTAMP,
-- end_date => NULL);

-- DBMS_NETWORK_ACL_ADMIN.add_privilege (
-- acl => 'lpr_acl_file.xml',
-- principal => 'SYSTEM',
-- is_grant => TRUE,
-- privilege => 'connect',
-- position => NULL,
-- start_date => NULL,
-- end_date => NULL);
--
-- DBMS_NETWORK_ACL_ADMIN.assign_acl (
-- acl => 'lpr_acl_file.xml',
-- host => '10.145.*',
-- lower_port => 515,
-- upper_port => NULL);
--
-- COMMIT;
-- END;
-- /
-- Below statement can be used to investigate the existing ACL lists.
-- SELECT host, lower_port, upper_port, acl
-- FROM dba_network_acls;

-- Get job-id from sequence. 1-999 cycles.
function GetNextJobID return integer
is
begin
return(lprprintque_seq.nextval);
end;

-- Check LPD reply. Octet of 0's means command accepted. Any other value is failed.
-- function returns 1 for success, 0 for failure.
function GetReply(ipconn in out utl_tcp.connection) return integer
is
resp raw(1);
ret integer;
begin
ret := 0;
utl_tcp.flush(ipconn);
resp := utl_tcp.get_raw(ipconn, 1, false);
if resp = rawnul then
ret := 1;
end if;
return ret;
end;

-- Get TCP connection to printer based on data in the table LPRPrinters
-- Returns connection on success or null when connection setup failed.
-- After opening the TCP connection, the function also sends the
-- 'Receive a printer job' to the LPD
function ipconnect(p_printerid number) return utl_tcp.connection
is
cursor c_prn(prnid number) is select * from lprprinters where printer_id = prnid;
r_prn lprprinters%rowtype;
ipconn utl_tcp.connection;
begin
open c_prn(p_printerid);
fetch c_prn into r_prn;
if c_prn%found then
ipconn := utl_tcp.open_connection(remote_host => r_prn.ipaddress,
remote_port => r_prn.port,
in_buffer_size => 100,
out_buffer_size => 9000,
charset => 'WE8PC850',
newline => chr(10),
tx_timeout => 5
);
end if;
close c_prn;
if utl_tcp.write_line(ipconn, chr(2) || r_prn.queuename) > 0 then
if GetReply(ipconn) = 0 then
utl_tcp.close_connection(ipconn);
ipconn := null;
end if;
end if;
return(ipconn);
end;

-- When we are done we would like to close the TCP connection....
procedure ipdisconnect(p_ipconn in out utl_tcp.connection) is
begin
utl_tcp.flush(p_ipconn);
utl_tcp.close_connection(p_ipconn);
end;

-- Send control data to LPD
-- Returns 1 on success, 0 on failure
-- Filename is a string composed of: cfA<jobid><hostname> (jobid is 3 digits, from 000 - 999
function send_ctrlfile(ipconn in out utl_tcp.connection, cfilehdr varchar2, ctrlfiledata varchar2) return integer
is
ret integer;
begin
-- cfilehdr := 'cfA'|| to_char(jobid, 'FM000') || host; <-- example header
ret := 0;
if utl_tcp.write_line(ipconn, chr(2)|| to_char(length(ctrlfiledata), 'FM999999')|| chr(32) || cfilehdr) > 0 then
if GetReply(ipconn) = 1 then
if utl_tcp.write_text(ipconn, ctrlfiledata || chr(0)) > 0 then
if GetReply(ipconn) = 1 then
ret := 1;
end if;
end if;
end if;
end if;
return(ret);
end;

-- Send the printer data to the LPD
-- Returns 1 on success, 0 on failure
-- Filename is a string composed of: dfA<jobid><hostname> (jobid is 3 digits, from 000 - 999
function send_data(ipconn in out utl_tcp.connection, dfilehdr varchar2, databuf long raw) return integer
is
ret integer;
begin
ret := 0;
-- dfilehdr := 'dfA'|| to_char(jobid, 'FM000') || host; <-- example header
if utl_tcp.write_line(ipconn, chr(3) || to_char(UTL_RAW.LENGTH(databuf), 'FM9999999999') || chr(32) || dfilehdr) > 1 then
if GetReply(ipconn) = 1 then
if utl_tcp.write_raw(ipconn, utl_raw.concat(databuf, rawnul)) > 0 then
if GetReply(ipconn) = 1 then
ret := 1;
end if;
end if;
end if;
end if;
return(ret);
end;

-- Construct the correct headers for the CTRL file and DATA file based on a job-id and the host name
procedure get_filehdrs(cfilehdr out varchar2, dfilehdr out varchar2)
is
jobid varchar(3);
begin
jobid := to_char(GetNextJobID, 'FM000');
cfilehdr := 'cfA' || jobid || host;
dfilehdr := 'dfA' || jobid || host;
end;

function CreateLabel(p_printerid number, p_filename varchar2, p_application varchar2) return integer is
ipconn utl_tcp.connection;
ctrlfiledata varchar2(2000);
blobptr blob;
jobid integer;
ret integer;
prndata varchar2(16384);
rawbuf long raw;
imagecmd varchar2(200);
textcmd varchar2(200);
dfilehdr varchar2(40);
cfilehdr varchar2(40);
begin

ret := 0;
get_filehdrs(cfilehdr, dfilehdr);
ctrlfiledata := 'H' || host || chr(10) ||
'P' || p_application || chr(10) ||
'l' || dfilehdr || chr(10) ||
'U' || dfilehdr || chr(10) ||
'N' || p_filename || chr(10);

prndata := 'I8,A,031' || chr(10); -- Set printer to 8bit chars, codepage 1252, country code 31 (Netherlands)
prndata := prndata || 'Q320,024' || chr(10); --Set label height to 320 dots, gap to 24 dots
prndata := prndata || 'q479' || chr(10); -- set label with to 479 dots
prndata := prndata || 'rN' || chr(10); -- set single buffer mode
prndata := prndata || 'S4' || chr(10); -- set high speed
prndata := prndata || 'D12' ||chr(10); -- set density
prndata := prndata || 'ZT' || chr(10); -- print bottom to top
prndata := prndata || 'JF' || chr(10); -- Enable top of form backup
prndata := prndata || 'OD' || chr(10); -- set Direct thermal
prndata := prndata || 'R176,0' || chr(10); -- set left and top margin ofset from absolute left of print head.
prndata := prndata || 'f100' || chr(10); -- Cutter fine-adjust.
prndata := prndata || 'N' || chr(10); -- Clear image buffer
prndata := prndata || 'A478,154,2,1,1,1,N,"ABCD12345678"' || chr(10);
prndata := prndata || 'P1' ||chr(10);
rawbuf := utl_raw.cast_to_raw(prndata);


ipconn := ipconnect(p_printerid);
if send_ctrlfile(ipconn, cfilehdr, ctrlfiledata) = 1 then
if send_data(ipconn, dfilehdr, rawbuf) = 1 then
ret := 1;
end if;
end if;
ipdisconnect(ipconn);
return(ret);

EXCEPTION
when others then ipdisconnect(ipconn);
return(0);
end;
end;
Tom Kyte
July 31, 2012 - 12:14 pm UTC
EXCEPTION 
      when others then ipdisconnect(ipconn);
      return(0);
   end;
