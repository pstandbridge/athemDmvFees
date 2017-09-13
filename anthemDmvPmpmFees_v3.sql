/*
Script to compile Anthem DMV care management attribution into database table
*/

DECLARE @myfilename nvarchar(255);
DECLARE @mysubject nvarchar(255);
SET @myfilename = 'Finance_AnthemDMVFees_' + CONVERT(VARCHAR(10), GETDATE(), 110) + '.csv';
SET @mysubject =  'Finance Report - Anthem DMV Fees - '+CONVERT(VARCHAR(10), GETDATE(), 110);

Set Nocount On

drop table pophealthanalytics.dbo.anthemDmvPmpmFees
--drop table #temp2

select AthenaEnterpriseID, PGM, CPR, MemberHealthcareID, code, MemberLastName,MemberFirstName, MemberDOB,ProviderNumber, left(month,6) as month, sum(PaymentAmount) as sums,
case when SourceFileName ='PRIVIA QUALITY NETWORK LLC' then 'pqn' when SourceFileName ='FAIRFAX FAMILY PRACTICE CENTERS' then 'fffp' else 'sipa' end as sourcefile
into #temp2
from PriviaDataWarehouse.dbo.AnthemPMPM
--where  -- SourceFileDate='2017-04-01 00:00:00.000' and 
--SourceFileName ='PRIVIA QUALITY NETWORK LLC'
group by AthenaEnterpriseID, PGM, CPR, MemberHealthcareID, code, MemberLastName,MemberFirstName, MemberDOB,ProviderNumber,left(month,6),case when SourceFileName ='PRIVIA QUALITY NETWORK LLC' then 'pqn' when SourceFileName ='FAIRFAX FAMILY PRACTICE CENTERS' then 'fffp' else 'sipa' end
order by MemberHealthcareID, month;

select yrmo as yrMo
,sourcefile as submarket
,count(*) as fees
,sysdatetime() as loadDate

into pophealthanalytics.dbo.anthemDmvPmpmFees

from (select  distinct  MemberHealthcareID,sourcefile,
MemberDOB,
code,
MemberLastName,
MemberFirstName,  providernumber,month as yrmo, sums 
from
#temp2
where sums>0 and sums is not null)
sub
group by sourcefile,yrmo 
order by sourcefile,yrmo;

--select * from pophealthanalytics.dbo.anthemDmvPmpmFees;

EXEC msdb.dbo.sp_send_dbmail
@profile_name = 'DataBot',
@recipients =  'peter.standbridge@priviahealth.com', --moving forward add mediserve
@subject = @mysubject,
@query = 'select * from pophealthanalytics.dbo.anthemDmvPmpmFees;',
@attach_query_result_as_file = 1, 
@query_attachment_filename = @myfilename,
@query_result_separator='   ',
@query_result_no_padding = 1,
@query_result_width=32767;